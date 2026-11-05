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
import org.kde.plasma.networkmanagement as PlasmaNM
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

            PlasmaNM.Handler {
                id: nmHandler
            }

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

            readonly property var builtInItems: [
                "wifi", "bluetooth", "airplanemode", "airdrop", "focus",
                "nightlight", "darkmode", "energy", "kscreen",
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
                    "airplanemode": "org.cesar.plasmacontrolcenter.airplanemode",
                    "airdrop": "org.kde.kdeconnect",
                    "energy": "org.kde.plasma.battery",
                    "volume": "org.kde.plasma.volume",
                    "brightness": "org.kde.plasma.brightness",
                    "wifi": "org.kde.plasma.networkmanagement",
                    "bluetooth": "org.kde.plasma.bluetooth",
                    "nightlight": "org.kde.plasma.nightcolorcontrol",
                    "kscreen": "org.kde.kscreen"
                };

                const pluginId = pluginMap[id];
                if (pluginId) {
                    if (disabledSni.includes(pluginId) || shown.includes(pluginId)) {
                        return false;
                    }
                    const modularPlugins = [
                        "org.cesar.plasmacontrolcenter.darkmode",
                        "org.cesar.plasmacontrolcenter.donotdisturb",
                        "org.cesar.plasmacontrolcenter.airplanemode"
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

            readonly property var builtInVisible: {
                modelTick;
                return builtInItems.filter(id => isTileVisible(id));
            }

            readonly property var extraVisible: {
                modelTick;
                const list = [];
                const ccItems = Array.from(Plasmoid.configuration.controlCenterItems || []);
                const builtInPluginIds = [
                    "wifi", "bluetooth", "airdrop", "airplanemode", "focus", "nightlight", "darkmode", "energy", "brightness", "volume", "kscreen",
                    "org.cesar.plasmacontrolcenter.darkmode",
                    "org.cesar.plasmacontrolcenter.donotdisturb",
                    "org.cesar.plasmacontrolcenter.airplanemode",
                    "org.kde.plasma.battery",
                    "org.kde.plasma.networkmanagement",
                    "org.kde.plasma.bluetooth",
                    "org.kde.plasma.volume",
                    "org.kde.plasma.brightness",
                    "org.kde.plasma.nightcolorcontrol",
                    "org.kde.kscreen",
                    "org.kde.kdeconnect"
                ];
                for (const item of ccItems) {
                    if (!builtInPluginIds.includes(item) && !list.includes(item) && isTileVisible(item)) {
                        list.push(item);
                    }
                }
                return list;
            }

            property var _trayRoleMap: ({})

            function getTrayRole(roleName: string, fallback: int): int {
                if (_trayRoleMap[roleName] !== undefined) {
                    return _trayRoleMap[roleName];
                }
                const model = Plasmoid.systemTrayModel;
                if (model && typeof model.roleNames === "function") {
                    const roles = model.roleNames();
                    for (const k in roles) {
                        _trayRoleMap[roles[k]] = Number(k);
                    }
                }
                return (_trayRoleMap[roleName] !== undefined) ? _trayRoleMap[roleName] : fallback;
            }

            function extraRoleData(id: string, roleName: string, fallbackRole: int) {
                const r = findTrayModelRow(id);
                if (r < 0) return undefined;
                const model = Plasmoid.systemTrayModel;
                if (!model) return undefined;
                const roleId = getTrayRole(roleName, fallbackRole);
                const idx = model.index(r, 0);
                return model.data(idx, roleId);
            }

            function findTrayModelRow(id: string): int {
                const model = Plasmoid.systemTrayModel;
                if (!model) return -1;
                const count = model.rowCount();
                for (let i = 0; i < count; ++i) {
                    const idx = model.index(i, 0);
                    if (model.data(idx, Qt.UserRole + 2) === id) {
                        return i;
                    }
                }
                const idRole = getTrayRole("Id", 371);
                for (let i = 0; i < count; ++i) {
                    const idx = model.index(i, 0);
                    if (model.data(idx, idRole) === id) {
                        return i;
                    }
                }
                const deRole = getTrayRole("DataEngineSource", 363);
                for (let i = 0; i < count; ++i) {
                    const idx = model.index(i, 0);
                    if (model.data(idx, deRole) === id) {
                        return i;
                    }
                }
                return -1;
            }

            function extraTitle(id: string): string {
                const r = findTrayModelRow(id);
                if (r < 0) return id;
                const idx = Plasmoid.systemTrayModel.index(r, 0);
                const t = extraRoleData(id, "Title", 375)
                    || Plasmoid.systemTrayModel.data(idx, Qt.DisplayRole)
                    || extraRoleData(id, "ToolTipTitle", 377);
                return (t && typeof t === "string" && t.length > 0) ? t : id;
            }

            function extraIcon(id: string): string {
                const r = findTrayModelRow(id);
                if (r < 0) return "application-x-executable";
                const iconName = extraRoleData(id, "IconName", 369);
                if (iconName && typeof iconName === "string" && iconName.length > 0) return iconName;
                const idx = Plasmoid.systemTrayModel.index(r, 0);
                return Plasmoid.systemTrayModel.data(idx, Qt.DecorationRole) || "application-x-executable";
            }

            function extraStatus(id: string): string {
                const sub = extraRoleData(id, "ToolTipSubTitle", 376);
                if (sub && typeof sub === "string" && sub.length > 0) return sub;
                const tt = extraRoleData(id, "ToolTipTitle", 377);
                const title = extraTitle(id);
                if (tt && typeof tt === "string" && tt.length > 0 && tt !== title) return tt;
                const r = findTrayModelRow(id);
                if (r >= 0) {
                    const idx = Plasmoid.systemTrayModel.index(r, 0);
                    const st = Plasmoid.systemTrayModel.data(idx, Qt.UserRole + 5);
                    if (st === PlasmaCore.Types.ActiveStatus || st === "Active" || st === 1) {
                        return i18n("Activo");
                    }
                }
                return "";
            }

            function extraService(id: string): string {
                return extraRoleData(id, "DataEngineSource", 363) || "";
            }

            function activateExtra(id: string, visualItem: var, px: real, py: real): void {
                const s = extraService(id);
                if (!s) return;
                const itemIsMenu = Boolean(extraRoleData(id, "ItemIsMenu", 372));
                const target = visualItem || controlCenterView;
                const posX = (px !== undefined && !isNaN(px)) ? px : (target.width / 2);
                const posY = (py !== undefined && !isNaN(py)) ? py : (target.height / 2);
                const rawPos = Plasmoid.popupPosition(target, Math.round(posX), Math.round(posY));
                const pos = Qt.point(Math.round(rawPos.x), Math.round(rawPos.y));
                if (itemIsMenu) {
                    Plasmoid.openContextMenu(s, pos, target);
                } else {
                    Plasmoid.activate(s, pos, target);
                }
            }

            function openExtraMenu(id: string, visualItem: var, px: real, py: real): void {
                const s = extraService(id);
                if (!s) return;
                const target = visualItem || controlCenterView;
                const posX = (px !== undefined && !isNaN(px)) ? px : (target.width / 2);
                const posY = (py !== undefined && !isNaN(py)) ? py : (target.height / 2);
                const rawPos = Plasmoid.popupPosition(target, Math.round(posX), Math.round(posY));
                const pos = Qt.point(Math.round(rawPos.x), Math.round(rawPos.y));
                Plasmoid.openContextMenu(s, pos, target);
            }

            readonly property var allItems: builtInVisible.concat(extraVisible)

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

            Connections {
                target: Plasmoid.systemTrayModel
                function onRowsInserted() { ccTasks.modelTick++; }
                function onRowsRemoved() { ccTasks.modelTick++; }
                function onModelReset() { ccTasks.modelTick++; }
                function onDataChanged() { ccTasks.modelTick++; }
            }

            Connections {
                target: (typeof root !== "undefined") ? root.controlCenterExtraModel : null
                function onCountChanged() { ccTasks.modelTick++; }
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
                id: airplaneModeComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("airplanemode") === "small") ? apSmall : apPill
                    Component {
                        id: apSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: (nmHandler && PlasmaNM.Configuration.airplaneModeEnabled) ? "network-flightmode-on" : "network-flightmode-off"
                            active: nmHandler ? PlasmaNM.Configuration.airplaneModeEnabled : false
                            toolTipText: (nmHandler && PlasmaNM.Configuration.airplaneModeEnabled) ? i18n("Modo Avión: Activo") : i18n("Modo Avión: Inactivo")
                            onClicked: if (nmHandler) nmHandler.enableAirplaneMode(!PlasmaNM.Configuration.airplaneModeEnabled)
                        }
                    }
                    Component {
                        id: apPill
                        QuickToggleTile {
                            anchors.fill: parent
                            iconName: (nmHandler && PlasmaNM.Configuration.airplaneModeEnabled) ? "network-flightmode-on" : "network-flightmode-off"
                            title: i18n("Modo Avión")
                            statusText: (nmHandler && PlasmaNM.Configuration.airplaneModeEnabled) ? i18n("Activo") : i18n("Inactivo")
                            active: nmHandler ? PlasmaNM.Configuration.airplaneModeEnabled : false
                            onToggled: if (nmHandler) nmHandler.enableAirplaneMode(!PlasmaNM.Configuration.airplaneModeEnabled)
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
                            onClicked: if (popup.backend) popup.backend.openKdeConnect()
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
                            onToggled: if (popup.backend) popup.backend.openKdeConnect()
                            onDetailsClicked: if (popup.backend) popup.backend.openKdeConnect()
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
                id: kscreenComponent
                Loader {
                    anchors.fill: parent
                    sourceComponent: (root.ccTileSize("kscreen") === "small") ? ksSmall : ksPill
                    Component {
                        id: ksSmall
                        CircleButton {
                            anchors.fill: parent
                            iconName: "preferences-desktop-display"
                            toolTipText: i18n("Pantalla: Disposición y monitores")
                            active: true
                            onClicked: if (popup.backend) popup.backend.openDisplaySettings()
                        }
                    }
                    Component {
                        id: ksPill
                        QuickToggleTile {
                            anchors.fill: parent
                            iconName: "preferences-desktop-display"
                            title: i18n("Pantalla")
                            statusText: i18n("Monitores")
                            active: true
                            onToggled: if (popup.backend) popup.backend.openDisplaySettings()
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

            Component {
                id: extraTileComponent
                Item {
                    id: extraTileRoot
                    property string extraItemId: ""
                    anchors.fill: parent

                    Loader {
                        anchors.fill: parent
                        sourceComponent: (root.ccTileSize(extraTileRoot.extraItemId) === "small") ? extraSmall : extraPill

                        Component {
                            id: extraSmall
                            Item {
                                id: smallItem
                                anchors.fill: parent

                                CircleButton {
                                    id: circleBtn
                                    anchors.fill: parent
                                    iconName: ccTasks.extraIcon(extraTileRoot.extraItemId)
                                    toolTipText: ccTasks.extraTitle(extraTileRoot.extraItemId)
                                    active: true
                                    onClicked: ccTasks.activateExtra(extraTileRoot.extraItemId, circleBtn, circleBtn.width / 2, circleBtn.height / 2)
                                    onRightClicked: mouse => ccTasks.openExtraMenu(extraTileRoot.extraItemId, circleBtn, mouse.x, mouse.y)
                                }
                            }
                        }

                        Component {
                            id: extraPill
                            Item {
                                id: pillItem
                                anchors.fill: parent

                                implicitWidth: Kirigami.Units.gridUnit * 12
                                implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.8)

                                CardBackground {
                                    id: cardBg
                                    anchors.fill: parent
                                    interactive: true
                                    hovered: mainMouse.containsMouse || chevronBtn.hovered
                                    pressed: mainMouse.pressed || chevronBtn.pressed
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing

                                    // Circular Icon
                                    Rectangle {
                                        Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.1)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: Layout.preferredWidth / 2
                                        color: Kirigami.Theme.highlightColor

                                        Behavior on color {
                                            ColorAnimation { duration: Kirigami.Units.shortDuration }
                                        }

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                            implicitHeight: implicitWidth
                                            source: ccTasks.extraIcon(extraTileRoot.extraItemId)
                                            color: Kirigami.Theme.highlightedTextColor
                                        }
                                    }

                                    // Title & Status
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 1

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            text: ccTasks.extraTitle(extraTileRoot.extraItemId)
                                            font.weight: Font.DemiBold
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                                            elide: Text.ElideRight
                                        }

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            text: ccTasks.extraStatus(extraTileRoot.extraItemId)
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                            opacity: 0.75
                                            elide: Text.ElideRight
                                            visible: text.length > 0
                                        }
                                    }

                                    // Chevron ToolButton for context menu
                                    PlasmaComponents3.ToolButton {
                                        id: chevronBtn
                                        icon.name: "go-next-symbolic"
                                        display: PlasmaComponents3.AbstractButton.IconOnly
                                        implicitWidth: Kirigami.Units.iconSizes.small
                                        implicitHeight: implicitWidth
                                        onClicked: ccTasks.openExtraMenu(extraTileRoot.extraItemId, chevronBtn, chevronBtn.width / 2, chevronBtn.height / 2)
                                    }
                                }

                                MouseArea {
                                    id: mainMouse
                                    anchors.fill: parent
                                    anchors.rightMargin: chevronBtn.width + Kirigami.Units.smallSpacing
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            ccTasks.openExtraMenu(extraTileRoot.extraItemId, pillItem, mouse.x, mouse.y);
                                        } else {
                                            ccTasks.activateExtra(extraTileRoot.extraItemId, pillItem, mouse.x, mouse.y);
                                        }
                                    }
                                }
                            }
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
                        id: tileLoader
                        anchors.fill: parent
                        sourceComponent: {
                            switch (ccTile.itemId) {
                            case "wifi": return wifiComponent;
                            case "bluetooth": return bluetoothComponent;
                            case "airplanemode": return airplaneModeComponent;
                            case "airdrop": return airdropComponent;
                            case "focus": return focusComponent;
                            case "nightlight": return nightLightComponent;
                            case "darkmode": return darkModeComponent;
                            case "energy": return energyComponent;
                            case "kscreen": return kscreenComponent;
                            case "brightness": return brightnessComponent;
                            case "volume": return volumeComponent;
                            default: return extraTileComponent;
                            }
                        }
                        onLoaded: {
                            if (item && item.hasOwnProperty("extraItemId")) {
                                item.extraItemId = ccTile.itemId;
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
