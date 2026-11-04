/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.notificationmanager as NotificationManager

Item {
    id: popup

    readonly property var backend: Plasmoid.backend

    NotificationManager.Settings {
        id: notifSettings
        live: true
    }

    readonly property bool notificationsInhibited: {
        const until = notifSettings.notificationsInhibitedUntil;
        const timeValid = until !== undefined && until !== null && !isNaN(until.getTime()) && until.getTime() > Date.now();
        return timeValid || notifSettings.notificationsInhibitedByApplication;
    }

    function toggleDoNotDisturb(): void {
        if (popup.notificationsInhibited) {
            notifSettings.notificationsInhibitedUntil = undefined;
            notifSettings.revokeApplicationInhibitions();
            notifSettings.save();
        } else {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            notifSettings.notificationsInhibitedUntil = d;
            notifSettings.save();
        }
    }

    implicitWidth: Kirigami.Units.gridUnit * 25
    implicitHeight: controlCenterContent.implicitHeight + trayHeading.height + Kirigami.Units.largeSpacing * 2

    Layout.minimumWidth: Kirigami.Units.gridUnit * 23
    Layout.minimumHeight: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
    Layout.preferredHeight: systemTrayState.activeApplet ? Kirigami.Units.gridUnit * 24 : implicitHeight

    property var hiddenLayout: dummyHiddenLayout
    property alias plasmoidContainer: container

    Item {
        id: dummyHiddenLayout
        property int itemCount: (typeof hiddenModel !== "undefined" && hiddenModel) ? hiddenModel.count : 0
        property int currentIndex: -1
        property var board: ({ order: [] })
        function forceActiveFocus() {}
        function moveTileByOffset(idx, offset) {}
        function moveTileToIndex(idx, target) {}
    }

    // Header
    PlasmaExtras.PlasmoidHeading {
        id: plasmoidHeading
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: trayHeading.height + bottomPadding + container.headingHeight
        Behavior on height {
            NumberAnimation { duration: Kirigami.Units.shortDuration / 2; easing.type: Easing.InOutQuad }
        }
    }

    // Main content layout
    ColumnLayout {
        id: expandedRepresentation
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // Header content layout
        RowLayout {
            id: trayHeading
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                id: backButton
                visible: systemTrayState.activeApplet !== null
                icon.name: mirrored ? "go-previous-symbolic-rtl" : "go-previous-symbolic"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18nc("@action:button", "Go Back")

                KeyNavigation.down: container

                onClicked: {
                    if (typeof systemTrayState.activeApplet?.backAction !== "undefined" && systemTrayState.activeApplet.backAction.enabled) {
                        systemTrayState.activeApplet?.backAction.trigger();
                    } else {
                        systemTrayState.setActiveApplet(null);
                    }
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                leftPadding: backButton.visible ? 0 : Kirigami.Units.smallSpacing
                level: 2
                text: systemTrayState.activeApplet ? systemTrayState.activeApplet.plasmoid.title : i18n("Centro de Control")
                font.weight: Font.Bold
                maximumLineCount: 1
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            // Preferencias del Sistema
            PlasmaComponents3.ToolButton {
                id: preferencesButton
                visible: !systemTrayState.activeApplet
                icon.name: "preferences-system"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18n("Preferencias del Sistema…")
                onClicked: if (popup.backend) popup.backend.openSystemSettings()
                PlasmaComponents3.ToolTip {
                    text: preferencesButton.text
                }
            }

            // Pin / Mantener abierto
            PlasmaComponents3.ToolButton {
                id: pinButton
                checkable: true
                checked: Plasmoid.configuration.pin
                onToggled: Plasmoid.configuration.pin = checked
                icon.name: "window-pin"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18n("Fijar abierto")
                PlasmaComponents3.ToolTip {
                    text: pinButton.text
                }
            }
        }

        // Vista principal: macOS Golden Gate cards
        ColumnLayout {
            id: controlCenterContent
            Layout.fillWidth: true
            visible: !systemTrayState.activeApplet
            spacing: Kirigami.Units.mediumSpacing

            // Fila 1: Conectividad (Izquierda) + Columna de Toggles Rápidos (Derecha)
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                // Tarjeta grande de Conectividad (Wi-Fi, Bluetooth, KDE Connect)
                ConnectivityGroup {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                    Layout.fillHeight: true
                }

                // Columna de Toggles Rápidos (4 píldoras)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                    spacing: Kirigami.Units.smallSpacing

                    // Concentración (No Molestar)
                    QuickToggleTile {
                        Layout.fillWidth: true
                        iconName: popup.notificationsInhibited ? "notifications-disabled-symbolic" : "notifications-symbolic"
                        title: i18n("Concentración")
                        statusText: popup.notificationsInhibited ? i18n("No molestar") : i18n("Desactivado")
                        active: popup.notificationsInhibited
                        onToggled: popup.toggleDoNotDisturb()
                    }

                    // Luz Nocturna (Night Color)
                    QuickToggleTile {
                        Layout.fillWidth: true
                        iconName: "weather-clear-night-symbolic"
                        title: i18n("Luz nocturna")
                        statusText: (popup.backend && popup.backend.nightLightActive) ? i18n("Activa") : i18n("Inactiva")
                        active: popup.backend ? popup.backend.nightLightActive : false
                        onToggled: if (popup.backend) popup.backend.toggleNightLight()
                    }

                    // Aspecto (Claro, Oscuro, Automático)
                    QuickToggleTile {
                        Layout.fillWidth: true
                        iconName: {
                            if (!popup.backend) return "weather-clear";
                            if (popup.backend.themeMode === "auto") return "preferences-system-time";
                            if (popup.backend.themeMode === "dark") return "weather-clear-night";
                            return "weather-clear";
                        }
                        title: i18n("Aspecto")
                        statusText: {
                            if (!popup.backend) return i18n("Modo claro");
                            if (popup.backend.themeMode === "auto") return i18n("Automático");
                            if (popup.backend.themeMode === "dark") return i18n("Modo oscuro");
                            return i18n("Modo claro");
                        }
                        active: popup.backend ? (popup.backend.themeMode === "dark" || popup.backend.themeMode === "auto") : false
                        onToggled: if (popup.backend) popup.backend.cycleThemeMode()
                    }

                    // Perfil de Energía
                    QuickToggleTile {
                        Layout.fillWidth: true
                        iconName: {
                            if (!popup.backend) return "battery";
                            if (popup.backend.powerProfile === "performance") return "speedometer";
                            if (popup.backend.powerProfile === "power-saver") return "battery-low";
                            return "battery";
                        }
                        title: i18n("Energía")
                        statusText: {
                            if (!popup.backend) return i18n("Equilibrado");
                            if (popup.backend.powerProfile === "performance") return i18n("Rendimiento");
                            if (popup.backend.powerProfile === "power-saver") return i18n("Ahorro de energía");
                            return i18n("Equilibrado");
                        }
                        active: popup.backend ? (popup.backend.powerProfile === "performance") : false
                        onToggled: if (popup.backend) popup.backend.cyclePowerProfile()
                    }
                }
            }

            // Fila 2: Sliders nativos (Brillo de Pantalla)
            BrightnessSliderTile {
                Layout.fillWidth: true
                visible: popup.backend ? popup.backend.brightnessAvailable : true
            }

            // Fila 3: Sliders nativos (Sonido)
            AudioSliderTile {
                Layout.fillWidth: true
            }

            // Fila 4: Botones rápidos de bloqueo y gestión de energía
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    icon.name: "system-lock-screen"
                    text: i18n("Bloquear pantalla")
                    onClicked: if (popup.backend) popup.backend.lockScreen()
                }

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    icon.name: "preferences-system-power-management"
                    text: i18n("Ajustes de energía…")
                    onClicked: if (popup.backend) popup.backend.openEnergySettings()
                }
            }

            // Elementos ocultos adicionales de la bandeja (si existieran)
            ColumnLayout {
                Layout.fillWidth: true
                visible: (typeof hiddenModel !== "undefined" && hiddenModel && hiddenModel.count > 0)
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Otros elementos")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: (typeof hiddenModel !== "undefined") ? hiddenModel : null
                        delegate: ItemLoader {
                            width: Kirigami.Units.iconSizes.medium
                            height: width
                        }
                    }
                }
            }
        }

        // Contenedor para sub-vistas detalladas de applets (redes, bluetooth, etc. cuando se abren)
        PlasmoidPopupsContainer {
            id: container
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: systemTrayState.activeApplet !== null

            Layout.topMargin: mergeHeadings ? 0 : dialog.topPadding

            KeyNavigation.up: pinButton
            KeyNavigation.backtab: pinButton

            onVisibleChanged: {
                if (visible) {
                    forceActiveFocus();
                }
            }
        }
    }

    // Footer
    PlasmaExtras.PlasmoidHeading {
        id: plasmoidFooter
        position: PlasmaComponents3.ToolBar.Footer
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        visible: container.appletHasFooter
        height: container.footerHeight
        z: -9999
    }
}
