/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import CachyOS.UI
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    clip: true

    property bool active: false
    property string statusText: ""

    signal toggled()

    implicitWidth: Kirigami.Units.gridUnit * 12
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.8)

    CardBackground {
        id: bg
        anchors.fill: parent
        interactive: true
        hovered: mouseArea.containsMouse
        pressed: mouseArea.pressed
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: CachyTheme.spacingSmall
        spacing: CachyTheme.spacingSmall

        // Icono circular
        Rectangle {
            Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.1)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Layout.preferredWidth / 2
            color: root.active ? CachyPalette.accentText : Qt.alpha(CachyPalette.text, 0.12)

            Behavior on color {
                ColorAnimation { duration: CachyTheme.animFast }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                source: root.active ? "notifications-disabled-symbolic" : "notifications-symbolic"
                isMask: true
                color: CachyPalette.text
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Concentración")
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                elide: Text.ElideRight
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: root.statusText
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                opacity: 0.75
                elide: Text.ElideRight
            }
        }
    }
}
