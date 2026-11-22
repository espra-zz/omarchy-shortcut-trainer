# Shortcut Trainer – notes for agents

An Omarchy shell plugin (Quickshell/QML) with plugin id `community.shortcut-trainer`.
The user-facing docs are in `README.md` and `README.de.md`, and `CHANGELOG.md` lists the changes.

## Layout

- `Service.qml`: the trainer itself. It is mounted once in omarchy-shell and does the focus tracking, tip picking, spaced repetition, the popup and the saved state (`~/.local/state/omarchy/shortcut-trainer.json`).
- `BarWidget.qml`: the bar icon and panel, with the tabs app / new / all / options. It reaches the service through `bar.shell.serviceFor(...)`.
- `Shortcuts.js`: pure logic with no QML. It holds the curated tips, `buildRules` from `hyprctl binds -j`, and `settingsSpec` with `readSettings`. Logic that can be tested belongs here.
- `i18n/<lang>.json`: flat string catalogs. Every new UI string goes into both `en.json` and `de.json`.
- `tests/`: Node unit tests for `Shortcuts.js`, plus a check that every QML `Text` sets `textFormat: Text.PlainText`.

## Settings

The user settings `tipSeconds`, `gapSeconds` and `newPerDay` live on the widget's entry in `~/.config/omarchy/shell.json`.
The panel writes them with `bar.shell.updateEntryInline(moduleName, entry)`, and the shell hands them back as the widget's `settings`.
The widget then pushes them to the service through `service.configure(settings)`.
Bounds and defaults are defined in `settingsSpec` in `Shortcuts.js`.

## Workflow

1. Edit the files here. This is the source of truth.
2. Run `tests/run`. CI (`.github/workflows/tests.yml`) runs on Node 22, so do not rely on newer Node behaviour.
3. Install into the live shell:
   ```bash
   rsync -a --exclude .git --exclude .github --exclude .gitignore --exclude tests --exclude CLAUDE.md \
     ./ ~/.config/omarchy/plugins/community.shortcut-trainer/
   omarchy restart shell
   ```
   The shell's hot reload has not reliably picked up changed QML here, so restart it. Check for errors with `journalctl --user --since -2min | grep -v 'Local plugin changed'`.
4. For a user-visible change, bump `version` in `manifest.json` and add an entry to `CHANGELOG.md`.

## Rules

- Follow Omarchy's plugin conventions: use `Style.duration()` for animations, read translations through `Commons.Translations`, and treat all dynamic text as plain text.
- Never edit `/usr/share/omarchy/`. You may read it to check the shell's plugin APIs.
- The repo is public at `github.com/espra-zz/omarchy-shortcut-trainer`. The repo-local git `user.email` is the GitHub noreply address, so keep it. Never commit with a private email address.
