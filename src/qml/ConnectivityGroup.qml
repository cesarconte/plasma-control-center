/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root

    readonly property var backend: Plasmoid.backend

    implicitWidth: Kirigami.Units.gridUnit * 15
    implicitHeight: layout.implicitHeight + Kirigami.Units.largeSpacing * 2

    CardBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.mediumSpacing
        spacing: Kirigami.Units.smallSpacing

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
            color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
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
            color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
        }

        // KDE Connect (AirDrop equivalente)
        ConnectivityRow {
            Layout.fillWidth: true
            iconName: "kdeconnect-symbolic"
            title: i18n("KDE Connect")
            statusText: i18n("Compartir archivos y portapapeles")
            active: true
            onToggled: if (root.backend) root.backend.openSystemSettings()
            onDetailsClicked: if (root.backend) root.backend.openSystemSettings()
        }
    }
}
