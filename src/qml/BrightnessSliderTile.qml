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

    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 3.8)

    readonly property real maxB: Math.max(1, root.backend ? root.backend.brightnessMax : 100)
    readonly property real curB: root.backend ? root.backend.brightness : 100
    readonly property real brightnessRatio: curB / maxB

    CardBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.mediumSpacing
        spacing: 2

        // Cabecera del control
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Pantalla")
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
            }

            PlasmaComponents3.Label {
                text: (root.backend && root.backend.nightLightActive)
                    ? i18n("Luz nocturna activa • %1%", Math.round(root.brightnessRatio * 100))
                    : (Math.round(root.brightnessRatio * 100) + "%")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                opacity: 0.7
            }
        }

        // Fila de Slider con iconos en los extremos (estilo Apple)
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: "brightness-low-symbolic"
                opacity: 0.8
            }

            PlasmaComponents3.Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: root.brightnessRatio

                onMoved: {
                    if (root.backend) {
                        root.backend.brightness = Math.round(value * root.maxB);
                    }
                }
            }

            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                source: "brightness-high-symbolic"
                opacity: 0.8
            }
        }
    }
}
