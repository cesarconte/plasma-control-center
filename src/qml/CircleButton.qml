/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import CachyOS.UI
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    clip: true


    property string iconName: ""
    property string toolTipText: ""
    property bool active: false
    property real diameter: Math.round(Kirigami.Units.gridUnit * 2.8)

    signal clicked()
    signal rightClicked(var mouse)

    implicitWidth: diameter
    implicitHeight: diameter

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height, root.diameter)
        height: width
        radius: width / 2
        color: {
            if (mouseArea.pressed) {
                return root.active ? Qt.darker(CachyTheme.accentColor, 1.25) : Qt.darker(CachyPalette.cardBackground, 1.25);
            }
            if (mouseArea.containsMouse) {
                return root.active ? Qt.lighter(CachyTheme.accentColor, 1.15) : Qt.lighter(CachyPalette.cardBackground, 1.15);
            }
            return root.active ? CachyTheme.accentColor : CachyPalette.cardBackground;
        }

        border.width: 1
        border.color: mouseArea.containsMouse
            ? Qt.alpha(CachyTheme.accentColor, 0.7)
            : Qt.alpha(CachyPalette.text, 0.10)

        Behavior on color {
            ColorAnimation { duration: CachyTheme.animFast }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
            source: root.iconName
            isMask: true
            color: CachyPalette.text
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked(mouse);
            } else {
                root.clicked();
            }
        }
    }

    PlasmaComponents3.ToolTip {
        text: root.toolTipText
        visible: mouseArea.containsMouse && root.toolTipText.length > 0
    }
}
