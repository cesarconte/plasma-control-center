/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

/*
 * The board of tiles shown in the popup.
 *
 * The model is the (unsorted) list of passive items; the visual order and the
 * span of every tile is computed here from the "tileOrder" and "tileSizes"
 * settings, so the underlying models and the applets they host are never
 * reordered or recreated when the user rearranges the tiles.
 */
PlasmaComponents3.ScrollView {
    id: hiddenTasksView

    property alias layout: hiddenTasks

    hoverEnabled: true
    background: null
    contentWidth: availableWidth
    implicitHeight: visible ? (hiddenTasks.height + hiddenTasks.margin) : 0

    // Qt.UserRole + 2 is BaseRole::ItemId (see the configuration page)
    readonly property int itemIdRole: Qt.UserRole + 2

    Flickable {
        id: flickable

        contentWidth: width
        contentHeight: hiddenTasks.height + hiddenTasks.margin
        boundsBehavior: Flickable.StopAtBounds
        interactive: hiddenTasks.draggedRow < 0
        clip: true

        Timer {
            id: autoScrollTimer
            interval: 16
            repeat: true
            running: hiddenTasks.draggedRow >= 0 && hiddenTasks.autoScrollStep !== 0
            onTriggered: {
                const maxY = Math.max(0, flickable.contentHeight - flickable.height);
                const oldY = flickable.contentY;
                const newY = Math.max(0, Math.min(maxY, oldY + hiddenTasks.autoScrollStep));
                const delta = newY - oldY;
                if (Math.abs(delta) > 0.1) {
                    flickable.contentY = newY;
                    hiddenTasks.dragY += delta;
                    hiddenTasks.dragPointerY += delta;
                    const curSlot = hiddenTasks.slotRect(hiddenTasks.draggedRow);
                    const centerX = hiddenTasks.dragX + curSlot.width / 2;
                    const centerY = hiddenTasks.dragY + curSlot.height / 2;
                    hiddenTasks.targetDropIndex = hiddenTasks.targetIndexAt(centerX, centerY);
                }
            }
        }

        Item {
            id: hiddenTasks

            // Number of grid columns of the board. Tile spans are expressed in these.
            readonly property int columns: 4
            readonly property int margin: Kirigami.Units.largeSpacing
            readonly property int gap: Kirigami.Units.largeSpacing
            readonly property real cell: Math.max(1, (width - gap * (columns - 1)) / columns)
            // Tiles are wider than tall, like in macOS: a row is a bit lower than a column is wide
            readonly property real rowHeight: Math.round(Math.max(cell * 0.72, Kirigami.Units.gridUnit * 3.5))

            // Compatibility with the rest of the applet (it was a GridView before)
            readonly property int count: repeater.count
            readonly property int itemCount: count
            property int currentIndex: -1

            // Dragging state (edit mode)
            property int draggedRow: -1
            property int targetDropIndex: -1
            property real dragX: 0
            property real dragY: 0
            property real dragPointerX: 0
            property real dragPointerY: 0
            property real autoScrollStep: 0

            // Bumped whenever the set of rows in the model changes
            property int modelTick: 0

            // Space always reserved for the scroll bar, so showing it never changes the layout (binding loop)
            readonly property real scrollBarReserve: Kirigami.Units.smallSpacing * 2

            x: margin
            width: hiddenTasksView.width - margin * 2 - scrollBarReserve
            height: board.rowCount > 0 ? board.rowCount * (rowHeight + gap) - gap : 0

            activeFocusOnTab: true

            readonly property var board: computeBoard(count, modelTick, Plasmoid.configuration.tileOrder, root.tileSizeMap)

            function rowId(row: int): string {
                return root.hiddenModel.data(root.hiddenModel.index(row, 0), hiddenTasksView.itemIdRole) ?? "";
            }

            function sortedEntries(n, userOrder) {
                const entries = [];
                for (let row = 0; row < n; ++row) {
                    entries.push({row: row, id: rowId(row)});
                }
                const order = Array.from(userOrder);
                const weight = e => {
                    const pos = order.indexOf(e.id);
                    return pos >= 0 ? pos : order.length + e.row;
                };
                entries.sort((a, b) => weight(a) - weight(b));
                return entries;
            }

            /*
             * Packs `entries` in monotonic reading order (top-to-bottom, left-to-right),
             * while still allowing tiles to fill rows alongside 2x2 ("large") tiles.
             */
            function layoutEntries(entries) {
                const n = entries.length;
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

                const slots = new Array(n);
                let usedRows = 0;
                let lastR = 0;
                let lastC = 0;
                for (const e of entries) {
                    const size = root.tileSize(e.id);
                    const cols = root.tileColumns(size);
                    const rows = root.tileRows(size);
                    let placed = false;
                    for (let r = lastR; !placed; ++r) {
                        const startCol = (r === lastR) ? lastC : 0;
                        for (let c = startCol; c + cols <= columns; ++c) {
                            if (isFree(r, c, rows, cols)) {
                                for (let rr = r; rr < r + rows; ++rr) {
                                    occupied[rr] = occupied[rr] || [];
                                    for (let cc = c; cc < c + cols; ++cc) {
                                        occupied[rr][cc] = true;
                                    }
                                }
                                slots[e.row] = {c: c, r: r, cols: cols, rows: rows};
                                usedRows = Math.max(usedRows, r + rows);
                                lastR = r;
                                lastC = c + cols;
                                placed = true;
                                break;
                            }
                        }
                    }
                }
                return {
                    slots: slots,
                    order: entries.map(e => e.row),
                    ids: entries.map(e => e.id),
                    rowCount: usedRows,
                    lastLinearPos: lastR * columns + lastC,
                };
            }

            /*
             * Returns { slots: [ {c, r, cols, rows} per model row ], order: [rows in display order], ids: [ids in display order], rowCount }
             */
            function computeBoard(n, tick, userOrder, sizes) {
                const entries = sortedEntries(n, userOrder);
                return layoutEntries(entries);
            }

            function slotRectFor(s): rect {
                if (!s) {
                    return Qt.rect(0, 0, cell, rowHeight);
                }
                return Qt.rect(s.c * (cell + gap), s.r * (rowHeight + gap),
                               s.cols * cell + (s.cols - 1) * gap, s.rows * rowHeight + (s.rows - 1) * gap);
            }

            function slotRect(row: int): rect {
                return slotRectFor(board.slots[row]);
            }

            /*! Moves the tile of row `from` to index `toIndex` in the display order */
            function moveTileToIndex(from: int, toIndex: int): void {
                const ids = Array.from(board.ids);
                const fromIndex = board.order.indexOf(from);
                if (fromIndex < 0 || toIndex < 0 || toIndex >= ids.length || fromIndex === toIndex) {
                    return;
                }
                const [moved] = ids.splice(fromIndex, 1);
                ids.splice(toIndex, 0, moved);
                Plasmoid.configuration.tileOrder = ids;
            }

            function moveTileByOffset(row: int, delta: int): void {
                const fromIndex = board.order.indexOf(row);
                if (fromIndex < 0) {
                    return;
                }
                const targetIndex = Math.max(0, Math.min(board.order.length - 1, fromIndex + delta));
                moveTileToIndex(row, targetIndex);
            }

            function targetIndexAt(px: real, py: real): int {
                const order = board.order;
                if (order.length <= 1) {
                    return 0;
                }

                // Direct hit test first: check which existing slot contains the point
                for (let i = 0; i < order.length; ++i) {
                    const rc = slotRect(order[i]);
                    if (px >= rc.x && px <= rc.x + rc.width && py >= rc.y && py <= rc.y + rc.height) {
                        return i;
                    }
                }

                // Otherwise, find the slot whose center is closest to (px, py)
                let bestIdx = 0;
                let bestDist = Infinity;
                for (let i = 0; i < order.length; ++i) {
                    const rc = slotRect(order[i]);
                    const scx = rc.x + rc.width / 2;
                    const scy = rc.y + rc.height / 2;
                    const d = Math.hypot(px - scx, py - scy);
                    if (d < bestDist) {
                        bestDist = d;
                        bestIdx = i;
                    }
                }
                return bestIdx;
            }

            function beginDrag(row: int): void {
                draggedRow = row;
                targetDropIndex = board.order.indexOf(row);
                const rc = slotRect(row);
                dragX = rc.x;
                dragY = rc.y;
                autoScrollStep = 0;
            }

            function dragTo(row: int, pointerX: real, pointerY: real, grabX: real, grabY: real): void {
                if (draggedRow !== row) {
                    return;
                }
                dragPointerX = pointerX;
                dragPointerY = pointerY;
                dragX = pointerX - grabX;
                dragY = pointerY - grabY;

                // Auto-scroll when dragging near the top or bottom edge of the visible viewport
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

                const curSlot = slotRect(row);
                const centerX = dragX + curSlot.width / 2;
                const centerY = dragY + curSlot.height / 2;
                targetDropIndex = targetIndexAt(centerX, centerY);
            }

            function endDrag(): void {
                if (draggedRow >= 0 && targetDropIndex >= 0) {
                    const fromIndex = board.order.indexOf(draggedRow);
                    if (fromIndex >= 0 && targetDropIndex !== fromIndex) {
                        moveTileToIndex(draggedRow, targetDropIndex);
                    }
                }
                draggedRow = -1;
                targetDropIndex = -1;
                autoScrollStep = 0;
            }

            // Keyboard navigation, following the visual order of the tiles
            function moveCurrent(delta: int): void {
                const order = board.order;
                if (order.length === 0) {
                    return;
                }
                let pos = order.indexOf(currentIndex);
                pos = pos < 0 ? 0 : Math.max(0, Math.min(order.length - 1, pos + delta));
                currentIndex = order[pos];
            }

            Keys.onPressed: event => {
                const tile = repeater.itemAt(currentIndex)?.item ?? null;
                const reorderMod = (event.modifiers & (Qt.ShiftModifier | Qt.AltModifier)) !== 0;
                switch (event.key) {
                case Qt.Key_Left:
                case Qt.Key_Up:
                    if (root.editMode && reorderMod && currentIndex >= 0) {
                        moveTileByOffset(currentIndex, -1);
                    } else {
                        moveCurrent(-1);
                    }
                    break;
                case Qt.Key_Right:
                case Qt.Key_Down:
                    if (root.editMode && reorderMod && currentIndex >= 0) {
                        moveTileByOffset(currentIndex, 1);
                    } else {
                        moveCurrent(1);
                    }
                    break;
                case Qt.Key_Space:
                case Qt.Key_Enter:
                case Qt.Key_Return:
                    if (tile) {
                        tile.activated(Qt.point(tile.width / 2, tile.height / 2));
                    }
                    break;
                case Qt.Key_Menu:
                    if (tile) {
                        tile.contextMenu(null);
                    }
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            onActiveFocusChanged: {
                if (activeFocus && currentIndex === -1) {
                    currentIndex = board.order.length > 0 ? board.order[0] : -1;
                } else if (!activeFocus && currentIndex >= 0) {
                    currentIndex = -1;
                }
            }

            Connections {
                target: root.hiddenModel
                function onRowsInserted() { hiddenTasks.modelTick++; }
                function onRowsRemoved() { hiddenTasks.modelTick++; }
                function onModelReset() { hiddenTasks.modelTick++; }
                function onLayoutChanged() { hiddenTasks.modelTick++; }
                function onRowsMoved() { hiddenTasks.modelTick++; }
            }

            // Visual placeholder showing the target slot where the dragged tile will land
            Rectangle {
                id: dropPlaceholder
                visible: hiddenTasks.draggedRow >= 0 && hiddenTasks.targetDropIndex >= 0
                readonly property rect targetRect: {
                    if (hiddenTasks.draggedRow < 0 || hiddenTasks.targetDropIndex < 0) {
                        return Qt.rect(0, 0, 0, 0);
                    }
                    const order = hiddenTasks.board.order;
                    if (order.length === 0) {
                        return Qt.rect(0, 0, 0, 0);
                    }
                    const idx = Math.max(0, Math.min(order.length - 1, hiddenTasks.targetDropIndex));
                    const targetRow = order[idx];
                    const targetRc = hiddenTasks.slotRect(targetRow);
                    const draggedRc = hiddenTasks.slotRect(hiddenTasks.draggedRow);
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

                Behavior on x {
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
            }

            Repeater {
                id: repeater

                model: root.hiddenModel
                delegate: ItemLoader {
                    id: tile

                    readonly property bool dragged: hiddenTasks.draggedRow === index
                    readonly property rect tileRect: hiddenTasks.slotRect(index)

                    x: dragged ? hiddenTasks.dragX : tileRect.x
                    y: dragged ? hiddenTasks.dragY : tileRect.y
                    width: tileRect.width
                    height: tileRect.height
                    z: dragged ? 100 : 1
                    scale: dragged ? 1.05 : 1
                    opacity: dragged ? 0.92 : 1

                    Accessible.role: Accessible.ListItem // needed to get the board description or role announced

                    Behavior on x {
                        enabled: !tile.dragged
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: !tile.dragged
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on width {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
