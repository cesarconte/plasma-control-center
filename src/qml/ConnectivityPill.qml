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

    property string iconName: ""
    property string title: ""
    property string statusText: ""
    property bool active: false

    signal toggled()
    signal detailsClicked()

    implicitWidth: Kirigami.Units.gridUnit * 12
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.8)

    CardBackground {
        anchors.fill: parent
        interactive: true
        hovered: pillMouse.containsMouse || circleMouse.containsMouse
        pressed: pillMouse.pressed
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: CachyTheme.spacingSmall
        spacing: CachyTheme.spacingSmall

        // Icono circular interactivo
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
                source: root.iconName
                isMask: true
                color: CachyPalette.text
            }

            MouseArea {
                id: circleMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.detailsClicked();
                    } else {
                        root.toggled();
                    }
                }
            }
        }

        // Título y estado
        MouseArea {
            id: pillMouse
            Layout.fillWidth: true
            Layout.fillHeight: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.detailsClicked()

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 2
                spacing: 1

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.title
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

        // Chevron para detalles
        PlasmaComponents3.ToolButton {
            icon.name: "go-next-symbolic"
            display: PlasmaComponents3.AbstractButton.IconOnly
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            onClicked: root.detailsClicked()
        }
    }
}
