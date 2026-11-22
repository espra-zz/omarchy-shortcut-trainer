// Unit tests for Shortcuts.js. Run with tests/run (needs Node 18+).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const here = new URL(".", import.meta.url);
const source = readFileSync(new URL("../Shortcuts.js", here), "utf8").replace(".pragma library", "");
const C = new Function(source + "; return { curated, buildRules, indexBinds, classify, ignored, fillNumbered, staticRules, settingsSpec, readSettings };")();
const binds = JSON.parse(readFileSync(new URL("fixture-binds.json", here), "utf8"));
const rules = C.buildRules(binds);
const byId = Object.fromEntries(rules.map(r => [r.id, r]));

test("curated tips take their keys from the live bindings", () => {
  assert.equal(byId["term-fullscreen"].keys, "WIN + F");
  assert.equal(byId["term-tmux"].keys, "WIN + ALT + ENTER");
  assert.equal(byId["term-focus"].keys, "WIN + ← / →");
});

test("the first binding for a description wins", () => {
  assert.equal(byId["all-close"].keys, "WIN + W");
});

test("curated tips without a binding on this machine are dropped", () => {
  assert.equal(byId["browser-width"], undefined);
  assert.equal(byId["all-screenshot"], undefined);
});

test("app-level tips are kept without bindings", () => {
  assert.equal(byId["file-path"].keys, "CTRL + L");
  assert.equal(C.staticRules().length, 3);
});

test("numbered families fold into one tip", () => {
  assert.equal(byId["all-workspace"].keys, "WIN + 1 … 3");
  assert.equal(byId["all-workspace"].desc, "Switch to workspace %1");
  assert.equal(byId["b-bar-panel-n"].keys, "WIN + CTRL + 1 … 2");
  assert.equal(C.fillNumbered("Leistenpanel %1", byId["b-bar-panel-n"].keys), "Leistenpanel 1–2");
});

test("every other described binding becomes a tip", () => {
  assert.equal(byId["b-color-picker"].keys, "WIN + PRINT");
  assert.equal(byId["b-dismiss-invoke-or-focus-last-notification"].keys, "WIN + ,");
  assert.ok(!byId["b-color-picker"].curated);
  assert.equal(byId["b-color-picker"].context, "all");
});

test("hardware keys, mouse, switches, keyless and malformed entries are skipped", () => {
  const descs = rules.map(r => r.desc);
  assert.ok(!descs.includes("Volume up"));
  assert.ok(!descs.includes("Move window"));
  assert.ok(!descs.includes("Expand window left"));
  assert.ok(rules.every(r => typeof r.keys === "string" && r.keys.length > 0));
});

test("curated descriptions are not repeated as automatic tips", () => {
  assert.equal(rules.filter(r => r.desc === "Full screen").length, 1);
});

test("ids are unique and fit the state file pattern", () => {
  const ids = rules.map(r => r.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const id of ids) assert.match(id, /^[a-z0-9-]{1,80}$/);
});

test("curated tips come first", () => {
  const firstAuto = rules.findIndex(r => !r.curated);
  assert.ok(rules.slice(firstAuto).every(r => !r.curated));
});

test("garbage input yields no bindings-based tips", () => {
  assert.deepEqual(C.buildRules(null).map(r => r.id), C.staticRules().map(r => r.id));
  assert.deepEqual(C.buildRules("x").map(r => r.id), C.staticRules().map(r => r.id));
});

test("apps map to contexts", () => {
  assert.equal(C.classify("com.mitchellh.ghostty"), "terminal");
  assert.equal(C.classify("org.gnome.Nautilus"), "files");
  assert.equal(C.classify("chromium"), "browser");
  assert.equal(C.classify("code"), "editor");
  assert.equal(C.classify("signal"), "all");
  assert.ok(C.ignored("org.quickshell"));
  assert.ok(C.ignored(""));
});

test("every curated tip has a text in every catalog", () => {
  for (const lang of ["en", "de"]) {
    const cat = JSON.parse(readFileSync(new URL(`../i18n/${lang}.json`, here), "utf8"));
    for (const c of C.curated) assert.ok(cat["rule." + c.id], `${lang}: rule.${c.id}`);
  }
});

test("catalogs have the same keys", () => {
  const en = Object.keys(JSON.parse(readFileSync(new URL("../i18n/en.json", here), "utf8"))).sort();
  const de = Object.keys(JSON.parse(readFileSync(new URL("../i18n/de.json", here), "utf8"))).sort();
  assert.deepEqual(de, en);
});

// Binding descriptions and key names come from outside the plugin. A QML Text
// left on AutoText would render markup-shaped input as rich text.
test("markup-shaped bindings stay plain strings", () => {
  const r = rules.find(r => r.desc === "<b>Markup</b> in a description");
  assert.ok(r);
  assert.equal(r.keys, "WIN + <IMG SRC=X>");
});

test("every QML Text renders plain text", () => {
  for (const file of ["Service.qml", "BarWidget.qml"]) {
    const qml = readFileSync(new URL("../" + file, here), "utf8");
    const blocks = qml.split(/^\s*Text \{/m).slice(1);
    for (const block of blocks) {
      const body = block.slice(0, block.search(/^\s*\}/m));
      assert.match(body, /textFormat: Text\.PlainText/, `${file}: a Text without PlainText`);
    }
  }
});

test("settings fall back to defaults and stay in bounds", () => {
  assert.deepEqual(C.readSettings(undefined), { tipSeconds: 5, gapSeconds: 45, newPerDay: 12 });
  assert.deepEqual(C.readSettings({ id: "x", tipSeconds: "8", gapSeconds: NaN, newPerDay: null }),
    { tipSeconds: 5, gapSeconds: 45, newPerDay: 12 });
  assert.deepEqual(C.readSettings({ tipSeconds: 999, gapSeconds: 1, newPerDay: -3 }),
    { tipSeconds: 60, gapSeconds: 5, newPerDay: 0 });
  assert.equal(C.readSettings({ tipSeconds: 7.6 }).tipSeconds, 8);
});

test("every offered choice is a valid setting, the default among them", () => {
  for (const s of C.settingsSpec) {
    assert.ok(s.choices.includes(s.def), s.key);
    for (const v of s.choices) assert.equal(C.readSettings({ [s.key]: v })[s.key], v);
  }
});
