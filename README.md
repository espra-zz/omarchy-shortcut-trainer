# Shortcut Trainer for Omarchy

Learn Omarchy's keyboard shortcuts while you work. When you switch to an app, a small tip appears in the corner with a shortcut that fits it, and it comes back at growing intervals until you know it.

[Deutsche Anleitung](README.de.md)

## What it does

- **Tips that fit the app.** A terminal gets terminal tips, a browser gets browser tips, and so on. Everything else gets general Omarchy shortcuts.
- **Always your real keys.** Tips are read live from your Hyprland bindings (`hyprctl binds -j`). If you rebind something, the tip follows.
- **Picks up new shortcuts automatically.** Every binding with a description becomes a tip, including ones you add yourself. When an Omarchy update adds shortcuts, they are marked **New in Omarchy** and shown first.
- **Spaced repetition.** Reviews that are due come before new tips. Intervals are 2 min, 10 min, 1 h, 1 day, 3 days, then weekly. At most 12 new tips a day, and never more than one tip every 45 seconds.
- **Bar widget.**
  - Click: opens a panel with the tips for the current app, the new ones, or all of them.
  - Click a tip in the panel: marks it as learned, so it stops appearing.
  - Middle-click: shows a tip right away.
  - Right-click: pauses or resumes tips.
  - The panel works with the keyboard too.
- **Fits Omarchy.**
  - Uses your theme's colours and appears on the monitor you are using.
  - Respects the animations toggle.
  - Follows the Omarchy language setting. Its own texts are in English and German; other shortcut names use Omarchy's translations in all its languages.
- **Private.**
  - No network, no `sudo`, no keyboard hook. It sees only which app has focus.
  - Progress is stored in `~/.local/state/omarchy/shortcut-trainer.json`.

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-shortcut-trainer.git --enable
```

Or from a checkout:

```bash
cp -r omarchy-shortcut-trainer ~/.config/omarchy/plugins/community.shortcut-trainer
omarchy plugin validate ~/.config/omarchy/plugins/community.shortcut-trainer
omarchy plugin enable community.shortcut-trainer --section right
```

## Remove

```bash
omarchy plugin remove community.shortcut-trainer
rm -f ~/.local/state/omarchy/shortcut-trainer.json   # learning progress
```

## Customise

The main settings are in the panel under **Options**:

- **Tip stays on screen:** 3 to 20 seconds (default 5)
- **At least this long between tips:** 15 seconds to 15 minutes (default 45 seconds)
- **New tips a day:** 3 to 50 (default 12). Repetitions are not counted.

They are kept on the widget's entry in `~/.config/omarchy/shell.json`, where you can also set them by hand, even outside the panel's choices (bounds: 2–60 s, 5–3600 s, 0–500):

```json
{ "id": "community.shortcut-trainer", "tipSeconds": 8, "gapSeconds": 120, "newPerDay": 6 }
```

| What | Where |
|---|---|
| Which shortcuts suit which app, and which come first | `curated` in `Shortcuts.js` |
| Which apps count as terminal, browser, files, editor | `classify()` in `Shortcuts.js` |
| Texts for curated tips and the interface | `i18n/<language>.json` |
| Repetition intervals, how long a shortcut counts as new | top of `Service.qml` |

A curated tip names Hyprland bindings by their description, as shown under SUPER + K:

```js
{ id: "all-lock", context: "all", binds: ["Lock system"] },
```

Give it a text in `i18n/en.json` (and other languages) as `"rule.all-lock"`. Without one, Omarchy's own translation of the description is used.

To add your own shortcuts, give your binding a description in `~/.config/hypr/bindings.lua`. It becomes a tip the next time Hyprland reloads.

## Limits

- The trainer cannot tell whether you actually used a shortcut, because Hyprland events do not say which key triggered an action. You mark tips as learned yourself.
- Shortcuts inside apps (tmux, vim, browser) are not covered, apart from a few file manager basics.
- Bindings Hyprland reports only as key codes are left out unless they belong to a numbered family such as workspaces.

## Development

```bash
tests/run                    # unit tests (Node 18+), no running desktop needed
omarchy plugin validate .
```

After changing QML that is already loaded, run `omarchy restart shell`.

## Licence

MIT
