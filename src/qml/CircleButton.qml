/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    property string iconName: ""
    property string toolTipText: ""
    property bool active: false
    property real diameter: Math.round(Kirigami.Units.gridUnit * 2.8)

    signal clicked()

    implicitWidth: diameter
    implicitHeight: diameter

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: {
            if (mouseArea.pressed) {
                return root.active ? Qt.darker(Kirigami.Theme.highlightColor, 1.15) : Qt.darker(Kirigami.Theme.alternateBackgroundColor, 1.15);
            }
            if (mouseArea.containsMouse) {
                return root.active ? Qt.lighter(Kirigami.Theme.highlightColor, 1.08) : Qt.lighter(Kirigami.Theme.alternateBackgroundColor, 1.08);
            }
            return root.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.alternateBackgroundColor;
        }

        border.width: 1
        border.color: mouseArea.containsMouse
            ? Qt.alpha(Kirigami.Theme.highlightColor, 0.4)
            : Qt.alpha(Kirigami.Theme.textColor, 0.08)

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
            source: root.iconName
            color: root.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }

    PlasmaComponents3.ToolTip {
        text: root.toolTipText
        visible: mouseArea.containsMouse && root.toolTipText.length > 0
    }
}
