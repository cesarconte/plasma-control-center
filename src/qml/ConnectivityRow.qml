/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    property string iconName: ""
    property string title: ""
    property string statusText: ""
    property bool active: false

    signal toggled()
    signal detailsClicked()

    implicitWidth: Kirigami.Units.gridUnit * 13
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.5)

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // Icono circular interactivo (botón de conmutación)
        Rectangle {
            Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.0)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Layout.preferredWidth / 2
            color: root.active ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.10)

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
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        // Título y estado interactivo
        MouseArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailsClicked()

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing
                spacing: 1

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.statusText
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                    elide: Text.ElideRight
                }
            }
        }

        // Botón chevron para ajustes de este subsistema
        PlasmaComponents3.ToolButton {
            icon.name: "go-next-symbolic"
            display: PlasmaComponents3.AbstractButton.IconOnly
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
            onClicked: root.detailsClicked()
        }
    }
}
