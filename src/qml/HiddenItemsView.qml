/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
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
import org.kde.plasma.plasmoid

PlasmaComponents3.ScrollView {
    id: hiddenTasksView

    property alias layout: hiddenTasks

    hoverEnabled: true
    background: null
    contentWidth: availableWidth
    implicitHeight: visible ? (hiddenTasks.height + hiddenTasks.margin * 2) : 0

    // Qt.UserRole + 2 is BaseRole::ItemId
    readonly property int itemIdRole: Qt.UserRole + 2

    Flickable {
        id: flickable

        contentWidth: width
        contentHeight: hiddenTasks.height + hiddenTasks.margin * 2
        boundsBehavior: Flickable.StopAtBounds
        interactive: hiddenTasks.draggedId === ""
        clip: true

        Timer {
            id: autoScrollTimer
            interval: 16
            repeat: true
            running: hiddenTasks.draggedId !== "" && hiddenTasks.autoScrollStep !== 0
            onTriggered: {
                const maxY = Math.max(0, flickable.contentHeight - flickable.height);
                const oldY = flickable.contentY;
                const newY = Math.max(0, Math.min(maxY, oldY + hiddenTasks.autoScrollStep));
                const delta = newY - oldY;
                if (Math.abs(delta) > 0.1) {
                    flickable.contentY = newY;
                    hiddenTasks.dragY += delta;
                    const curSlot = hiddenTasks.slotRect(hiddenTasks.draggedId);
                    const centerX = hiddenTasks.dragX + curSlot.width / 2;
                    const centerY = hiddenTasks.dragY + curSlot.height / 2;
                    hiddenTasks.targetDropIndex = hiddenTasks.targetIndexAt(centerX, centerY);
                }
            }
        }

        Item {
            id: hiddenTasks

            readonly property int columns: 4
            readonly property int margin: Kirigami.Units.smallSpacing
            readonly property int gap: Kirigami.Units.smallSpacing * 1.5
            readonly property real cell: Math.max(1, (width - gap * (columns - 1)) / columns)
            readonly property real rowHeight: Math.round(Kirigami.Units.gridUnit * 2.85)

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
            width: hiddenTasksView.width - margin * 2 - scrollBarReserve
            height: board.rowCount > 0 ? board.rowCount * (rowHeight + gap) - gap : 0

            activeFocusOnTab: true

            readonly property var builtinItems: [
                "wifi", "energy", "bluetooth", "airdrop",
                "stagemanager", "screenmirroring", "darkmode", "nightlight", "focus",
                "brightness", "volume",
                "lockscreen", "systemsettings", "screenshot", "energysettings"
            ]

            readonly property var allItems: {
                modelTick;
                const list = Array.from(builtinItems);
                if (popup.filteredTrayModel) {
                    const cnt = popup.filteredTrayModel.count;
                    for (let i = 0; i < cnt; ++i) {
                        const idx = popup.filteredTrayModel.index(i, 0);
                        const id = popup.filteredTrayModel.data(idx, hiddenTasksView.itemIdRole) || "";
                        if (id && !list.includes(id)) {
                            list.push(id);
                        }
                    }
                }
                return list;
            }

            readonly property var board: computeBoard(allItems, modelTick, Plasmoid.configuration.tileOrder, root.tileSizeMap)

            function computeBoard(items, tick, userOrder, sizes) {
                const order = Array.from(userOrder);
                const sorted = Array.from(items);
                const weight = id => {
                    const pos = order.indexOf(id);
                    return pos >= 0 ? pos : order.length + items.indexOf(id);
                };
                sorted.sort((a, b) => weight(a) - weight(b));

                const occupied = {};
                const isFree = (r, c, rows, cols) => {
                    for (let rr = r; rr < r + rows; ++rr) {
                        for (let cc = c; cc < c + cols; ++cc) {
                            if (occupied[`${rr},${cc}`]) return false;
                        }
                    }
                    return true;
                };

                const slots = {};
                let usedRows = 0;
                for (const id of sorted) {
                    const size = root.tileSize(id);
                    const cols = root.tileColumns(size);
                    const rows = root.tileRows(size);
                    let placed = false;
                    for (let r = 0; !placed; ++r) {
                        for (let c = 0; c + cols <= columns; ++c) {
                            if (isFree(r, c, rows, cols)) {
                                for (let rr = r; rr < r + rows; ++rr) {
                                    for (let cc = c; cc < c + cols; ++cc) {
                                        occupied[`${rr},${cc}`] = true;
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

            function slotRectFor(s): rect {
                if (!s) return Qt.rect(0, 0, cell, rowHeight);
                return Qt.rect(s.c * (cell + gap), s.r * (rowHeight + gap),
                               s.cols * cell + (s.cols - 1) * gap, s.rows * rowHeight + (s.rows - 1) * gap);
            }

            function slotRect(id: string): rect {
                return slotRectFor(board.slots[id]);
            }

            function moveTileToIndex(fromId: string, toIndex: int): void {
                const ids = Array.from(board.order);
                const fromIndex = ids.indexOf(fromId);
                if (fromIndex < 0 || toIndex < 0 || toIndex >= ids.length || fromIndex === toIndex) return;
                const [moved] = ids.splice(fromIndex, 1);
                ids.splice(toIndex, 0, moved);
                Plasmoid.configuration.tileOrder = ids;
            }

            function moveTileByOffset(id: string, delta: int): void {
                const fromIndex = board.order.indexOf(id);
                if (fromIndex < 0) return;
                const targetIndex = Math.max(0, Math.min(board.order.length - 1, fromIndex + delta));
                moveTileToIndex(id, targetIndex);
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
                    const d = Math.hypot(px - (rc.x + rc.width / 2), py - (rc.y + rc.height / 2));
                    if (d < bestDist) {
                        bestDist = d;
                        bestIdx = i;
                    }
                }
                return bestIdx;
            }

            function beginDrag(id: string, grabX: real, grabY: real): void {
                draggedId = id;
                targetDropIndex = board.order.indexOf(id);
                const rc = slotRect(id);
                dragX = rc.x;
                dragY = rc.y;
                dragGrabX = grabX;
                dragGrabY = grabY;
                autoScrollStep = 0;
            }

            function dragTo(id: string, pointerX: real, pointerY: real): void {
                if (draggedId !== id) return;
                dragX = pointerX - dragGrabX;
                dragY = pointerY - dragGrabY;

                const edgeZone = Kirigami.Units.gridUnit * 2;
                const viewTop = flickable.contentY;
                const viewBottom = flickable.contentY + flickable.height;
                if (pointerY - viewTop < edgeZone && flickable.contentY > 0) {
                    autoScrollStep = -Math.max(2, (edgeZone - (pointerY - viewTop)) * 0.25);
                } else if (viewBottom - pointerY < edgeZone && flickable.contentY < flickable.contentHeight - flickable.height) {
                    autoScrollStep = Math.max(2, (edgeZone - (viewBottom - pointerY)) * 0.25);
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
                target: popup.filteredTrayModel
                function onRowsInserted() { hiddenTasks.modelTick++; }
                function onRowsRemoved() { hiddenTasks.modelTick++; }
                function onModelReset() { hiddenTasks.modelTick++; }
                function onLayoutChanged() { hiddenTasks.modelTick++; }
            }

            // Visual placeholder showing the target slot where the dragged tile will land
            Rectangle {
                id: dropPlaceholder
                visible: hiddenTasks.draggedId !== "" && hiddenTasks.targetDropIndex >= 0
                readonly property rect targetRect: {
                    if (hiddenTasks.draggedId === "" || hiddenTasks.targetDropIndex < 0) return Qt.rect(0, 0, 0, 0);
                    const order = hiddenTasks.board.order;
                    if (order.length === 0) return Qt.rect(0, 0, 0, 0);
                    const idx = Math.max(0, Math.min(order.length - 1, hiddenTasks.targetDropIndex));
                    const targetId = order[idx];
                    const targetRc = hiddenTasks.slotRect(targetId);
                    const draggedRc = hiddenTasks.slotRect(hiddenTasks.draggedId);
                    return Qt.rect(targetRc.x, targetRc.y, draggedRc.width, draggedRc.height);
                }
                x: targetRect.x
                y: targetRect.y
                width: targetRect.width
                height: targetRect.height
                z: 10
                radius: Kirigami.Units.gridUnit * 1.0
                color: Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                border.width: 2
                border.color: Kirigami.Theme.highlightColor

                Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
            }

            // Components for Built-in Control Tiles
            Component {
                id: wifiComponent
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

            Component {
                id: energyComponent
                EnergyCard {
                    anchors.fill: parent
                }
            }

            Component {
                id: bluetoothComponent
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

            Component {
                id: airdropComponent
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

            Component {
                id: stageManagerComponent
                CircleButton {
                    anchors.fill: parent
                    iconName: "window-duplicate"
                    toolTipText: i18n("Organizador visual (Stage Manager)")
                    onClicked: if (popup.backend) popup.backend.toggleOverview()
                }
            }

            Component {
                id: screenMirroringComponent
                CircleButton {
                    anchors.fill: parent
                    iconName: "video-display"
                    toolTipText: i18n("Duplicar pantalla (Screen Mirroring)")
                    onClicked: if (popup.backend) popup.backend.openDisplaySettings()
                }
            }

            Component {
                id: darkModeComponent
                CircleButton {
                    anchors.fill: parent
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
            }

            Component {
                id: nightLightComponent
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
                id: focusComponent
                FocusPill {
                    anchors.fill: parent
                    active: popup.notificationsInhibited
                    statusText: popup.notificationsInhibited ? i18n("No molestar") : i18n("Desactivado")
                    onToggled: popup.toggleDoNotDisturb()
                }
            }

            Component {
                id: brightnessComponent
                BrightnessSliderTile {
                    anchors.fill: parent
                    visible: popup.backend ? popup.backend.brightnessAvailable : true
                }
            }

            Component {
                id: volumeComponent
                AudioSliderTile {
                    anchors.fill: parent
                }
            }

            Component {
                id: lockScreenComponent
                CircleButton {
                    anchors.fill: parent
                    iconName: "system-lock-screen"
                    toolTipText: i18n("Bloquear pantalla")
                    onClicked: if (popup.backend) popup.backend.lockScreen()
                }
            }

            Component {
                id: systemSettingsComponent
                CircleButton {
                    anchors.fill: parent
                    iconName: "preferences-system"
                    toolTipText: i18n("Preferencias del Sistema…")
                    onClicked: if (popup.backend) popup.backend.openSystemSettings()
                }
            }

            Component {
                id: screenshotComponent
                CircleButton {
                    anchors.fill: parent
                    iconName: "spectacle"
                    toolTipText: i18n("Captura de pantalla")
                    onClicked: if (popup.backend) popup.backend.takeScreenshot()
                }
            }

            Component {
                id: energySettingsComponent
                CircleButton {
                    anchors.fill: parent
                    iconName: "preferences-system-power-management"
                    toolTipText: i18n("Ajustes de energía…")
                    onClicked: if (popup.backend) popup.backend.openEnergySettings()
                }
            }

            // Built-in Tiles Repeater
            Repeater {
                id: builtinRepeater
                model: hiddenTasks.builtinItems

                delegate: Item {
                    id: builtinTile
                    required property int index
                    required property string modelData

                    readonly property string itemId: modelData
                    readonly property rect tileRect: hiddenTasks.slotRect(itemId)
                    readonly property bool dragged: hiddenTasks.draggedId === itemId

                    x: dragged ? hiddenTasks.dragX : tileRect.x
                    y: dragged ? hiddenTasks.dragY : tileRect.y
                    width: tileRect.width
                    height: tileRect.height
                    z: dragged ? 100 : 1
                    scale: dragged ? 1.05 : 1
                    opacity: dragged ? 0.92 : 1

                    Behavior on x { enabled: !builtinTile.dragged; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !builtinTile.dragged; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

                    Loader {
                        anchors.fill: parent
                        sourceComponent: {
                            switch (builtinTile.itemId) {
                            case "wifi": return wifiComponent;
                            case "energy": return energyComponent;
                            case "bluetooth": return bluetoothComponent;
                            case "airdrop": return airdropComponent;
                            case "stagemanager": return stageManagerComponent;
                            case "screenmirroring": return screenMirroringComponent;
                            case "darkmode": return darkModeComponent;
                            case "nightlight": return nightLightComponent;
                            case "focus": return focusComponent;
                            case "brightness": return brightnessComponent;
                            case "volume": return volumeComponent;
                            case "lockscreen": return lockScreenComponent;
                            case "systemsettings": return systemSettingsComponent;
                            case "screenshot": return screenshotComponent;
                            case "energysettings": return energySettingsComponent;
                            default: return null;
                            }
                        }
                    }

                    TileEditOverlay {
                        itemId: builtinTile.itemId
                        hiddenTasks: hiddenTasks
                    }
                }
            }

            // Dynamic Passive Tray Items Repeater
            Repeater {
                id: trayRepeater
                model: popup.filteredTrayModel

                delegate: Item {
                    id: trayTile
                    required property int index
                    required property var model

                    readonly property string itemId: {
                        if (!model) return "";
                        return model.Id || popup.filteredTrayModel.data(popup.filteredTrayModel.index(index, 0), hiddenTasksView.itemIdRole) || "";
                    }
                    readonly property rect tileRect: hiddenTasks.slotRect(itemId)
                    readonly property bool dragged: hiddenTasks.draggedId === itemId

                    visible: itemId.length > 0
                    x: dragged ? hiddenTasks.dragX : tileRect.x
                    y: dragged ? hiddenTasks.dragY : tileRect.y
                    width: tileRect.width
                    height: tileRect.height
                    z: dragged ? 100 : 1
                    scale: dragged ? 1.05 : 1
                    opacity: dragged ? 0.92 : 1

                    Behavior on x { enabled: !trayTile.dragged; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !trayTile.dragged; NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

                    ItemLoader {
                        anchors.centerIn: parent
                        width: (root.tileSize(trayTile.itemId) === "small")
                            ? Math.min(parent.width, parent.height)
                            : parent.width
                        height: (root.tileSize(trayTile.itemId) === "small")
                            ? width
                            : parent.height
                        index: trayTile.index
                        effectiveStatus: PlasmaCore.Types.PassiveStatus
                        model: trayTile.model
                    }

                    TileEditOverlay {
                        itemId: trayTile.itemId
                        hiddenTasks: hiddenTasks
                    }
                }
            }
        }
    }
}
