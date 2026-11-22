import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "Shortcuts.js" as Catalog

// The trainer, mounted once inside omarchy-shell.
//
// It watches which app has focus (window class only: no keyboard hook, no
// network) and shows one shortcut tip at a time. Every described Hyprland
// binding is a tip, so shortcuts that arrive with an Omarchy update show up
// by themselves and are flagged as new. Progress is kept in
// ~/.local/state/omarchy/shortcut-trainer.json.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  // Filled in by the Omarchy host.
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property string omarchyPath: ""

  // ------------------------------------------------------------- tuning (ms)
  // The first three are user settings, pushed in by the bar widget through
  // configure(); these are the defaults until it does.
  property int popupDuration: 5000
  // Least time from one tip to the next. Never shorter than a tip stays up.
  property int globalCooldown: 45000
  // Tips never seen before, per day. Repetitions are not counted.
  property int maxNewPerDay: 12
  // Wait before the n-th repetition: 2 min, 10 min, 1 h, 1 day, 3 days, 1 week.
  readonly property var repetitionIntervals: [120000, 600000, 3600000, 86400000, 259200000, 604800000]
  // How long a shortcut that arrived with an update counts as new.
  readonly property double freshFor: 14 * 86400000

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/shortcut-trainer.json"
  readonly property string omarchyRoot: omarchyPath || Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  // ------------------------------------------------------------------- state
  property var allRules: Catalog.staticRules()
  property var ruleById: indexRules(allRules)
  property bool bindsLoaded: false
  property bool stateLoaded: false

  property var progress: ({})   // {id: {shown, nextAt, known}}
  property var seen: null       // [id] of every tip this machine has had; null before the first run
  property var fresh: ({})      // {id: first-seen ms} for tips that came with an update
  property var daily: ({ date: "", count: 0 })
  property bool paused: false

  property double lastPopupAt: 0
  property string lastClass: ""
  property string currentContext: "all"

  readonly property int knownCount: {
    var n = 0
    for (var i = 0; i < allRules.length; i++)
      if (progress[allRules[i].id] && progress[allRules[i].id].known) n++
    return n
  }
  readonly property var freshRules: allRules.filter(function(r) { return root.fresh[r.id] !== undefined })

  // What the popup shows.
  property string hintId: ""
  property string hintKeys: ""
  property string hintContext: ""
  property int hintRepetition: 0
  property bool hintFresh: false
  property bool tipShown: false
  property var tipScreen: null

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // Omarchy's own translations of binding descriptions, for tips that have no
  // text of their own here.
  readonly property string language: Commons.I18n.language || "en"
  readonly property var omarchyStrings: {
    var base = parseCatalog(omarchyBaseFile.text())
    var lang = parseCatalog(omarchyLangFile.text())
    return Object.assign({}, base, lang)
  }
  FileView {
    id: omarchyLangFile
    path: root.omarchyRoot + "/default/i18n/" + root.language + "/keybindings.json"
    printErrors: false
  }
  FileView {
    id: omarchyBaseFile
    path: root.omarchyRoot + "/default/i18n/" + root.language.split("-")[0] + "/keybindings.json"
    printErrors: false
  }

  function parseCatalog(raw) {
    if (!raw || raw.length > 1000000) return ({})
    try {
      var data = JSON.parse(raw)
      return data && typeof data === "object" && !Array.isArray(data) ? data : ({})
    } catch (e) {
      return ({})
    }
  }

  function indexRules(list) {
    var map = {}
    for (var i = 0; i < list.length; i++) map[list[i].id] = list[i]
    return map
  }

  // -------------------------------------------------------------- public API
  function ruleText(id) {
    var own = strings.t("rule." + id, "")
    if (own && own !== "rule." + id) return own
    var r = ruleById[id]
    if (!r || !r.desc) return id
    var text = omarchyStrings[r.desc]
    if (typeof text !== "string" || text.length === 0 || text.length > 200) text = r.desc
    return Catalog.fillNumbered(text, r.keys)
  }
  function contextText(ctx) { return strings.t("context." + ctx, ctx) }
  function isKnown(id) { return !!(progress[id] && progress[id].known) }
  function isFresh(id) { return fresh[id] !== undefined }
  function shownCount(id) { return progress[id] ? progress[id].shown : 0 }

  // The tips that belong to one kind of app. "all" means the curated
  // everywhere-tips; the full list is allRules.
  function rulesFor(ctx) {
    return allRules.filter(function(r) { return r.curated && r.context === ctx })
  }

  function setKnown(id, known) {
    var next = Object.assign({}, progress)
    next[id] = Object.assign({ shown: 0, nextAt: 0 }, next[id] || {}, { known: !!known })
    progress = next
    if (known) clearFresh(id)
    if (known && hintId === id) hideTip()
    saveSoon()
  }

  function setPaused(value) {
    paused = !!value
    if (paused) hideTip()
    saveSoon()
  }

  function resetProgress() {
    progress = ({})
    fresh = ({})
    daily = ({ date: "", count: 0 })
    lastPopupAt = 0
    saveSoon()
  }

  // A tip for the current app right away, regardless of pause or cooldown.
  function showNow() { nextHint(true) }

  // ------------------------------------------------------------------- logic
  function onFocusClass(appClass) {
    var klass = String(appClass || "").toLowerCase().slice(0, 120)
    if (Catalog.ignored(klass)) return
    // Only when entering another app, not between two windows of the same one.
    if (klass === lastClass) return
    lastClass = klass
    currentContext = Catalog.classify(klass)
    debounce.restart()
  }

  function today() {
    var d = new Date()
    return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()
  }

  // Order of preference:
  //   1. shortcuts that came with an Omarchy update, not shown yet
  //   2. repetitions that are due, the longest overdue first
  //   3. tips never shown, at most maxNewPerDay a day:
  //      this app's tips, then the curated everywhere-tips, then the rest
  // Within each, tips for the current app come before general ones.
  function pickRule(force) {
    var now = Date.now()
    var ctx = currentContext
    var pool = allRules.filter(function(r) {
      return !root.isKnown(r.id) && (r.context === ctx || r.context === "all")
    })
    if (pool.length === 0) return null

    function rank(r) {
      var shown = root.shownCount(r.id)
      var tier
      if (root.isFresh(r.id) && shown === 0) tier = 0
      else if (shown > 0) tier = 1
      else tier = 2
      var place = r.context === ctx && ctx !== "all" ? 0 : (r.curated ? 1 : 2)
      return { tier: tier, place: place, shown: shown, nextAt: shown > 0 ? root.progress[r.id].nextAt : 0 }
    }

    var newLeft = daily.date === today() ? maxNewPerDay - daily.count : maxNewPerDay
    var candidates = pool.map(function(r) { return { rule: r, rank: rank(r) } }).filter(function(c) {
      if (force) return true
      if (c.rank.tier === 1) return c.rank.nextAt <= now
      if (c.rank.tier === 2) return newLeft > 0
      return true
    })
    if (candidates.length === 0) return null

    candidates.sort(function(a, b) {
      var x = a.rank, y = b.rank
      if (force) {
        // On request: something not seen yet, else whatever was seen longest ago.
        if ((x.shown === 0) !== (y.shown === 0)) return x.shown === 0 ? -1 : 1
        if (x.place !== y.place) return x.place - y.place
        if (x.nextAt !== y.nextAt) return x.nextAt - y.nextAt
        return a.rule.order - b.rule.order
      }
      if (x.tier !== y.tier) return x.tier - y.tier
      if (x.place !== y.place) return x.place - y.place
      if (x.nextAt !== y.nextAt) return x.nextAt - y.nextAt
      return a.rule.order - b.rule.order
    })
    return candidates[0].rule
  }

  // Settings from the widget's shell.json entry; see Catalog.readSettings.
  function configure(raw) {
    var s = Catalog.readSettings(raw)
    popupDuration = s.tipSeconds * 1000
    globalCooldown = Math.max(s.gapSeconds, s.tipSeconds) * 1000
    maxNewPerDay = s.newPerDay
  }

  function nextHint(force) {
    if (paused && !force) return
    var now = Date.now()
    if (!force && now - lastPopupAt < globalCooldown) return
    var rule = pickRule(force)
    if (!rule) return

    var previous = shownCount(rule.id)
    var delay = repetitionIntervals[Math.min(previous, repetitionIntervals.length - 1)]
    var next = Object.assign({}, progress)
    next[rule.id] = { shown: previous + 1, nextAt: now + delay, known: false }
    progress = next
    if (previous === 0) {
      var d = today()
      daily = { date: d, count: (daily.date === d ? daily.count : 0) + 1 }
    }

    hintId = rule.id
    hintKeys = rule.keys
    hintContext = rule.context === "all" ? "all" : currentContext
    hintRepetition = previous + 1
    hintFresh = isFresh(rule.id)
    clearFresh(rule.id)
    saveSoon()

    lastPopupAt = now
    tipScreen = focusedScreen()
    tipShown = true
    hideTimer.restart()
  }

  function clearFresh(id) {
    if (fresh[id] === undefined) return
    var next = Object.assign({}, fresh)
    delete next[id]
    fresh = next
  }

  function hideTip() {
    hideTimer.stop()
    tipShown = false
  }

  function focusedScreen() {
    var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === name) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  // Compares this machine's tips with the ones it had before. On the very
  // first run everything counts as already there; afterwards anything not
  // seen before arrived with an update (or a binding you added).
  function reconcileSeen() {
    if (!bindsLoaded || !stateLoaded) return
    var ids = allRules.map(function(r) { return r.id })
    var now = Date.now()
    var nextFresh = {}
    var keys = Object.keys(fresh)
    for (var i = 0; i < keys.length; i++)
      if (now - fresh[keys[i]] < freshFor && ruleById[keys[i]]) nextFresh[keys[i]] = fresh[keys[i]]

    if (seen !== null) {
      var known = {}
      for (var j = 0; j < seen.length; j++) known[seen[j]] = true
      for (var k = 0; k < ids.length; k++)
        if (!known[ids[k]] && shownCount(ids[k]) === 0) nextFresh[ids[k]] = now
      var merged = seen.concat(ids.filter(function(id) { return !known[id] }))
      seen = merged.slice(-2000)
    } else {
      seen = ids
    }
    fresh = nextFresh
    saveSoon()
  }

  // ------------------------------------------------------------- persistence
  function applyState(raw) {
    var data = null
    try { data = JSON.parse(raw) } catch (e) { data = null }
    if (!data || typeof data !== "object") return
    var idOk = /^[a-z0-9-]{1,80}$/
    paused = data.paused === true

    var clean = {}
    var src = data.progress && typeof data.progress === "object" ? data.progress : {}
    var ids = Object.keys(src).slice(0, 2000)
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i], s = src[id]
      if (!idOk.test(id) || !s || typeof s !== "object") continue
      clean[id] = {
        shown: Math.max(0, Math.min(1000, Number(s.shown) | 0)),
        nextAt: Number(s.nextAt) > 0 ? Number(s.nextAt) : 0,
        known: s.known === true
      }
    }
    progress = clean

    if (Array.isArray(data.seen))
      seen = data.seen.slice(0, 2000).filter(function(x) { return typeof x === "string" && idOk.test(x) })

    var f = {}
    if (data.fresh && typeof data.fresh === "object") {
      var fk = Object.keys(data.fresh).slice(0, 500)
      for (var j = 0; j < fk.length; j++)
        if (idOk.test(fk[j]) && Number(data.fresh[fk[j]]) > 0) f[fk[j]] = Number(data.fresh[fk[j]])
    }
    fresh = f

    if (data.daily && typeof data.daily.date === "string" && data.daily.date.length < 12)
      daily = { date: data.daily.date, count: Math.max(0, Number(data.daily.count) | 0) }
  }

  function saveSoon() { if (stateLoaded) saveTimer.restart() }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.applyState(text())
      root.stateLoaded = true
      root.reconcileSeen()
    }
    onLoadFailed: {
      root.stateLoaded = true
      root.reconcileSeen()
    }
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: stateFile.setText(JSON.stringify({
      version: 2,
      paused: root.paused,
      daily: root.daily,
      fresh: root.fresh,
      seen: root.seen || [],
      progress: root.progress
    }, null, 2) + "\n")
  }

  // ---------------------------------------------------------------- bindings
  Process {
    id: bindsProc
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.length > 4000000) return
        var list = null
        try { list = JSON.parse(text) } catch (e) { list = null }
        if (!Array.isArray(list)) return
        var rules = Catalog.buildRules(list)
        root.allRules = rules
        root.ruleById = root.indexRules(rules)
        root.bindsLoaded = true
        root.reconcileSeen()
      }
    }
  }

  function reloadBinds() { if (!bindsProc.running) bindsProc.running = true }

  // Take over the context of the window that already has focus, without a tip.
  Process {
    id: activeProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.length > 200000) return
        var w = null
        try { w = JSON.parse(text) } catch (e) { w = null }
        if (!w || typeof w["class"] !== "string" || root.lastClass !== "") return
        var klass = w["class"].toLowerCase().slice(0, 120)
        if (Catalog.ignored(klass)) return
        root.lastClass = klass
        root.currentContext = Catalog.classify(klass)
      }
    }
  }

  Component.onCompleted: {
    reloadBinds()
    activeProc.running = true
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      if (event.name === "activewindow") {
        // activewindow>>class,title
        var parts = event.parse(2)
        if (parts.length >= 1) root.onFocusClass(parts[0])
      } else if (event.name === "configreloaded") {
        root.reloadBinds()
      }
    }
  }

  Timer {
    id: debounce
    interval: 450
    onTriggered: root.nextHint(false)
  }

  Timer {
    id: hideTimer
    interval: root.popupDuration
    onTriggered: root.tipShown = false
  }

  // ------------------------------------------------------------------- popup
  PanelWindow {
    id: tipWindow
    screen: root.tipScreen
    visible: root.tipShown || card.opacity > 0
    color: "transparent"
    implicitWidth: Style.space(440)
    implicitHeight: card.implicitHeight + Style.space(8)
    anchors {
      bottom: true
      right: true
    }
    margins {
      right: Style.space(28)
      bottom: Style.space(28)
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "omarchy-shortcut-trainer"
    // An empty input region: clicks go to the window underneath.
    mask: Region {}

    Rectangle {
      id: card
      readonly property color fg: Commons.Color.notifications.text
      readonly property color accent: Commons.Color.accent
      readonly property color dim: Qt.darker(fg, 1.5)

      width: parent.width
      anchors.bottom: parent.bottom
      implicitHeight: body.implicitHeight + Style.space(28)
      radius: Style.cornerRadius
      color: Commons.Color.notifications.background
      border.color: Commons.Color.notifications.border
      border.width: Math.max(1, Style.normalBorderWidth)

      opacity: root.tipShown ? 1 : 0
      scale: root.tipShown ? 1 : 0.97
      transformOrigin: Item.BottomRight
      Behavior on opacity {
        NumberAnimation { duration: Style.duration(root.tipShown ? 180 : 120); easing.type: Easing.OutCubic }
      }
      Behavior on scale {
        NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
      }

      Rectangle {
        x: 0
        y: Style.space(14)
        width: Style.space(3)
        height: parent.height - Style.space(28)
        color: card.accent
      }

      Column {
        id: body
        x: Style.space(18)
        y: Style.space(14)
        width: parent.width - Style.space(36)
        spacing: Style.space(10)

        Text {
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: strings.t("popup.header", "SHORTCUT TRAINER  /  %1").arg(root.contextText(root.hintContext).toUpperCase())
          color: card.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }

        Row {
          width: parent.width
          spacing: Style.space(14)

          Rectangle {
            id: keycap
            width: Math.min(parent.width * 0.55, Math.max(Style.space(120), keysText.implicitWidth + Style.space(24)))
            height: keysText.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(card.accent, 0.12)
            border.color: Util.alpha(card.accent, 0.5)
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: keysText
              anchors.centerIn: parent
              width: Math.min(implicitWidth, parent.width - Style.space(16))
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.hintKeys
              color: card.accent
              font.family: Style.font.family
              font.pixelSize: root.hintKeys.length > 16 ? Style.font.subtitle : Style.font.heading
              font.bold: true
            }
          }

          Text {
            width: parent.width - keycap.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: root.hintId ? root.ruleText(root.hintId) : ""
            color: card.fg
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: (root.hintFresh
                 ? strings.t("popup.fresh", "NEW IN OMARCHY")
                 : root.hintRepetition <= 1
                   ? strings.t("popup.new", "NEW")
                   : strings.t("popup.repeat", "REPETITION %1").arg(Commons.I18n.formatNumber(root.hintRepetition)))
                + "  ·  " + strings.t("popup.markHint", "mark as learned in the bar")
          color: card.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
