/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.volume as PlasmaAudio

PlasmaComponents3.ScrollView {
    id: controlCenterView

    property alias layout: ccTasks

    hoverEnabled: true
    background: null
    contentWidth: availableWidth
    implicitHeight: visible ? (ccTasks.height + ccTasks.margin * 2) : 0

    onVisibleChanged: {
        if (visible) {
            ccTasks.modelTick++;
        }
    }

    Flickable {
        id: flickable

        contentWidth: width
        contentHeight: ccTasks.height + ccTasks.margin * 2
        boundsBehavior: Flickable.StopAtBounds
        interactive: ccTasks.draggedId === ""
        clip: true

        Timer {
            id: autoScrollTimer
            interval: 16
            repeat: true
            running: ccTasks.draggedId !== "" && ccTasks.autoScrollStep !== 0
            onTriggered: {
                const maxY = Math.max(0, flickable.contentHeight - flickable.height);
                const oldY = flickable.contentY;
                const newY = Math.max(0, Math.min(maxY, oldY + ccTasks.autoScrollStep));
                const delta = newY - oldY;
                if (Math.abs(delta) > 0.1) {
                    flickable.contentY = newY;
                    ccTasks.dragY += delta;
                    const curSlot = ccTasks.slotRect(ccTasks.draggedId);
                    const centerX = ccTasks.dragX + curSlot.width / 2;
                    const centerY = ccTasks.dragY + curSlot.height / 2;
                    ccTasks.targetDropIndex = ccTasks.targetIndexAt(centerX, centerY);
                }
            }
        }

        Item {
            id: ccTasks

            readonly property int columns: 4
            readonly property int margin: Kirigami.Units.largeSpacing
            readonly property int gap: Kirigami.Units.largeSpacing
            readonly property real cell: Math.max(1, (width - gap * (columns - 1)) / columns)
            readonly property real rowHeight: Math.round(Math.max(cell * 0.72, Kirigami.Units.gridUnit * 3.5))

            // Dragging state (edit mode)
            property string draggedId: ""
            property int targetDropIndex: -1
            property real dragX: 0
            property real dragY: 0
            property real dragGrabX: 0
            property real dragGrabY: 0
            property real autoScrollStep: 0

            property int modelTick: 0
            readonly property real scrollBarReserve: Kirigami.Units.smallSpacing * 2

            x: margin
            width: controlCenterView.width - margin * 2 - scrollBarReserve
            height: board.rowCount > 0 ? board.rowCount * (rowHeight + gap) - gap : 0

            activeFocusOnTab: true

            readonly property var candidateItems: [
                "wifi", "bluetooth", "airdrop", "focus",
                "nightlight", "darkmode", "energy",
                "brightness", "volume"
            ]

            function isTileVisible(id: string): bool {
                const extra = Array.from(Plasmoid.configuration.extraItems || []);
                const shown = Array.from(Plasmoid.configuration.shownItems || []);
                const ccItems = Array.from(Plasmoid.configuration.controlCenterItems || []);
                const disabledSni = Array.from(Plasmoid.configuration.disabledStatusNotifiers || []);

                if (disabledSni.includes(id) || shown.includes(id)) {
                    return false;
                }

                const pluginMap = {
                    "darkmode": "org.cesar.plasmacontrolcenter.darkmode",
                    "focus": "org.cesar.plasmacontrolcenter.donotdisturb",
                    "airdrop": "org.cesar.plasmacontrolcenter.airplanemode",
                    "energy": "org.kde.plasma.battery",
                    "volume": "org.kde.plasma.volume",
                    "brightness": "org.kde.plasma.brightness",
                    "wifi": "org.kde.plasma.networkmanagement",
                    "bluetooth": "org.kde.plasma.bluetooth",
                    "nightlight": "org.kde.plasma.nightcolorcontrol"
                };

                const pluginId = pluginMap[id];
                if (pluginId) {
                    if (disabledSni.includes(pluginId) || shown.includes(pluginId)) {
                        return false;
                    }
                    const modularPlugins = [
                        "org.cesar.plasmacontrolcenter.darkmode",
                        "org.cesar.plasmacontrolcenter.donotdisturb"
                    ];
                    if (modularPlugins.includes(pluginId)) {
                        if (!extra.includes(pluginId)) return false;
                    }
                    if (ccItems.length > 0 && !ccItems.includes(pluginId) && !ccItems.includes(id)) {
                        return false;
                    }
                } else {
                    if (ccItems.length > 0 && !ccItems.includes(id)) {
                        return false;
                    }
                }

                return true;
            }

            readonly property var allItems: {
                modelTick;
                return candidateItems.filter(id => isTileVisible(id));
            }

            readonly property var board: computeBoard(allItems, modelTick, Plasmoid.configuration.controlCenterTileOrder, root.ccTileSizeMap)

            function computeBoard(items, tick, userOrder, sizes) {
                const order = Array.from(userOrder || []);
                const sorted = Array.from(items);
                const weight = id => {
                    const pos = order.indexOf(id);
                    return pos >= 0 ? pos : order.length + items.indexOf(id);
                };
                sorted.sort((a, b) => weight(a) - weight(b));

                const occupied = [];   // occupied[r][c] -> bool
                const isFree = (r, c, rows, cols) => {
                    for (let rr = r; rr < r + rows; ++rr) {
                        for (let cc = c; cc < c + cols; ++cc) {
                            if (occupied[rr] && occupied[rr][cc]) {
                                return false;
                            }
                        }
                    }
                    return true;
                };

                const slots = {};
                let usedRows = 0;

                for (const id of sorted) {
                    const size = root.ccTileSize(id);
                    const cols = root.tileColumns(size);
                    const rows = root.tileRows(size);
                    let placed = false;

                    for (let r = 0; !placed; ++r) {
                        for (let c = 0; c + cols <= columns; ++c) {
                            if (isFree(r, c, rows, cols)) {
                                for (let rr = r; rr < r + rows; ++rr) {
                                    occupied[rr] = occupied[rr] || [];
                                    for (let cc = c; cc < c + cols; ++cc) {
                                        occupied[rr][cc] = true;
                                    }
                                }
                                slots[id] = { c: c, r: r, cols: cols, rows: rows };
                                usedRows = Math.max(usedRows, r + rows);
                                placed = true;
                                break;
                            }
                        }
                    }
                }

                return {
                    slots: slots,
                    order: sorted,
                    rowCount: usedRows
                };
            }

            function slotRect(id: string): rect {
                const s = board.slots[id];
                if (!s) {
                    return Qt.rect(0, 0, cell, rowHeight);
                }
                return Qt.rect(
                    s.c * (cell + gap),
                    s.r * (rowHeight + gap),
                    s.cols * cell + (s.cols - 1) * gap,
                    s.rows * rowHeight + (s.rows - 1) * gap
                );
            }

            function moveTileToIndex(fromId: string, toIndex: int): void {
                const order = Array.from(board.order);
                const fromIdx = order.indexOf(fromId);
                if (fromIdx < 0 || toIndex < 0 || toIndex >= order.length || fromIdx === toIndex) {
                    return;
                }
                order.splice(fromIdx, 1);
                order.splice(toIndex, 0, fromId);
                Plasmoid.configuration.controlCenterTileOrder = order;
                modelTick++;
            }

            function moveTileByOffset(id: string, delta: int): void {
                const order = Array.from(board.order);
                const fromIdx = order.indexOf(id);
                if (fromIdx < 0) return;
                const toIdx = Math.max(0, Math.min(order.length - 1, fromIdx + delta));
                moveTileToIndex(id, toIdx);
            }

            function targetIndexAt(px: real, py: real): int {
                const order = board.order;
                if (order.length <= 1) return 0;

                for (let i = 0; i < order.length; ++i) {
                    const rc = slotRect(order[i]);
                    if (px >= rc.x && px <= rc.x + rc.width && py >= rc.y && py <= rc.y + rc.height) {
                        return i;
                    }
                }

                let bestIdx = 0;
                let bestDist = Infinity;
                for (let i = 0; i < order.length; ++i) {
                    const rc = slotRect(order[i]);
                    const cx = rc.x + rc.width / 2;
                    const cy = rc.y + rc.height / 2;
                    const d = Math.hypot(px - cx, py - cy);
                    if (d < bestDist) {
                        bestDist = d;
                        bestIdx = i;
                    }
                }
                return bestIdx;
            }

            function beginDrag(id: string, grabX: real, grabY: real): void {
                draggedId = id;
                dragGrabX = grabX;
                dragGrabY = grabY;
                targetDropIndex = board.order.indexOf(id);
                const rc = slotRect(id);
                dragX = rc.x;
                dragY = rc.y;
                autoScrollStep = 0;
            }

            function dragTo(id: string, px: real, py: real): void {
                if (draggedId !== id) return;
                dragX = px - dragGrabX;
                dragY = py - dragGrabY;

                const edgeZone = Kirigami.Units.gridUnit * 2;
                const viewTop = flickable.contentY;
                const viewBottom = flickable.contentY + flickable.height;
                if (py - viewTop < edgeZone && flickable.contentY > 0) {
                    autoScrollStep = -Math.max(2, (edgeZone - (py - viewTop)) * 0.25);
                } else if (viewBottom - py < edgeZone && flickable.contentY < flickable.contentHeight - flickable.height) {
                    autoScrollStep = Math.max(2, (edgeZone - (viewBottom - py)) * 0.25);
                } else {
                    autoScrollStep = 0;
                }

                const curSlot = slotRect(id);
                const centerX = dragX + curSlot.width / 2;
                const centerY = dragY + curSlot.height / 2;
                targetDropIndex = targetIndexAt(centerX, centerY);
            }

            function endDrag(): void {
                if (draggedId !== "" && targetDropIndex >= 0) {
                    const fromIndex = board.order.indexOf(draggedId);
                    if (fromIndex >= 0 && targetDropIndex !== fromIndex) {
                        moveTileToIndex(draggedId, targetDropIndex);
                    }
                }
                draggedId = "";
                targetDropIndex = -1;
                autoScrollStep = 0;
            }

            Connections {
                target: Plasmoid.configuration
                function onControlCenterTileOrderChanged() { ccTasks.modelTick++; }
                function onControlCenterTileSizesChanged() { ccTasks.modelTick++; }
                function onControlCenterItemsChanged() { ccTasks.modelTick++; }
                function onExtraItemsChanged() { ccTasks.modelTick++; }
                function onShownItemsChanged() { ccTasks.modelTick++; }
                function onHiddenItemsChanged() { ccTasks.modelTick++; }
                function onDisabledStatusNotifiersChanged() { ccTasks.modelTick++; }
            }

            // Visual placeholder showing the target slot where the dragged tile will land
            Rectangle {
                id: dropPlaceholder
                visible: ccTasks.draggedId !== "" && ccTasks.targetDropIndex >= 0
                readonly property rect targetRect: {
                    if (ccTasks.draggedId === "" || ccTasks.targetDropIndex < 0) return Qt.rect(0, 0, 0, 0);
                    const order = ccTasks.board.order;
                    if (order.length === 0) return Qt.rect(0, 0, 0, 0);
                    const idx = Math.max(0, Math.min(order.length - 1, ccTasks.targetDropIndex));
                    const targetId = order[idx];
                    const targetRc = ccTasks.slotRect(targetId);
                    const draggedRc = ccTasks.slotRect(ccTasks.draggedId);
                    return Qt.rect(targetRc.x, targetRc.y, draggedRc.width, draggedRc.height);
                }
                x: targetRect.x
                y: targetRect.y
                width: targetRect.width
                height: targetRect.height
                z: 10
                radius: Math.min(Kirigami.Units.gridUnit * 1.1, height / 2)
                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                border.width: 2
                border.color: Kirigami.Theme.highlightColor

                Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
            }

            // Component definitions for each tile
            Component {
                id: wifiComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("wifi") === "small") ? wifiSmall : wifiPill
                    Component {
                        id: wifiSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: (popup.backend && popup.backend.wifiEnabled) ? "network-wireless-connected-symbolic" : "network-wireless-disconnected-symbolic"
                            active: popup.backend ? popup.backend.wifiEnabled : false
                            toolTipText: {
                                if (!popup.backend || !popup.backend.wifiEnabled) return i18n("Wi-Fi desactivado");
                                const ssid = popup.backend.wifiSsid;
                                return (ssid && ssid.length > 0) ? `Wi-Fi: ${ssid}` : i18n("Wi-Fi activado");
                            }
                            onClicked: if (popup.backend) popup.backend.toggleWifi()
                        }
                    }
                    Component {
                        id: wifiPill
                        ConnectivityPill {
                            anchors.fill: parent
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
                    }
                }
            }

            Component {
                id: bluetoothComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("bluetooth") === "small") ? btSmall : btPill
                    Component {
                        id: btSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: (popup.backend && popup.backend.bluetoothEnabled) ? "preferences-system-bluetooth-symbolic" : "bluetooth-disabled-symbolic"
                            active: popup.backend ? popup.backend.bluetoothEnabled : false
                            toolTipText: {
                                if (!popup.backend || !popup.backend.bluetoothEnabled) return i18n("Bluetooth desactivado");
                                const dev = popup.backend.bluetoothDevice;
                                return (dev && dev.length > 0) ? `Bluetooth: ${dev}` : i18n("Bluetooth activado");
                            }
                            onClicked: if (popup.backend) popup.backend.toggleBluetooth()
                        }
                    }
                    Component {
                        id: btPill
                        ConnectivityPill {
                            anchors.fill: parent
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
                    }
                }
            }

            Component {
                id: airdropComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("airdrop") === "small") ? airdropSmall : airdropPill
                    Component {
                        id: airdropSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: "kdeconnect-symbolic"
                            toolTipText: i18n("AirDrop (KDE Connect)")
                            active: true
                            onClicked: if (popup.backend) popup.backend.openSystemSettings()
                        }
                    }
                    Component {
                        id: airdropPill
                        ConnectivityPill {
                            anchors.fill: parent
                            iconName: "kdeconnect-symbolic"
                            title: i18n("AirDrop")
                            statusText: i18n("KDE Connect")
                            active: true
                            onToggled: if (popup.backend) popup.backend.openSystemSettings()
                            onDetailsClicked: if (popup.backend) popup.backend.openSystemSettings()
                        }
                    }
                }
            }

            Component {
                id: focusComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("focus") === "small") ? focusSmall : focusPill
                    Component {
                        id: focusSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: popup.notificationsInhibited ? "notifications-disabled-symbolic" : "notifications-symbolic"
                            active: popup.notificationsInhibited
                            toolTipText: popup.notificationsInhibited ? i18n("Concentración: No molestar") : i18n("Concentración: Desactivado")
                            onClicked: popup.toggleDoNotDisturb()
                        }
                    }
                    Component {
                        id: focusPill
                        FocusPill {
                            anchors.fill: parent
                            active: popup.notificationsInhibited
                            statusText: popup.notificationsInhibited ? i18n("No molestar") : i18n("Desactivado")
                            onToggled: popup.toggleDoNotDisturb()
                        }
                    }
                }
            }

            Component {
                id: nightLightComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("nightlight") === "small") ? nlSmall : nlPill
                    Component {
                        id: nlSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: "weather-clear-night-symbolic"
                            active: popup.backend ? popup.backend.nightLightActive : false
                            toolTipText: (popup.backend && popup.backend.nightLightActive)
                                ? i18n("Luz nocturna: Activa")
                                : i18n("Luz nocturna: Inactiva")
                            onClicked: if (popup.backend) popup.backend.toggleNightLight()
                        }
                    }
                    Component {
                        id: nlPill
                        QuickToggleTile {
                            anchors.fill: parent
                            iconName: "weather-clear-night-symbolic"
                            title: i18n("Luz nocturna")
                            statusText: (popup.backend && popup.backend.nightLightActive) ? i18n("Activa") : i18n("Inactiva")
                            active: popup.backend ? popup.backend.nightLightActive : false
                            onToggled: if (popup.backend) popup.backend.toggleNightLight()
                        }
                    }
                }
            }

            Component {
                id: darkModeComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("darkmode") === "small") ? dmSmall : dmPill
                    Component {
                        id: dmSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: (popup.backend && popup.backend.darkMode) ? "weather-clear-night" : "weather-clear"
                            active: popup.backend ? (popup.backend.themeMode === "dark" || popup.backend.themeMode === "auto") : false
                            toolTipText: {
                                if (!popup.backend) return i18n("Aspecto: Modo claro");
                                if (popup.backend.themeMode === "auto") return i18n("Aspecto: Automático");
                                if (popup.backend.themeMode === "dark") return i18n("Aspecto: Modo oscuro");
                                return i18n("Aspecto: Modo claro");
                            }
                            onClicked: if (popup.backend) popup.backend.cycleThemeMode()
                        }
                    }
                    Component {
                        id: dmPill
                        QuickToggleTile {
                            anchors.fill: parent
                            iconName: (popup.backend && popup.backend.darkMode) ? "weather-clear-night" : "weather-clear"
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
                    }
                }
            }

            Component {
                id: energyComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: {
                        const s = root.ccTileSize("energy");
                        if (s === "small") return energySmall;
                        if (s === "large") return energyCard;
                        return energyPill;
                    }
                    Component {
                        id: energySmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: {
                                if (!popup.backend) return "battery";
                                if (popup.backend.powerProfile === "performance") return "speedometer";
                                if (popup.backend.powerProfile === "power-saver") return "battery-low";
                                return "battery";
                            }
                            active: popup.backend ? (popup.backend.powerProfile === "performance") : false
                            toolTipText: {
                                if (!popup.backend) return i18n("Energía: Equilibrado");
                                if (popup.backend.powerProfile === "performance") return i18n("Energía: Rendimiento");
                                if (popup.backend.powerProfile === "power-saver") return i18n("Energía: Ahorro");
                                return i18n("Energía: Equilibrado");
                            }
                            onClicked: if (popup.backend) popup.backend.cyclePowerProfile()
                        }
                    }
                    Component {
                        id: energyCard
                        EnergyCard {
                            anchors.fill: parent
                        }
                    }
                    Component {
                        id: energyPill
                        QuickToggleTile {
                            anchors.fill: parent
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
            }

            Component {
                id: brightnessComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("brightness") === "small") ? brightSmall : brightFull
                    Component {
                        id: brightSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: {
                                const maxB = Math.max(1, popup.backend ? popup.backend.brightnessMax : 100);
                                const curB = popup.backend ? popup.backend.brightness : 100;
                                const ratio = curB / maxB;
                                return (ratio < 0.33) ? "brightness-low-symbolic" : "brightness-high-symbolic";
                            }
                            active: true
                            toolTipText: {
                                const maxB = Math.max(1, popup.backend ? popup.backend.brightnessMax : 100);
                                const curB = popup.backend ? popup.backend.brightness : 100;
                                return i18n("Brillo: %1%", Math.round((curB / maxB) * 100));
                            }
                            onClicked: if (popup.backend) popup.backend.openDisplaySettings()
                        }
                    }
                    Component {
                        id: brightFull
                        BrightnessSliderTile {
                            anchors.fill: parent
                            visible: popup.backend ? popup.backend.brightnessAvailable : true
                        }
                    }
                }
            }

            Component {
                id: volumeComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("volume") === "small") ? volSmall : volFull
                    Component {
                        id: volSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: {
                                const sink = PlasmaAudio.PreferredDevice.sink;
                                const isMuted = sink ? sink.muted : false;
                                const vol = sink ? (sink.volume / 65536.0) : 0.0;
                                if (isMuted || vol === 0) return "audio-volume-muted-symbolic";
                                if (vol < 0.33) return "audio-volume-low-symbolic";
                                if (vol < 0.66) return "audio-volume-medium-symbolic";
                                return "audio-volume-high-symbolic";
                            }
                            active: true
                            toolTipText: {
                                const sink = PlasmaAudio.PreferredDevice.sink;
                                const vol = sink ? Math.round((sink.volume / 65536.0) * 100) : 0;
                                return i18n("Sonido: %1%", vol);
                            }
                            onClicked: {
                                const sink = PlasmaAudio.PreferredDevice.sink;
                                if (sink) sink.muted = !sink.muted;
                            }
                        }
                    }
                    Component {
                        id: volFull
                        AudioSliderTile {
                            anchors.fill: parent
                        }
                    }
                }
            }

            // Repeater of Control Center Tiles
            Repeater {
                id: tileRepeater
                model: ccTasks.allItems

                delegate: Item {
                    id: ccTile
                    required property int index
                    required property string modelData

                    readonly property string itemId: modelData
                    readonly property rect tileRect: ccTasks.slotRect(itemId)
                    readonly property bool dragged: ccTasks.draggedId === itemId

                    x: dragged ? ccTasks.dragX : tileRect.x
                    y: dragged ? ccTasks.dragY : tileRect.y
                    width: tileRect.width
                    height: tileRect.height
                    z: dragged ? 100 : 1
                    scale: dragged ? 1.05 : 1
                    opacity: dragged ? 0.92 : 1

                    Behavior on x { enabled: !ccTile.dragged; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !ccTile.dragged; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

                    Loader {
                        anchors.fill: parent
                        sourceComponent: {
                            switch (ccTile.itemId) {
                            case "wifi": return wifiComponent;
                            case "bluetooth": return bluetoothComponent;
                            case "airdrop": return airdropComponent;
                            case "focus": return focusComponent;
                            case "nightlight": return nightLightComponent;
                            case "darkmode": return darkModeComponent;
                            case "energy": return energyComponent;
                            case "brightness": return brightnessComponent;
                            case "volume": return volumeComponent;
                            default: return null;
                            }
                        }
                    }

                    TileEditOverlay {
                        itemId: ccTile.itemId
                        boardLayout: ccTasks
                    }
                }
            }
        }
    }
}
