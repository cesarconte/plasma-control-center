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
import org.kde.plasma.private.volume as PlasmaAudio

Item {
    id: root

    clip: true

    readonly property var backend: Plasmoid.backend

    signal clicked()
    signal detailsClicked()

    readonly property var currentSink: PlasmaAudio.PreferredDevice.sink
    readonly property real volumePercent: currentSink ? (currentSink.volume / 65536.0) : 0.0
    readonly property bool isMuted: currentSink ? currentSink.muted : false

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

        // Línea 1: Título "Sonido" + Chevron
        RowLayout {
            Layout.fillWidth: true
            spacing: CachyTheme.spacingSmall

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Sonido")
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                elide: Text.ElideRight
            }

            PlasmaComponents3.ToolButton {
                icon.name: "go-next-symbolic"
                display: PlasmaComponents3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                onClicked: {
                    root.detailsClicked();
                }
            }
        }

        // Línea 2: Icono de sonido + Scroll (Slider) + Porcentaje
        RowLayout {
            Layout.fillWidth: true
            spacing: CachyTheme.spacingSmall

            PlasmaComponents3.ToolButton {
                icon.name: {
                    if (root.isMuted || root.volumePercent === 0) return "audio-volume-muted-symbolic";
                    if (root.volumePercent < 0.33) return "audio-volume-low-symbolic";
                    if (root.volumePercent < 0.66) return "audio-volume-medium-symbolic";
                    return "audio-volume-high-symbolic";
                }
                display: PlasmaComponents3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
                onClicked: {
                    if (root.currentSink) {
                        root.currentSink.muted = !root.currentSink.muted;
                    }
                }
                PlasmaComponents3.ToolTip {
                    text: root.isMuted ? i18n("Activar sonido") : i18n("Silenciar")
                }
            }

            CachySlider {
                id: soundSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: root.volumePercent

                onMoved: {
                    if (root.currentSink) {
                        root.currentSink.volume = Math.round(value * 65536);
                    }
                }
            }

            PlasmaComponents3.Label {
                Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.2)
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volumePercent * 100) + "%"
                font: Kirigami.Theme.smallFont
                opacity: 0.85
            }
        }
    }
}
