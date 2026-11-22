import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Shortcuts.js" as Catalog

// The bar icon and its panel. The service does the work; the panel shows the
// tips for the app in front, the ones new in Omarchy, or all of them, and
// lets you mark them learned or pause the trainer.
Panel {
  id: root
  moduleName: "community.shortcut-trainer"
  ipcTarget: "community.shortcut-trainer"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property var service: {
    var host = bar && bar.shell ? bar.shell : null
    if (!host || typeof host.serviceFor !== "function") return null
    return host.serviceFor("community.shortcut-trainer")
  }

  // ---------------------------------------------------------------- settings
  // Kept on this widget's entry in shell.json, like the clock's formats, and
  // handed to the service, which does the timing.
  readonly property var prefs: Catalog.readSettings(root.settings)
  readonly property var settingRows: Catalog.settingsSpec

  function pushSettings() { if (service) service.configure(root.settings) }
  onServiceChanged: pushSettings()
  onSettingsChanged: pushSettings()
  Component.onCompleted: pushSettings()

  function setSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    // Applied at once; the shell.json write comes back as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function settingLabel(key) {
    if (key === "tipSeconds") return strings.t("settings.tipSeconds", "Tip stays on screen")
    if (key === "gapSeconds") return strings.t("settings.gapSeconds", "At least this long between tips")
    return strings.t("settings.newPerDay", "New tips a day")
  }
  function choiceText(key, value) {
    if (key === "newPerDay") return Commons.I18n.formatNumber(value)
    if (value >= 60 && value % 60 === 0) return Commons.I18n.formatNumber(value / 60) + " min"
    return Commons.I18n.formatNumber(value) + " s"
  }

  readonly property bool paused: service ? service.paused : false
  readonly property string context: service ? service.currentContext : "all"
  readonly property int total: service ? service.allRules.length : 0
  readonly property int known: service ? service.knownCount : 0
  readonly property int freshCount: service ? service.freshRules.length : 0

  // "app", "fresh", "all" or "settings"
  property string view: "app"
  readonly property var views: freshCount > 0 ? ["app", "fresh", "all", "settings"] : ["app", "all", "settings"]
  readonly property bool inSettings: view === "settings"
  readonly property var shownRules: {
    if (!service || inSettings) return []
    if (view === "all") return service.allRules
    if (view === "fresh") return service.freshRules
    return service.rulesFor(context)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ---------------------------------------------------------- keyboard cursor
  // Rows: 0 pause/now, 1 view tabs, 2.. one per tip (or per setting), last reset.
  readonly property int listStart: 2
  readonly property int rowCount: (inSettings ? settingRows.length : shownRules.length) + 3
  property int cursorRow: 0
  property int cursorCell: 0
  property bool cursorActive: false

  function settingAt(row) {
    return inSettings && row >= listStart && row < listStart + settingRows.length
      ? settingRows[row - listStart] : null
  }
  function cellsIn(row) {
    var s = settingAt(row)
    return row === 0 ? 2 : row === 1 ? views.length : s ? s.choices.length : 1
  }
  function cursorOn(row, cell) {
    return cursorActive && cursorRow === row && (cell === undefined || cursorCell === cell)
  }
  function point(row, cell) { cursorActive = true; cursorRow = row; cursorCell = cell || 0 }
  function moveCursor(dx, dy) {
    if (!cursorActive) { cursorActive = true; return }
    if (dy !== 0) {
      cursorRow = Math.max(0, Math.min(rowCount - 1, cursorRow + dy))
      cursorCell = Math.min(cursorCell, cellsIn(cursorRow) - 1)
      revealRow(cursorRow)
    } else {
      cursorCell = Math.max(0, Math.min(cellsIn(cursorRow) - 1, cursorCell + dx))
      if (cursorRow === 1) setView(views[cursorCell])
    }
  }
  function activateCursor() {
    if (!cursorActive || !service) return
    if (cursorRow === 0) { if (cursorCell === 0) service.setPaused(!paused); else showNow() }
    else if (cursorRow === 1) setView(views[cursorCell])
    else if (cursorRow === rowCount - 1) service.resetProgress()
    else if (settingAt(cursorRow)) {
      const s = settingAt(cursorRow)
      setSetting(s.key, s.choices[cursorCell])
    } else {
      const r = shownRules[cursorRow - listStart]
      if (r) service.setKnown(r.id, !service.isKnown(r.id))
    }
  }
  function revealRow(row) {
    if (inSettings) return
    var i = row - listStart
    if (i < 0 || i >= list.count) return
    var item = list.itemAt(i)
    if (!item) return
    if (item.y < flick.contentY) flick.contentY = item.y
    else if (item.y + item.height > flick.contentY + flick.height)
      flick.contentY = item.y + item.height - flick.height
  }
  function setView(v) {
    view = v
    flick.contentY = 0
  }
  function showNow() {
    if (!service) return
    close()
    service.showNow()
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorRow = 0
    cursorCell = 0
    view = freshCount > 0 ? "fresh" : "app"
    flick.contentY = 0
  }
  onRowCountChanged: if (cursorRow >= rowCount) cursorRow = rowCount - 1
  onViewsChanged: if (views.indexOf(view) < 0) view = "app"

  // ------------------------------------------------------------------- button
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{F030C}"  // nf-md-keyboard
    active: root.freshCount > 0
    opacity: root.paused ? 0.45 : 1
    tooltipText: root.opened ? "" : (root.paused
      ? strings.t("tooltip.paused", "Shortcut trainer paused")
      : root.freshCount > 0
        ? strings.tn("tooltip.fresh", root.freshCount, "%1 new shortcuts in Omarchy").arg(Commons.I18n.formatNumber(root.freshCount))
        : strings.t("tooltip.active", "Shortcut trainer · %1 of %2 learned")
            .arg(Commons.I18n.formatNumber(root.known)).arg(Commons.I18n.formatNumber(root.total)))
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.showNow()
      else if (b === Qt.RightButton) { if (root.service) root.service.setPaused(!root.paused) }
      else root.toggle()
    }
  }

  // -------------------------------------------------------------------- panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- heading ----------
        Column {
          width: parent.width
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: strings.t("panel.title", "Shortcut Trainer")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: strings.t("panel.progress", "%1 OF %2 LEARNED")
              .arg(Commons.I18n.formatNumber(root.known)).arg(Commons.I18n.formatNumber(root.total))
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(3)
          color: Util.alpha(root.bar.foreground, 0.12)
          Rectangle {
            width: root.total > 0 ? parent.width * root.known / root.total : 0
            height: parent.height
            color: Commons.Color.accent
          }
        }

        // ---------- controls ----------
        Row {
          width: parent.width
          spacing: Style.space(6)

          Button {
            width: (parent.width - parent.spacing) / 2
            text: root.paused ? strings.t("panel.resume", "Resume tips") : strings.t("panel.pause", "Pause tips")
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            verticalPadding: Style.space(10)
            bordered: true
            active: root.paused
            hasCursor: root.cursorOn(0, 0)
            onClicked: { if (root.service) root.service.setPaused(!root.paused) }
            onHovered: function(h) { if (h) root.point(0, 0) }
          }
          Button {
            width: (parent.width - parent.spacing) / 2
            text: strings.t("panel.showNow", "Show a tip now")
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            verticalPadding: Style.space(10)
            bordered: true
            hasCursor: root.cursorOn(0, 1)
            onClicked: root.showNow()
            onHovered: function(h) { if (h) root.point(0, 1) }
          }
        }

        // ---------- view tabs ----------
        Row {
          id: tabs
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.views
            Button {
              required property string modelData
              required property int index
              width: (tabs.width - tabs.spacing * (root.views.length - 1)) / root.views.length
              text: modelData === "app"
                ? (root.service ? root.service.contextText(root.context) : "")
                : modelData === "fresh"
                  ? strings.t("panel.tabFresh", "New · %1").arg(Commons.I18n.formatNumber(root.freshCount))
                  : modelData === "settings"
                    ? strings.t("panel.tabSettings", "Options")
                    : strings.t("panel.tabAll", "All · %1").arg(Commons.I18n.formatNumber(root.total))
              fontSize: Style.font.caption
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              verticalPadding: Style.space(7)
              selected: root.view === modelData
              hasCursor: root.cursorOn(1, index)
              onClicked: root.setView(modelData)
              onHovered: function(h) { if (h) root.point(1, index) }
            }
          }
        }

        Text {
          visible: root.view === "fresh"
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: strings.t("panel.freshNote", "These shortcuts arrived with an Omarchy update or a new binding. They come first as tips.")
          color: root.bar.foreground
          opacity: 0.6
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        // ---------- settings ----------
        Column {
          visible: root.inSettings
          width: parent.width
          spacing: Style.space(12)

          Repeater {
            model: root.settingRows
            SettingRow {}
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: strings.t("settings.note", "Tips come when you switch apps. Saved in ~/.config/omarchy/shell.json.")
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // ---------- tips ----------
        Flickable {
          id: flick
          visible: !root.inSettings
          width: parent.width
          height: Math.min(contentHeight, Style.space(330))
          contentHeight: listColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          Column {
            id: listColumn
            width: flick.width
            spacing: Style.space(2)

            Repeater {
              id: list
              model: root.shownRules
              delegate: RuleRow {}
            }
          }
        }

        Text {
          visible: !root.inSettings && root.shownRules.length === 0
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: strings.t("panel.empty", "No shortcuts found. Your Hyprland bindings may not have descriptions.")
          color: root.bar.foreground
          opacity: 0.6
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        PanelSeparator { width: parent.width; foreground: root.bar.foreground }

        Button {
          width: parent.width
          text: strings.t("panel.reset", "Reset progress")
          fontSize: Style.font.caption
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          verticalPadding: Style.space(6)
          hasCursor: root.cursorOn(root.rowCount - 1)
          onClicked: { if (root.service) root.service.resetProgress() }
          onHovered: function(h) { if (h) root.point(root.rowCount - 1) }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: strings.t("panel.footer", "Click a shortcut to mark it learned. Middle-click the icon for a tip, right-click to pause.")
          color: root.bar.foreground
          opacity: 0.5
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  // One setting: its name, then a chip per choice.
  component SettingRow: Column {
    id: setting
    required property var modelData
    required property int index
    readonly property int cursorIndex: root.listStart + index
    readonly property int current: root.prefs[modelData.key]

    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      elide: Text.ElideRight
      text: root.settingLabel(setting.modelData.key)
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Row {
      id: chips
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: setting.modelData.choices
        Button {
          required property var modelData
          required property int index
          width: (chips.width - chips.spacing * (setting.modelData.choices.length - 1)) / setting.modelData.choices.length
          text: root.choiceText(setting.modelData.key, modelData)
          fontSize: Style.font.caption
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          verticalPadding: Style.space(7)
          selected: setting.current === modelData
          hasCursor: root.cursorOn(setting.cursorIndex, index)
          onClicked: root.setSetting(setting.modelData.key, modelData)
          onHovered: function(h) { if (h) root.point(setting.cursorIndex, index) }
        }
      }
    }
  }

  // One tip: mark · keys · text. A click toggles "learned".
  component RuleRow: Rectangle {
    id: row
    required property var modelData
    required property int index
    readonly property int cursorIndex: root.listStart + index
    readonly property bool isKnown: root.service ? root.service.isKnown(modelData.id) : false
    readonly property bool isFresh: root.service ? root.service.isFresh(modelData.id) : false
    readonly property bool hot: rowMouse.containsMouse || root.cursorOn(cursorIndex)

    width: parent ? parent.width : 0
    implicitHeight: Math.max(keysLabel.implicitHeight, descLabel.implicitHeight) + Style.space(12)
    radius: Style.cornerRadius
    color: hot ? Style.hoverFillFor(root.bar.foreground, Commons.Color.accent) : "transparent"
    border.width: root.cursorOn(cursorIndex) ? Math.max(1, Style.focusBorderWidth) : 0
    border.color: Style.focusBorderFor(root.bar.foreground, Commons.Color.accent)

    Text {
      id: mark
      x: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: row.isKnown ? "✓" : (row.isFresh ? "★" : "○")
      color: row.isKnown || row.isFresh ? Commons.Color.accent : root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }
    Text {
      id: keysLabel
      anchors.left: mark.right
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(row.width * 0.42)
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      text: row.modelData.keys
      color: row.isKnown ? Qt.darker(root.bar.foreground, 1.6) : Commons.Color.accent
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    Text {
      id: descLabel
      anchors.left: keysLabel.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      text: root.service ? root.service.ruleText(row.modelData.id) : ""
      color: root.bar.foreground
      opacity: row.isKnown ? 0.5 : 1
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.strikeout: row.isKnown
    }
    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.point(row.cursorIndex)
      onClicked: { if (root.service) root.service.setKnown(row.modelData.id, !row.isKnown) }
    }
  }
}
