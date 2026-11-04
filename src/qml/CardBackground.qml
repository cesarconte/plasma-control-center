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

    radius: Kirigami.Units.gridUnit * 0.7
    color: {
        const base = Kirigami.Theme.alternateBackgroundColor;
        if (pressed) {
            return Qt.darker(base, 1.15);
        }
        if (hovered && interactive) {
            return Qt.lighter(base, 1.08);
        }
        return base;
    }

    border.width: 1
    border.color: (hovered && interactive)
        ? Qt.alpha(Kirigami.Theme.highlightColor, 0.4)
        : Qt.alpha(Kirigami.Theme.textColor, 0.08)
}
