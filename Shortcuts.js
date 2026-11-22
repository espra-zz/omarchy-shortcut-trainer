.pragma library

// Where the tips come from.
//
// Every Hyprland binding that carries a description becomes a tip on its own,
// so shortcuts that arrive with an Omarchy update (or that you add to
// ~/.config/hypr/bindings.lua with a description) need no change here.
//
// The curated list below only adds judgement on top: which shortcuts fit
// which kind of app, which come first, and a friendlier text. Each entry
// names bindings by their description, exactly as `hyprctl binds -j` (and
// SUPER + K) shows it. Numbered families such as "Switch to workspace 3" are
// folded into one tip named like Omarchy's translation key,
// "Switch to workspace %1". An entry whose bindings are missing on this
// machine is dropped rather than showing a wrong key.
//
// `keys` is for app-level shortcuts Hyprland does not know about (the file
// manager ones). Their text lives in i18n/<lang>.json under "rule.<id>".

var curated = [
  { id: "term-fullscreen", context: "terminal", binds: ["Full screen"] },
  { id: "term-split", context: "terminal", binds: ["Toggle window split"] },
  { id: "term-focus", context: "terminal", binds: ["Focus on left window", "Focus on right window"] },
  { id: "term-tmux", context: "terminal", binds: ["Tmux"] },
  { id: "term-quake", context: "terminal", binds: ["Toggle Quake console"] },
  { id: "term-floating", context: "terminal", binds: ["Toggle window floating/tiling"] },

  { id: "browser-width", context: "browser", binds: ["Full width"] },
  { id: "browser-tiled-full", context: "browser", binds: ["Tiled full screen"] },
  { id: "browser-private", context: "browser", binds: ["Browser (private)"] },
  { id: "browser-clipboard", context: "browser", binds: ["Clipboard manager"] },
  { id: "browser-popout", context: "browser", binds: ["Pop window out (float & pin)"] },

  { id: "file-path", context: "files", keys: "CTRL + L" },
  { id: "file-up", context: "files", keys: "ALT + ↑" },
  { id: "file-hidden", context: "files", keys: "CTRL + H" },
  { id: "file-cwd", context: "files", binds: ["File manager (cwd)"] },

  { id: "editor-focus", context: "editor", binds: ["Focus on left window", "Focus on right window"] },
  { id: "editor-swap", context: "editor", binds: ["Swap window to the left", "Swap window to the right"] },
  { id: "editor-scratchpad", context: "editor", binds: ["Toggle scratchpad"] },

  { id: "all-close", context: "all", binds: ["Close window"] },
  { id: "all-workspace", context: "all", binds: ["Switch to workspace %1"] },
  { id: "all-move-ws", context: "all", binds: ["Move window to workspace %1"] },
  { id: "all-menu", context: "all", binds: ["Omarchy menu"] },
  { id: "all-help", context: "all", binds: ["Keybindings"] },
  { id: "all-next-ws", context: "all", binds: ["Next workspace"] },
  { id: "all-group", context: "all", binds: ["Toggle window grouping"] },
  { id: "all-screenshot", context: "all", binds: ["Screenshot"] }
];

var contexts = ["terminal", "browser", "files", "editor", "all"];

function classify(appClass) {
  var klass = String(appClass || "").toLowerCase();
  if (/ghostty|foot|kitty|alacritty|wezterm|konsole|terminal|ptyxis/.test(klass)) return "terminal";
  if (/firefox|chromium|chrome|brave|vivaldi|zen|librewolf/.test(klass)) return "browser";
  if (/thunar|nautilus|dolphin|pcmanfm|nemo/.test(klass)) return "files";
  if (/^code|codium|cursor|windsurf|zed|neovide/.test(klass)) return "editor";
  return "all";
}

// Windows that never get a tip.
function ignored(appClass) {
  return /omarchy-shell|quickshell|rofi|walker|^$/.test(String(appClass || "").toLowerCase());
}

// Bindings that make poor tips: hardware keys, mouse actions, lid switches.
function noise(key) {
  return /^(XF86|mouse|switch:)/.test(String(key || ""));
}

// Hyprland modmask bits, in the order Omarchy writes them.
var MODS = [
  { bit: 64, name: "WIN" },
  { bit: 4, name: "CTRL" },
  { bit: 8, name: "ALT" },
  { bit: 1, name: "SHIFT" }
];

var KEY_NAMES = {
  "RETURN": "ENTER", "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓",
  "ESCAPE": "ESC", "grave": "`", "comma": ",", "PERIOD": ".", "SLASH": "/",
  "BACKSPACE": "⌫", "Delete": "DEL", "DELETE": "DEL", "Home": "HOME"
};

function modLabel(mask) {
  var out = [];
  for (var i = 0; i < MODS.length; i++)
    if (mask & MODS[i].bit) out.push(MODS[i].name);
  return out;
}

function keyLabel(key) {
  var k = String(key || "");
  return KEY_NAMES[k] !== undefined ? KEY_NAMES[k] : k.toUpperCase();
}

function slug(text) {
  return String(text).toLowerCase().replace(/%1/g, "n").replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "").slice(0, 60) || "x";
}

// Turns `hyprctl binds -j` into an ordered list of entries keyed by
// description. The input is untrusted: only fields of the expected type and
// a sane length are used. Numbered families collapse into one entry whose
// description ends in "%1" and which counts its members.
function indexBinds(list) {
  var index = {};
  var order = [];
  if (!Array.isArray(list)) return { index: index, order: order };
  var n = Math.min(list.length, 2000);
  for (var i = 0; i < n; i++) {
    var b = list[i];
    if (!b || typeof b.description !== "string") continue;
    var desc = b.description.trim();
    if (desc.length === 0 || desc.length > 120) continue;
    var key = typeof b.key === "string" ? b.key.slice(0, 40) : "";
    if (noise(key)) continue;
    var mask = Number(b.modmask) | 0;

    var numbered = /^(.*\S)\s+(\d{1,2})$/.exec(desc);
    if (numbered) {
      var template = numbered[1] + " %1";
      var tkey = template.toLowerCase();
      var g = index[tkey];
      if (!g) {
        g = index[tkey] = { desc: template, modmask: mask, key: "", count: 0, numbered: true };
        order.push(tkey);
      }
      if (g.modmask === mask) g.count++;
      continue;
    }

    var dkey = desc.toLowerCase();
    if (index[dkey]) continue; // the first binding for a description wins
    index[dkey] = { desc: desc, modmask: mask, key: key, count: 1, numbered: false };
    order.push(dkey);
  }
  return { index: index, order: order };
}

function entryKeys(e) {
  if (e.numbered) {
    var last = e.count >= 10 ? "0" : String(Math.min(e.count, 9));
    return modLabel(e.modmask).concat(["1 … " + last]).join(" + ");
  }
  if (!e.key) return "";
  return modLabel(e.modmask).concat([keyLabel(e.key)]).join(" + ");
}

// The key text for a curated entry, or "" when it does not apply here.
function resolveCurated(rule, index) {
  if (!rule.binds) return rule.keys || "";
  var found = [];
  for (var i = 0; i < rule.binds.length; i++) {
    var e = index[rule.binds[i].toLowerCase()];
    if (!e || !entryKeys(e)) return "";
    found.push(e);
  }
  if (found.length === 1) return entryKeys(found[0]);
  var sameMods = found.every(function(e) { return e.modmask === found[0].modmask && !e.numbered; });
  if (sameMods) {
    var keys = found.map(function(e) { return keyLabel(e.key); }).join(" / ");
    return modLabel(found[0].modmask).concat([keys]).join(" + ");
  }
  return found.map(entryKeys).join("  ·  ");
}

// The whole catalogue for this machine: curated tips first, in their order,
// then every other described binding in Omarchy's order.
// Each rule: { id, context, keys, desc, curated, order }
//   desc is the English binding description (for Omarchy's translations),
//   or "" for curated app-level tips.
function buildRules(bindList) {
  var built = indexBinds(bindList);
  var index = built.index;
  var rules = [];
  var used = {};
  var ids = {};

  for (var i = 0; i < curated.length; i++) {
    var c = curated[i];
    var keys = resolveCurated(c, index);
    if (c.binds) for (var j = 0; j < c.binds.length; j++) used[c.binds[j].toLowerCase()] = true;
    if (!keys) continue;
    ids[c.id] = true;
    rules.push({ id: c.id, context: c.context, keys: keys,
                 desc: c.binds ? index[c.binds[0].toLowerCase()].desc : "",
                 curated: true, order: rules.length });
  }

  for (var k = 0; k < built.order.length; k++) {
    var dkey = built.order[k];
    if (used[dkey]) continue;
    var e = index[dkey];
    var ekeys = entryKeys(e);
    if (!ekeys) continue;
    var id = "b-" + slug(e.desc);
    var n = 2;
    while (ids[id]) id = "b-" + slug(e.desc).slice(0, 56) + "-" + n++;
    ids[id] = true;
    rules.push({ id: id, context: "all", keys: ekeys, desc: e.desc, curated: false, order: rules.length });
  }
  return rules;
}

// Curated-only rules for the moment before hyprctl has answered.
function staticRules() {
  return curated.filter(function(c) { return !c.binds; }).map(function(c, i) {
    return { id: c.id, context: c.context, keys: c.keys, desc: "", curated: true, order: i };
  });
}

// Replaces %1 in a numbered description with the range it stands for.
function fillNumbered(text, keys) {
  var m = /1 … (\d)$/.exec(String(keys || ""));
  return String(text).replace("%1", m ? "1–" + (m[1] === "0" ? "10" : m[1]) : "N");
}

// What the panel's settings tab offers. The values live on the widget's entry
// in ~/.config/omarchy/shell.json; a value outside its bounds is clamped and
// anything that is not a number falls back to the default.
var settingsSpec = [
  { key: "tipSeconds", def: 5, min: 2, max: 60, choices: [3, 5, 8, 12, 20] },
  { key: "gapSeconds", def: 45, min: 5, max: 3600, choices: [15, 45, 120, 300, 900] },
  { key: "newPerDay", def: 12, min: 0, max: 500, choices: [3, 6, 12, 24, 50] }
];

function readSettings(raw) {
  var out = {};
  for (var i = 0; i < settingsSpec.length; i++) {
    var s = settingsSpec[i];
    var v = raw && typeof raw === "object" ? raw[s.key] : undefined;
    v = typeof v === "number" && isFinite(v) ? Math.round(v) : s.def;
    out[s.key] = Math.max(s.min, Math.min(s.max, v));
  }
  return out;
}
