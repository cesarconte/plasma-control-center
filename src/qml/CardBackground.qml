/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool interactive: false

    radius: Math.min(Kirigami.Units.gridUnit * 1.1, height / 2)
    color: {
        const base = Kirigami.Theme.alternateBackgroundColor;
        if (pressed) {
            return Qt.darker(base, 1.25);
        }
        if (hovered && interactive) {
            return Qt.tint(base, Qt.rgba(1, 1, 1, 0.14));
        }
        return base;
    }

    border.width: (hovered && interactive) ? 1.5 : 1
    border.color: (hovered && interactive)
        ? Qt.alpha(Kirigami.Theme.highlightColor, 0.75)
        : Qt.alpha(Kirigami.Theme.textColor, 0.08)

    Behavior on color {
        ColorAnimation { duration: Kirigami.Units.shortDuration }
    }
}
