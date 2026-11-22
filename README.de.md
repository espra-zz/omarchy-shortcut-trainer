# Shortcut Trainer für Omarchy

Lerne Omarchys Tastenkürzel nebenbei. Wenn du in eine App wechselst, erscheint unten rechts ein kleiner Tipp mit einem passenden Shortcut. Er kommt in wachsenden Abständen wieder, bis du ihn kannst.

## Was es macht

- **Tipps passend zur App.** Im Terminal gibt es Terminal-Tipps, im Browser Browser-Tipps und so weiter. Sonst gibt es allgemeine Omarchy-Shortcuts.
- **Immer deine echten Tasten.** Die Tipps werden live aus deinen Hyprland-Bindings gelesen (`hyprctl binds -j`). Wenn du etwas umbelegst, zieht der Tipp mit.
- **Neue Shortcuts kommen von selbst dazu.** Jedes Binding mit Beschreibung wird ein Tipp, auch deine eigenen. Bringt ein Omarchy-Update neue Shortcuts, werden sie als **Neu in Omarchy** markiert und zuerst gezeigt.
- **Wiederholung in Abständen.** Fällige Wiederholungen kommen vor neuen Tipps. Die Abstände sind 2 min, 10 min, 1 h, 1 Tag, 3 Tage, danach wöchentlich. Höchstens 12 neue Tipps pro Tag und nie mehr als ein Tipp alle 45 Sekunden.
- **Symbol in der Leiste.**
  - Klick: öffnet ein Panel mit den Tipps für die aktuelle App, den neuen oder allen.
  - Klick auf einen Tipp im Panel: markiert ihn als gelernt, dann kommt er nicht mehr.
  - Mittelklick: zeigt sofort einen Tipp.
  - Rechtsklick: pausiert die Tipps oder setzt sie fort.
  - Das Panel lässt sich auch mit der Tastatur bedienen.
- **Passt zu Omarchy.**
  - Nutzt die Farben deines Themes und erscheint auf dem Monitor, an dem du arbeitest.
  - Respektiert die Einstellung, mit der man Animationen ausschaltet.
  - Folgt der Omarchy-Sprache: Die eigenen Texte gibt es auf Deutsch und Englisch, alle anderen Shortcut-Namen kommen aus Omarchys eigenen Übersetzungen.
- **Privat.**
  - Kein Netzwerk, kein `sudo`, kein Tastatur-Hook. Das Plugin sieht nur, welche App im Vordergrund ist.
  - Der Fortschritt liegt in `~/.local/state/omarchy/shortcut-trainer.json`.

## Installation

```bash
omarchy plugin add https://github.com/<du>/omarchy-shortcut-trainer.git --enable
```

## Entfernen

```bash
omarchy plugin remove community.shortcut-trainer
rm -f ~/.local/state/omarchy/shortcut-trainer.json   # Lernfortschritt
```

## Anpassen

Die wichtigsten Einstellungen findest du im Panel unter **Optionen**:

- **Tipp bleibt sichtbar:** 3 bis 20 Sekunden (Standard 5)
- **Mindestabstand zwischen zwei Tipps:** 15 Sekunden bis 15 Minuten (Standard 45 Sekunden)
- **Neue Tipps pro Tag:** 3 bis 50 (Standard 12). Wiederholungen zählen nicht mit.

Die Werte stehen im Eintrag des Widgets in `~/.config/omarchy/shell.json`. Dort kannst du sie auch von Hand setzen, sogar außerhalb der Auswahl im Panel (Grenzen: 2–60 s, 5–3600 s, 0–500):

```json
{ "id": "community.shortcut-trainer", "tipSeconds": 8, "gapSeconds": 120, "newPerDay": 6 }
```

| Was | Wo |
|---|---|
| Welche Shortcuts zu welcher App passen und welche zuerst kommen | `curated` in `Shortcuts.js` |
| Welche Apps als Terminal, Browser, Dateimanager oder Editor gelten | `classify()` in `Shortcuts.js` |
| Texte für die ausgewählten Tipps und die Oberfläche | `i18n/<sprache>.json` |
| Wiederholungsabstände, wie lange ein Shortcut als neu gilt | oben in `Service.qml` |

Eigene Shortcuts: Gib deinem Binding in `~/.config/hypr/bindings.lua` eine Beschreibung. Nach dem nächsten Neuladen von Hyprland ist es ein Tipp.

## Grenzen

- Ob du einen Shortcut wirklich benutzt, erkennt das Plugin nicht, weil Hyprland nicht verrät, welche Taste eine Aktion ausgelöst hat. Gelernte Tipps markierst du selbst.
- Shortcuts innerhalb von Programmen (tmux, vim, Browser) sind nicht dabei, außer ein paar Grundlagen für den Dateimanager.
