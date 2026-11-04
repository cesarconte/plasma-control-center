/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: editOverlay

    required property string itemId
    required property var boardLayout

    anchors.fill: parent
    visible: (typeof root !== "undefined" && root.editMode)
    z: 50

    readonly property bool isSmall: (typeof root !== "undefined") ? (root.ccTileSize(itemId) === "small") : false

    Rectangle {
        id: editBorder
        anchors.centerIn: editOverlay.isSmall ? parent : undefined
        anchors.fill: editOverlay.isSmall ? undefined : parent
        width: editOverlay.isSmall ? Math.min(parent.width, parent.height) : parent.width
        height: editOverlay.isSmall ? width : parent.height
        radius: editOverlay.isSmall ? width / 2 : Kirigami.Units.gridUnit * 1.0

        color: editMouse.containsMouse ? Qt.alpha(Kirigami.Theme.highlightColor, 0.16) : "transparent"
        border.width: 1.5
        border.color: editMouse.containsMouse
            ? Kirigami.Theme.highlightColor
            : Qt.alpha(Kirigami.Theme.highlightColor, 0.45)

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    MouseArea {
        id: editMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property real grabX: 0
        property real grabY: 0

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                sizeMenu.popup(editOverlay, mouse.x, mouse.y);
                return;
            }
            const p = editMouse.mapToItem(boardLayout, mouse.x, mouse.y);
            const rc = boardLayout.slotRect(editOverlay.itemId);
            grabX = p.x - rc.x;
            grabY = p.y - rc.y;
            boardLayout.beginDrag(editOverlay.itemId, grabX, grabY);
        }

        onPositionChanged: mouse => {
            if (pressed && boardLayout.draggedId === editOverlay.itemId) {
                const p = editMouse.mapToItem(boardLayout, mouse.x, mouse.y);
                boardLayout.dragTo(editOverlay.itemId, p.x, p.y);
            }
        }

        onReleased: boardLayout.endDrag()
        onCanceled: boardLayout.endDrag()
    }

    PlasmaComponents3.ToolButton {
        id: resizeButton
        z: 60
        anchors {
            top: parent.top
            right: parent.right
            margins: 2
        }
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        icon.name: "transform-scale"
        display: PlasmaComponents3.AbstractButton.IconOnly
        text: i18n("Cambiar tamaño")
        onClicked: sizeMenu.popup(resizeButton, 0, resizeButton.height)

        PlasmaComponents3.ToolTip {
            text: resizeButton.text
        }
    }

    QQC2.Menu {
        id: sizeMenu

        component SizeItem: QQC2.MenuItem {
            required property string sizeName
            checkable: true
            autoExclusive: true
            checked: root.ccTileSize(editOverlay.itemId) === sizeName
            onTriggered: {
                root.setCcTileSize(editOverlay.itemId, sizeName);
                boardLayout.modelTick++;
            }
        }

        SizeItem { sizeName: "small"; text: i18n("Pequeño (1 celda)") }
        SizeItem { sizeName: "medium"; text: i18n("Mediano (2 celdas)") }
        SizeItem { sizeName: "large"; text: i18n("Grande (2x2 celdas)") }
        SizeItem { sizeName: "wide"; text: i18n("Ancho (4 celdas)") }

        QQC2.MenuSeparator {}

        QQC2.MenuItem {
            icon.name: "go-previous"
            text: i18n("Mover antes")
            enabled: (boardLayout.board.order.indexOf(editOverlay.itemId)) > 0
            onTriggered: boardLayout.moveTileByOffset(editOverlay.itemId, -1)
        }

        QQC2.MenuItem {
            icon.name: "go-next"
            text: i18n("Mover después")
            enabled: {
                const order = boardLayout.board.order;
                const pos = order.indexOf(editOverlay.itemId);
                return pos >= 0 && pos < order.length - 1;
            }
            onTriggered: boardLayout.moveTileByOffset(editOverlay.itemId, 1)
        }

        QQC2.MenuItem {
            icon.name: "go-top"
            text: i18n("Mover al principio")
            enabled: (boardLayout.board.order.indexOf(editOverlay.itemId)) > 0
            onTriggered: boardLayout.moveTileToIndex(editOverlay.itemId, 0)
        }
    }
}
