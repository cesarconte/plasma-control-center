/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import CachyOS.UI
import org.kde.plasma.plasmoid

Item {
    id: root

    readonly property var backend: Plasmoid.backend

    implicitWidth: Kirigami.Units.gridUnit * 15
    implicitHeight: layout.implicitHeight + CachyTheme.spacingLarge * 2

    CardBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: CachyTheme.marginCard
        spacing: CachyTheme.spacingSmall

        // Wi-Fi
        ConnectivityRow {
            Layout.fillWidth: true
            iconName: (root.backend && root.backend.wifiEnabled) ? "network-wireless-connected-symbolic" : "network-wireless-disconnected-symbolic"
            title: i18n("Wi-Fi")
            statusText: {
                if (!root.backend || !root.backend.wifiEnabled) {
                    return i18n("Desactivado");
                }
                const ssid = root.backend.wifiSsid;
                return (ssid && ssid.length > 0) ? ssid : i18n("Activado");
            }
            active: root.backend ? root.backend.wifiEnabled : false
            onToggled: if (root.backend) root.backend.toggleWifi()
            onDetailsClicked: if (root.backend) root.backend.openNetworkSettings()
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(CachyPalette.text, 0.08)
        }

        // Bluetooth
        ConnectivityRow {
            Layout.fillWidth: true
            iconName: (root.backend && root.backend.bluetoothEnabled) ? "preferences-system-bluetooth-symbolic" : "bluetooth-disabled-symbolic"
            title: i18n("Bluetooth")
            statusText: {
                if (!root.backend || !root.backend.bluetoothEnabled) {
                    return i18n("Desactivado");
                }
                const dev = root.backend.bluetoothDevice;
                return (dev && dev.length > 0) ? dev : i18n("Activado");
            }
            active: root.backend ? root.backend.bluetoothEnabled : false
            onToggled: if (root.backend) root.backend.toggleBluetooth()
            onDetailsClicked: if (root.backend) root.backend.openBluetoothSettings()
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(CachyPalette.text, 0.08)
        }

        // KDE Connect
        ConnectivityRow {
            Layout.fillWidth: true
            iconName: "kdeconnect-symbolic"
            title: i18n("KDE Connect")
            statusText: {
                if (root.backend && root.backend.kdeConnectConnected && root.backend.kdeConnectDevice.length > 0) {
                    return root.backend.kdeConnectDevice;
                }
                return i18n("Desconectado");
            }
            active: root.backend ? root.backend.kdeConnectConnected : false
            onToggled: if (root.backend) root.backend.openKdeConnect()
            onDetailsClicked: if (root.backend) root.backend.openKdeConnect()
        }
    }
}
