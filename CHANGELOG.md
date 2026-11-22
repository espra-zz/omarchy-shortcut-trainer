# Changelog

## 0.4.0

- Options tab in the panel: how long a tip stays on screen, the least time between tips, and how many new tips come a day. Saved on the widget's entry in `~/.config/omarchy/shell.json`.

## 0.3.0

- Every Hyprland binding with a description is now a tip (about 150 on a stock Omarchy), so shortcuts from Omarchy updates or your own bindings appear without changes to the plugin.
- Shortcuts that arrive later are marked "New in Omarchy", shown first, and listed in their own panel tab.
- Tip names fall back to Omarchy's own translations of binding descriptions.
- Due reviews come before new tips, with at most 12 new tips a day. A weekly interval was added after 3 days.
- Panel: tabs for the current app, new shortcuts and all shortcuts, with a scrollable list.
- Unit tests and CI.

## 0.2.0

- Keys are read live from Hyprland bindings instead of being hard-coded.
- Bar widget with a panel: mark tips learned, pause, show a tip now.
- Progress persists across restarts.
- Popup follows the theme, the focused monitor and the animations setting.
- German and English.

## 0.1.0

- First prototype: tips by window class with spaced repetition in memory.
