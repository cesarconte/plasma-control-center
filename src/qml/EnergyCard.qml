/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

Item {
    id: root

    readonly property var backend: Plasmoid.backend

    implicitWidth: Kirigami.Units.gridUnit * 12
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 5.9)

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
        onClicked: if (root.backend) root.backend.cyclePowerProfile()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.mediumSpacing
        spacing: Kirigami.Units.smallSpacing

        // Icono circular grande superior
        Rectangle {
            Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.4)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Layout.preferredWidth / 2
            color: (root.backend && root.backend.powerProfile === "performance")
                ? Kirigami.Theme.highlightColor
                : Qt.alpha(Kirigami.Theme.textColor, 0.12)

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
                source: {
                    if (!root.backend) return "battery";
                    if (root.backend.powerProfile === "performance") return "speedometer";
                    if (root.backend.powerProfile === "power-saver") return "battery-low";
                    return "battery";
                }
                color: (root.backend && root.backend.powerProfile === "performance")
                    ? Kirigami.Theme.highlightedTextColor
                    : Kirigami.Theme.textColor
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Título y estado
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: i18n("Energía")
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: {
                if (!root.backend) return i18n("Equilibrado");
                if (root.backend.powerProfile === "performance") return i18n("Rendimiento");
                if (root.backend.powerProfile === "power-saver") return i18n("Ahorro de energía");
                return i18n("Equilibrado");
            }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
            opacity: 0.75
            elide: Text.ElideRight
        }
    }
}
