#!/usr/bin/env bash
# Swaps the stock System Tray of every panel for Plasma Control Centre (or back with --restore).
# The stock applet is not uninstalled; its panel entry (and settings) is removed, so make sure
# you are fine with re-selecting which entries to show.
set -euo pipefail

FROM=org.kde.plasma.systemtray
TO=org.cesar.plasmacontrolcenter
if [ "${1:-}" = "--restore" ]; then
    FROM=org.cesar.plasmacontrolcenter
    TO=org.kde.plasma.systemtray
fi

SCRIPT=$(cat <<JS
var swapped = 0;
panels().forEach(function (panel) {
    panel.widgets().forEach(function (widget) {
        if (widget.type === "$FROM") {
            var index = widget.index;
            widget.remove();
            var replacement = panel.addWidget("$TO");
            replacement.index = index;
            swapped++;
        }
    });
});
print("Swapped " + swapped + " widget(s): $FROM -> $TO");
JS
)

qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$SCRIPT"
