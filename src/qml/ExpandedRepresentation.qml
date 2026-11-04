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
import org.kde.kitemmodels as KItemModels
import org.kde.notificationmanager as NotificationManager

Item {
    id: popup

    readonly property var backend: Plasmoid.backend

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

    // Applets de hardware que ya tienen tarjeta propia en el Centro de Control
    readonly property var redundantAppletIds: [
        "org.kde.plasma.volume",
        "org.kde.plasma.brightness",
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.bluetooth",
        "org.kde.plasma.battery",
        "org.cesar.plasmacontrolcenter.darkmode",
        "org.cesar.plasmacontrolcenter.donotdisturb",
        "org.cesar.plasmacontrolcenter.systemsettings"
    ]

    // Filtro para mostrar solo elementos reales de bandeja en la rejilla inferior
    KItemModels.KSortFilterProxyModel {
        id: filteredTrayModel
        sourceModel: (typeof root !== "undefined" && root.hiddenModel) ? root.hiddenModel : null
        filterRowCallback: (sourceRow, sourceParent) => {
            if (!sourceModel) return false;
            const itemId = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), Qt.UserRole + 2) || "";
            return !popup.redundantAppletIds.includes(itemId);
        }
    }

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

    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: systemTrayState.activeApplet
        ? Kirigami.Units.gridUnit * 24
        : (controlCenterContent.implicitHeight + trayHeading.height + Kirigami.Units.largeSpacing * 2)

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: implicitHeight

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

        // ====================================================================
        // VISTA PRINCIPAL: macOS Golden Gate (macOS 15 Sequoia / iOS 18)
        // ====================================================================
        ColumnLayout {
            id: controlCenterContent
            Layout.fillWidth: true
            visible: systemTrayState.activeApplet === null
            spacing: Kirigami.Units.mediumSpacing

            // ----------------------------------------------------------------
            // BLOQUE SUPERIOR (2 Columnas)
            // ----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                // Columna Izquierda: 3 píldoras independientes (Wi-Fi, Bluetooth, KDE Connect / AirDrop)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Kirigami.Units.smallSpacing

                    // 1. Wi-Fi
                    ConnectivityPill {
                        Layout.fillWidth: true
                        iconName: (popup.backend && popup.backend.wifiEnabled) ? "network-wireless-connected-symbolic" : "network-wireless-disconnected-symbolic"
                        title: i18n("Wi-Fi")
                        statusText: {
                            if (!popup.backend || !popup.backend.wifiEnabled) return i18n("Desactivado");
                            const ssid = popup.backend.wifiSsid;
                            return (ssid && ssid.length > 0) ? ssid : i18n("Activado");
                        }
                        active: popup.backend ? popup.backend.wifiEnabled : false
                        onToggled: if (popup.backend) popup.backend.toggleWifi()
                        onDetailsClicked: if (popup.backend) popup.backend.openNetworkSettings()
                    }

                    // 2. Bluetooth
                    ConnectivityPill {
                        Layout.fillWidth: true
                        iconName: (popup.backend && popup.backend.bluetoothEnabled) ? "preferences-system-bluetooth-symbolic" : "bluetooth-disabled-symbolic"
                        title: i18n("Bluetooth")
                        statusText: {
                            if (!popup.backend || !popup.backend.bluetoothEnabled) return i18n("Desactivado");
                            const dev = popup.backend.bluetoothDevice;
                            return (dev && dev.length > 0) ? dev : i18n("Activado");
                        }
                        active: popup.backend ? popup.backend.bluetoothEnabled : false
                        onToggled: if (popup.backend) popup.backend.toggleBluetooth()
                        onDetailsClicked: if (popup.backend) popup.backend.openBluetoothSettings()
                    }

                    // 3. AirDrop (KDE Connect)
                    ConnectivityPill {
                        Layout.fillWidth: true
                        iconName: "kdeconnect-symbolic"
                        title: i18n("AirDrop")
                        statusText: i18n("KDE Connect")
                        active: true
                        onToggled: if (popup.backend) popup.backend.openSystemSettings()
                        onDetailsClicked: if (popup.backend) popup.backend.openSystemSettings()
                    }
                }

                // Columna Derecha: Tarjeta 2x2 Energía + 2 botones circulares inferiores
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Kirigami.Units.smallSpacing

                    // Tarjeta 2x2: Perfil de Energía / Batería
                    EnergyCard {
                        Layout.fillWidth: true
                    }

                    // Fila inferior de la columna derecha: 2 botones circulares (Stage Manager y Screen Mirroring)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        // 1. Stage Manager / Organizador visual
                        CircleButton {
                            Layout.alignment: Qt.AlignCenter
                            iconName: "view-split-left"
                            toolTipText: i18n("Organizador visual (Stage Manager)")
                            onClicked: if (popup.backend) popup.backend.toggleOverview()
                        }

                        // 2. Screen Mirroring / Duplicar pantalla
                        CircleButton {
                            Layout.alignment: Qt.AlignCenter
                            iconName: "video-display"
                            toolTipText: i18n("Duplicar pantalla (Screen Mirroring)")
                            onClicked: if (popup.backend) popup.backend.openDisplaySettings()
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // FILA INTERMEDIA: 2 Botones Circulares + 1 Píldora Ancha (Focus)
            // ----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // 1. Círculo: Aspecto (Modo Claro / Oscuro / Auto)
                CircleButton {
                    iconName: {
                        if (!popup.backend) return "weather-clear";
                        if (popup.backend.themeMode === "auto") return "preferences-system-time";
                        if (popup.backend.themeMode === "dark") return "weather-clear-night";
                        return "weather-clear";
                    }
                    active: popup.backend ? (popup.backend.themeMode === "dark" || popup.backend.themeMode === "auto") : false
                    toolTipText: {
                        if (!popup.backend) return i18n("Aspecto: Modo claro");
                        if (popup.backend.themeMode === "auto") return i18n("Aspecto: Automático");
                        if (popup.backend.themeMode === "dark") return i18n("Aspecto: Modo oscuro");
                        return i18n("Aspecto: Modo claro");
                    }
                    onClicked: if (popup.backend) popup.backend.cycleThemeMode()
                }

                // 2. Círculo: Luz nocturna (Night Shift / True Tone)
                CircleButton {
                    iconName: "weather-clear-night-symbolic"
                    active: popup.backend ? popup.backend.nightLightActive : false
                    toolTipText: (popup.backend && popup.backend.nightLightActive)
                        ? i18n("Luz nocturna: Activa")
                        : i18n("Luz nocturna: Inactiva")
                    onClicked: if (popup.backend) popup.backend.toggleNightLight()
                }

                // 3. Píldora Ancha: Concentración (Focus / No molestar)
                FocusPill {
                    Layout.fillWidth: true
                    active: popup.notificationsInhibited
                    statusText: popup.notificationsInhibited ? i18n("No molestar") : i18n("Desactivado")
                    onToggled: popup.toggleDoNotDisturb()
                }
            }

            // ----------------------------------------------------------------
            // SLIDERS: Pantalla y Sonido
            // ----------------------------------------------------------------
            BrightnessSliderTile {
                Layout.fillWidth: true
                visible: popup.backend ? popup.backend.brightnessAvailable : true
            }

            AudioSliderTile {
                Layout.fillWidth: true
            }

            // ----------------------------------------------------------------
            // CUADRÍCULA INFERIOR: Botones de Acción y Bandeja del Sistema
            // Rejilla de 4 columnas (idéntica a la Imagen 1 de Sequoia)
            // ----------------------------------------------------------------
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                // 1. Bloquear pantalla
                CircleButton {
                    Layout.alignment: Qt.AlignCenter
                    iconName: "system-lock-screen"
                    toolTipText: i18n("Bloquear pantalla")
                    onClicked: if (popup.backend) popup.backend.lockScreen()
                }

                // 2. Preferencias del Sistema
                CircleButton {
                    Layout.alignment: Qt.AlignCenter
                    iconName: "preferences-system"
                    toolTipText: i18n("Preferencias del Sistema…")
                    onClicked: if (popup.backend) popup.backend.openSystemSettings()
                }

                // 3. Captura de pantalla
                CircleButton {
                    Layout.alignment: Qt.AlignCenter
                    iconName: "spectacle"
                    toolTipText: i18n("Captura de pantalla")
                    onClicked: if (popup.backend) popup.backend.takeScreenshot()
                }

                // 4. Ajustes de energía
                CircleButton {
                    Layout.alignment: Qt.AlignCenter
                    iconName: "preferences-system-power-management"
                    toolTipText: i18n("Ajustes de energía…")
                    onClicked: if (popup.backend) popup.backend.openEnergySettings()
                }

                // Elementos dinámicos reales de la bandeja (Telegram, VPN, Cachy-Update, etc.)
                Repeater {
                    model: filteredTrayModel

                    delegate: Item {
                        id: traySlot
                        required property int index
                        required property var model

                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: Math.round(Kirigami.Units.gridUnit * 2.8)
                        implicitHeight: implicitWidth

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Kirigami.Theme.alternateBackgroundColor
                            border.width: 1
                            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

                            ItemLoader {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.smallMedium
                                height: width
                                index: traySlot.index
                                effectiveStatus: PlasmaCore.Types.PassiveStatus
                                model: traySlot.model
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // SUB-VISTA: Contenedor para detalles de applets (redes, bluetooth, etc)
        // ====================================================================
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
