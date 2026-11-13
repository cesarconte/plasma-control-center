/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import CachyOS.UI

Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool interactive: false

    radius: Math.min(Kirigami.Units.gridUnit * 1.1, height / 2)
    color: {
        const base = CachyPalette.cardBackground;
        if (pressed) {
            return Qt.darker(base, 1.25);
        }
        if (hovered && interactive) {
            return Qt.tint(base, Qt.rgba(1, 1, 1, 0.22));
        }
        return base;
    }

    border.width: (hovered && interactive) ? 2 : 1
    border.color: (hovered && interactive)
        ? Qt.alpha(CachyTheme.accentColor, 0.9)
        : Qt.alpha(CachyPalette.text, 0.10)

    Behavior on color {
        ColorAnimation { duration: CachyTheme.animFast }
    }
    Behavior on border.width {
        NumberAnimation { duration: CachyTheme.animFast }
    }
}
