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
import org.kde.plasma.plasmoid

Item {
    id: root

    clip: true

    readonly property var backend: Plasmoid.backend

    signal clicked()
    signal detailsClicked()

    readonly property real maxB: Math.max(1, root.backend ? root.backend.brightnessMax : 100)
    readonly property real curB: root.backend ? root.backend.brightness : 100
    readonly property real brightnessRatio: curB / maxB

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
        acceptedButtons: Qt.LeftButton
        onClicked: {
            root.clicked();
            root.detailsClicked();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: CachyTheme.marginCard
        spacing: 2

        // Línea 1: Título "Brillo"
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: i18n("Brillo")
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
            elide: Text.ElideRight
        }

        // Línea 2: Icono de brillo + Scroll (Slider) + Porcentaje
        RowLayout {
            Layout.fillWidth: true
            spacing: CachyTheme.spacingSmall

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

            CachySlider {
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
                Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.2)
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.brightnessRatio * 100) + "%"
                font: Kirigami.Theme.smallFont
                opacity: 0.85
            }
        }
    }
}
