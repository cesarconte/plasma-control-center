/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: abstractItem

    required property int index
    required property var model
    required property int status
    required property int effectiveStatus

    required property string itemId
    /*required*/ property alias text: label.text

    // subclasses need to bind these tooltip properties
    required mainText
    required subText
    required textFormat

    readonly property alias iconContainer: iconContainer
    readonly property bool inHiddenLayout: effectiveStatus === PlasmaCore.Types.PassiveStatus
    readonly property bool inVisibleLayout: effectiveStatus === PlasmaCore.Types.ActiveStatus

    property bool effectivePressed: false

    // Keep these in sync with the layout of the tile board in HiddenItemsView.qml
    readonly property int margins: Kirigami.Units.smallSpacing
    readonly property int maxTextLines: 2

    // --- Control Center tile geometry (only used in the popup) ---------------
    readonly property string tileSize: inHiddenLayout ? root.tileSize(itemId) : ""
    readonly property bool isSmall: tileSize === "small"
    readonly property bool isLarge: tileSize === "large"
    readonly property bool editing: inHiddenLayout && root.editMode
    readonly property bool isCurrent: inHiddenLayout && root.hiddenLayout.activeFocus && root.hiddenLayout.currentIndex === index
    readonly property int tilePadding: Kirigami.Units.gridUnit * 0.7
    readonly property real badgeSize: isLarge ? Kirigami.Units.iconSizes.large : Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
    readonly property real tileIconSize: isSmall ? Kirigami.Units.iconSizes.medium
        : Kirigami.Units.iconSizes.roundedIconSize(badgeSize * 0.58)

    // input agnostic way to trigger the main action
    signal activated(var pos)

    // proxy signals for MouseArea
    signal clicked(var mouse)
    signal pressed(var mouse)
    signal wheel(var wheel)
    signal contextMenu(var mouse)

    PulseAnimation {
        targetItem: iconContainer
        running: (abstractItem.status === PlasmaCore.Types.NeedsAttentionStatus
                || abstractItem.status === PlasmaCore.Types.RequiresAttentionStatus)
            && Kirigami.Units.longDuration > 0
    }

    // Card
    Rectangle {
        id: card
        anchors.fill: abstractItem
        visible: abstractItem.inHiddenLayout && !systemTrayState.activeApplet
        radius: Math.min(Kirigami.Units.gridUnit * 1.1, height / 2)
        color: Qt.alpha(Kirigami.Theme.textColor, mouseArea.containsMouse || abstractItem.isCurrent ? 0.17 : 0.09)
        border.width: abstractItem.isCurrent || abstractItem.editing ? 2 : 1
        border.color: abstractItem.isCurrent || abstractItem.editing
            ? Qt.alpha(Kirigami.Theme.highlightColor, abstractItem.editing ? 0.55 : 1)
            : Qt.alpha(Kirigami.Theme.textColor, 0.07)

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    // Round badge behind the icon
    Rectangle {
        id: badge
        visible: abstractItem.inHiddenLayout && !abstractItem.isSmall && !systemTrayState.activeApplet
        width: abstractItem.badgeSize
        height: width
        radius: width / 2
        x: abstractItem.tilePadding
        y: abstractItem.isLarge ? abstractItem.tilePadding : (abstractItem.height - height) / 2
        color: Qt.alpha(mouseArea.containsMouse ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor,
                        mouseArea.containsMouse ? 0.28 : 0.14)

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    MouseArea {
        id: mouseArea
        propagateComposedEvents: true
        // This needs to be above applets when it's in the grid hidden area
        // so that it can receive hover events while the mouse is over an applet,
        // but below them on regular systray, so collapsing works
        z: abstractItem.inHiddenLayout ? 1 : 0
        anchors.fill: abstractItem
        hoverEnabled: true
        drag.filterChildren: true
        enabled: !systemTrayState.activeApplet
        // Necessary to make the whole delegate area forward all mouse events
        acceptedButtons: Qt.AllButtons
        // Using onPositionChanged instead of onEntered because changing the
        // index in a scrollable view also changes the view position.
        // onEntered will change the index while the items are scrolling,
        // making it harder to scroll.
        onPositionChanged: if (abstractItem.inHiddenLayout) {
            root.hiddenLayout.currentIndex = abstractItem.index
        }
        onClicked: mouse => { abstractItem.clicked(mouse) }
        onPressed: mouse => {
            if (abstractItem.inHiddenLayout) {
                root.hiddenLayout.currentIndex = abstractItem.index
            }
            abstractItem.hideImmediately()
            abstractItem.pressed(mouse)
        }
        onPressAndHold: mouse => {
            if (mouse.button === Qt.LeftButton) {
                abstractItem.contextMenu(mouse)
            }
        }
        onWheel: wheel => {
            abstractItem.wheel(wheel);
            //Don't accept the event in order to make the scrolling by mouse wheel working
            //for the parent scrollview this icon is in.
            wheel.accepted = false;
        }
    }

    FocusScope {
        id: iconContainer

        readonly property bool pressed: abstractItem.effectivePressed || mouseArea.containsPress

        onPressedChanged: {
            if (pressed) {
                growAnimation.stop();
                shrinkAnimation.start();
            } else if (!shrinkAnimation.running) {
                growAnimation.start();
            }
        }

        // Applets with wide compact representations must not spill out of their tile
        clip: abstractItem.inHiddenLayout
        activeFocusOnTab: !abstractItem.inHiddenLayout
        focus: true // Required in HiddenItemsView so keyboard events can be forwarded to this item
        Accessible.name: abstractItem.text
        Accessible.description: abstractItem.subText
        Accessible.role: Accessible.Button
        Accessible.onPressAction: abstractItem.activated(Plasmoid.popupPosition(iconContainer, iconContainer.width/2, iconContainer.height/2));

        NumberAnimation {
            id: shrinkAnimation
            target: iconContainer
            property: "scale"
            to: 0.9
            duration: Kirigami.Units.veryShortDuration
            easing.type: Easing.OutQuart
            onFinished: {
                if (!iconContainer.pressed) {
                    growAnimation.start();
                }
            }
        }

        NumberAnimation {
            id: growAnimation
            target: iconContainer
            property: "scale"
            to: 1
            duration: Kirigami.Units.longDuration - shrinkAnimation.duration
            easing.type: Easing.OutCubic
        }

        Keys.onPressed: event => {
            switch (event.key) {
                case Qt.Key_Space:
                case Qt.Key_Enter:
                case Qt.Key_Return:
                case Qt.Key_Select:
                    abstractItem.activated(Qt.point(width/2, height/2));
                    break;
                case Qt.Key_Menu:
                    abstractItem.contextMenu(null);
                    event.accepted = true;
                    break;
            }
        }

        property alias container: abstractItem
        property alias inVisibleLayout: abstractItem.inVisibleLayout
        readonly property int size: abstractItem.inVisibleLayout ? root.itemSize : (abstractItem.inHiddenLayout ? abstractItem.tileIconSize : Kirigami.Units.iconSizes.medium)

        // In the panel the icon is centered in its cell; in the popup it sits in the tile's badge.
        width: abstractItem.inVisibleLayout
            ? (root.vertical ? abstractItem.width : size)
            : size
        height: abstractItem.inVisibleLayout
            ? (!root.vertical ? abstractItem.height : size)
            : size
        x: abstractItem.inHiddenLayout && !abstractItem.isSmall
            ? badge.x + (badge.width - width) / 2
            : (abstractItem.width - width) / 2
        y: abstractItem.inHiddenLayout && !abstractItem.isSmall
            ? badge.y + (badge.height - height) / 2
            : (abstractItem.height - height) / 2
    }

    // Title and status line of the tile
    Column {
        id: textColumn

        visible: abstractItem.inHiddenLayout && !abstractItem.isSmall && !systemTrayState.activeApplet
        spacing: 0

        readonly property real textX: abstractItem.tilePadding + abstractItem.badgeSize + Kirigami.Units.largeSpacing

        x: abstractItem.isLarge ? abstractItem.tilePadding : textX
        width: abstractItem.isLarge
            ? abstractItem.width - abstractItem.tilePadding * 2
            : abstractItem.width - textX - abstractItem.tilePadding
        y: abstractItem.isLarge
            ? abstractItem.height - abstractItem.tilePadding - height
            : (abstractItem.height - height) / 2

        PlasmaComponents3.Label {
            id: label

            width: parent.width
            maximumLineCount: abstractItem.maxTextLines
            font.weight: Font.DemiBold

            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }

        PlasmaComponents3.Label {
            id: statusLabel

            width: parent.width
            visible: text.length > 0
            // The first line of the tooltip's sub text works as the "status" of the entry (Bluetooth: On...)
            text: (abstractItem.subText ?? "").split("\n")[0].replace(/<[^>]*>/g, "").trim()
            maximumLineCount: abstractItem.isLarge ? 2 : 1
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }

        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }
    }

    // --- Edit mode: drag to rearrange, button/right click to resize --------------
    SequentialAnimation on rotation {
        id: wiggle
        running: abstractItem.editing && !systemTrayState.activeApplet && root.hiddenLayout.draggedRow !== abstractItem.index && Kirigami.Units.longDuration > 0
        loops: Animation.Infinite
        onRunningChanged: if (!running) {
            abstractItem.rotation = 0;
        }
        NumberAnimation { to: -0.9; duration: 110 + (abstractItem.index % 3) * 20; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.9; duration: 110 + (abstractItem.index % 3) * 20; easing.type: Easing.InOutSine }
    }

    MouseArea {
        id: editOverlay

        property real grabX: 0
        property real grabY: 0

        z: 5
        anchors.fill: abstractItem
        visible: abstractItem.editing && !systemTrayState.activeApplet
        enabled: visible
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                sizeMenu.popup();
                return;
            }
            grabX = mouse.x;
            grabY = mouse.y;
            root.hiddenLayout.beginDrag(abstractItem.index);
            // beginDrag() places the tile in its slot; keep it under the pointer
            const p = editOverlay.mapToItem(root.hiddenLayout, mouse.x, mouse.y);
            root.hiddenLayout.dragTo(abstractItem.index, p.x, p.y, grabX, grabY);
        }
        onPositionChanged: mouse => {
            if (pressed && root.hiddenLayout.draggedRow === abstractItem.index) {
                const p = editOverlay.mapToItem(root.hiddenLayout, mouse.x, mouse.y);
                root.hiddenLayout.dragTo(abstractItem.index, p.x, p.y, grabX, grabY);
            }
        }
        onReleased: root.hiddenLayout.endDrag()
        onCanceled: root.hiddenLayout.endDrag()
    }

    PlasmaComponents3.ToolButton {
        id: resizeButton

        z: 6
        visible: abstractItem.editing && !systemTrayState.activeApplet
        anchors {
            top: abstractItem.top
            right: abstractItem.right
            margins: Kirigami.Units.smallSpacing
        }
        implicitWidth: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
        implicitHeight: implicitWidth
        icon.name: "transform-scale"
        display: PlasmaComponents3.AbstractButton.IconOnly
        text: i18nc("@action:button Change the size of this tile", "Resize")
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
            checked: abstractItem.tileSize === sizeName
            onTriggered: root.setTileSize(abstractItem.itemId, sizeName)
        }

        SizeItem { sizeName: "small"; text: i18nc("@item:inmenu Tile size, one cell", "Small") }
        SizeItem { sizeName: "medium"; text: i18nc("@item:inmenu Tile size, two cells wide", "Medium") }
        SizeItem { sizeName: "large"; text: i18nc("@item:inmenu Tile size, two by two cells", "Large") }
        SizeItem { sizeName: "wide"; text: i18nc("@item:inmenu Tile size, full width", "Wide") }
    }
}
