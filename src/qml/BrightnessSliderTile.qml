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

    implicitWidth: Kirigami.Units.gridUnit * 25
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 4.4)

    readonly property real maxB: Math.max(1, root.backend ? root.backend.brightnessMax : 100)
    readonly property real curB: root.backend ? root.backend.brightness : 100
    readonly property real brightnessRatio: curB / maxB

    CardBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.mediumSpacing
        spacing: Kirigami.Units.smallSpacing

        // Cabecera del control
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                source: "video-display"
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Pantalla")
                font.weight: Font.DemiBold
            }

            PlasmaComponents3.Label {
                text: (root.backend && root.backend.nightLightActive) ? i18n("Luz nocturna activa") : i18n("Brillo")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            PlasmaComponents3.ToolButton {
                icon.name: "preferences-desktop-display"
                display: PlasmaComponents3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                onClicked: if (root.backend) root.backend.openDisplaySettings()
                PlasmaComponents3.ToolTip {
                    text: i18n("Ajustes de Pantalla")
                }
            }
        }

        // Fila de Slider nativo PlasmaComponents3
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                icon.name: {
                    if (root.brightnessRatio < 0.33) return "brightness-low-symbolic";
                    return "brightness-high-symbolic";
                }
                display: PlasmaComponents3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
                onClicked: if (root.backend) root.backend.toggleNightLight()
                PlasmaComponents3.ToolTip {
                    text: (root.backend && root.backend.nightLightActive) ? i18n("Desactivar luz nocturna") : i18n("Activar luz nocturna")
                }
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

            PlasmaComponents3.Label {
                Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.4)
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.brightnessRatio * 100) + "%"
                font: Kirigami.Theme.smallFont
                opacity: 0.85
            }
        }
    }
}
