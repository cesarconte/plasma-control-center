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
import org.kde.plasma.private.volume as PlasmaAudio

Item {
    id: root

    readonly property var backend: Plasmoid.backend

    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 3.8)

    readonly property var currentSink: PlasmaAudio.PreferredDevice.sink
    readonly property real volumePercent: currentSink ? (currentSink.volume / 65536.0) : 0.0
    readonly property bool isMuted: currentSink ? currentSink.muted : false

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
                text: i18n("Sonido")
                font.weight: Font.DemiBold
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
            }

            PlasmaComponents3.Label {
                text: root.currentSink ? root.currentSink.description : i18n("Salida por defecto")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                opacity: 0.7
                elide: Text.ElideRight
                Layout.maximumWidth: root.width * 0.5
            }
        }

        // Fila de Slider con iconos en los extremos y selector de salida a la derecha
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                icon.name: {
                    if (root.isMuted || root.volumePercent === 0) return "audio-volume-muted-symbolic";
                    if (root.volumePercent < 0.33) return "audio-volume-low-symbolic";
                    if (root.volumePercent < 0.66) return "audio-volume-medium-symbolic";
                    return "audio-volume-high-symbolic";
                }
                display: PlasmaComponents3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.small
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

            PlasmaComponents3.Slider {
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

            PlasmaComponents3.ToolButton {
                icon.name: "audio-speakers-symbolic"
                display: PlasmaComponents3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                onClicked: if (root.backend) root.backend.openAudioSettings()
                PlasmaComponents3.ToolTip {
                    text: i18n("Ajustes de Sonido")
                }
            }
        }
    }
}
