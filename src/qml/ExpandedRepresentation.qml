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

    // 0: Centro de Control (macOS Golden Gate), 1: Bandeja del Sistema (Plasma Tray)
    property int currentTab: 0

    property alias hiddenLayout: hiddenItemsView.layout
    property alias plasmoidContainer: container

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
    implicitHeight: {
        if (systemTrayState.activeApplet) {
            return Kirigami.Units.gridUnit * 24;
        }
        if (popup.currentTab === 0) {
            const h = controlCenterView.implicitHeight + trayHeading.height + Kirigami.Units.largeSpacing * 2;
            return Math.min(Kirigami.Units.gridUnit * 30, Math.max(Kirigami.Units.gridUnit * 22, h));
        }
        return Kirigami.Units.gridUnit * 24;
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 23
    Layout.minimumHeight: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
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

            // Título cuando hay un sub-applet activo
            Kirigami.Heading {
                visible: systemTrayState.activeApplet !== null
                Layout.fillWidth: true
                leftPadding: Kirigami.Units.smallSpacing
                level: 2
                text: systemTrayState.activeApplet ? systemTrayState.activeApplet.plasmoid.title : ""
                font.weight: Font.Bold
                maximumLineCount: 1
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            // Selector Segmentado estilo macOS Sequoia (Centro de Control | Bandeja)
            Rectangle {
                id: tabSwitcher
                visible: !systemTrayState.activeApplet
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Kirigami.Units.gridUnit * 1.8
                implicitWidth: segmentsRow.implicitWidth + 8
                radius: implicitHeight / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

                RowLayout {
                    id: segmentsRow
                    anchors.centerIn: parent
                    spacing: 2

                    // Pestaña 0: Centro de Control
                    Rectangle {
                        id: controlCenterTab
                        implicitHeight: Kirigami.Units.gridUnit * 1.5
                        implicitWidth: ccRow.implicitWidth + Kirigami.Units.mediumSpacing * 2
                        radius: implicitHeight / 2
                        color: popup.currentTab === 0 ? Kirigami.Theme.backgroundColor : "transparent"
                        border.width: popup.currentTab === 0 ? 1 : 0
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.currentTab = 0
                        }

                        RowLayout {
                            id: ccRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                source: "controlcenter-symbolic"
                                fallback: Qt.resolvedUrl("controlcenter-symbolic.svg")
                            }

                            PlasmaComponents3.Label {
                                text: i18n("Centro de Control")
                                font.weight: popup.currentTab === 0 ? Font.DemiBold : Font.Normal
                                opacity: popup.currentTab === 0 ? 1.0 : 0.7
                            }
                        }
                    }

                    // Pestaña 1: Bandeja del Sistema
                    Rectangle {
                        id: trayTab
                        implicitHeight: Kirigami.Units.gridUnit * 1.5
                        implicitWidth: trayRow.implicitWidth + Kirigami.Units.mediumSpacing * 2
                        radius: implicitHeight / 2
                        color: popup.currentTab === 1 ? Kirigami.Theme.backgroundColor : "transparent"
                        border.width: popup.currentTab === 1 ? 1 : 0
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.currentTab = 1
                        }

                        RowLayout {
                            id: trayRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                source: "view-grid-symbolic"
                            }

                            PlasmaComponents3.Label {
                                text: i18n("Bandeja")
                                font.weight: popup.currentTab === 1 ? Font.DemiBold : Font.Normal
                                opacity: popup.currentTab === 1 ? 1.0 : 0.7
                            }

                            // Contador de elementos en la bandeja
                            Rectangle {
                                visible: root.hiddenModel && root.hiddenModel.count > 0
                                implicitWidth: Math.max(height, badgeText.implicitWidth + 8)
                                implicitHeight: Kirigami.Units.iconSizes.small
                                radius: height / 2
                                color: popup.currentTab === 1 ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.15)

                                PlasmaComponents3.Label {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: root.hiddenModel ? root.hiddenModel.count : "0"
                                    font.pixelSize: Math.max(9, Math.round(Kirigami.Units.gridUnit * 0.6))
                                    font.bold: true
                                    color: popup.currentTab === 1 ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                }
                            }
                        }
                    }
                }
            }

            // Espaciador flexible para empujar acciones a la derecha
            Item {
                Layout.fillWidth: true
            }

            // Acciones contextuales del applet activo
            Repeater {
                id: primaryActionButtons
                model: {
                    if (!actionsButton.applet) return [];
                    return actionsButton.applet.Plasmoid.contextualActions.filter(action => {
                        return !action.isSeparator && action.priority === PlasmaCore.Action.HighPriority;
                    });
                }
                delegate: PlasmaComponents3.ToolButton {
                    id: actionButton
                    required property int index
                    required property PlasmaCore.Action modelData
                    property PlasmaCore.Action qAction: modelData
                    visible: qAction && qAction.visible

                    contentItem: Kirigami.Icon {
                        anchors.centerIn: parent
                        active: actionButton.hovered
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        source: actionButton.qAction ? actionButton.qAction.icon.name : ""
                    }

                    enabled: qAction && qAction.enabled
                    checkable: qAction && qAction.checkable
                    checked: qAction && qAction.checked
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: qAction ? qAction.text : ""

                    PlasmaComponents3.ToolTip {
                        text: actionButton.text
                    }
                    onClicked: if (qAction) qAction.trigger()
                }
            }

            PlasmaComponents3.ToolButton {
                id: actionsButton
                visible: visibleActions > 0
                enabled: showAsMenu || (singleAction && singleAction.enabled)
                checked: showAsMenu ? configMenu.status !== PlasmaExtras.Menu.Closed : singleAction && singleAction.checked

                property QtObject applet: systemTrayState.activeApplet || root
                property int visibleActions: actions.length
                property PlasmaCore.Action singleAction: visibleActions === 1 && menuItemFactory.object ? menuItemFactory.object.action : null
                property bool showAsMenu: visibleActions > 1 || (singleAction !== null && singleAction.alwaysShowAsMenu === true)

                readonly property var actions: {
                    if (!applet) return [];
                    return applet.plasmoid.contextualActions
                        .filter(action => {
                            return action.visible &&
                            action.priority === PlasmaCore.Action.NormalPriority &&
                            action !== applet.plasmoid.internalAction("configure");
                        })
                        .reduce((dstActions, action, i, srcActions) => {
                            if (!action.isSeparator) {
                                const prevAction = srcActions[i - 1];
                                if (prevAction?.isSeparator && dstActions.length > 0) {
                                    dstActions.push(prevAction);
                                }
                                dstActions.push(action);
                            }
                            return dstActions;
                        }, []);
                }

                icon.name: "application-menu"
                checkable: showAsMenu || (singleAction && singleAction.checkable)
                contentItem.opacity: showAsMenu
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: (actionsButton.singleAction && !showAsMenu) ? actionsButton.singleAction.text : i18n("More actions")

                Kirigami.Icon {
                    parent: actionsButton
                    anchors.centerIn: parent
                    active: actionsButton.hovered
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                    source: (actionsButton.singleAction && !actionsButton.showAsMenu) ? actionsButton.singleAction.icon.name : ""
                    visible: actionsButton.singleAction && !actionsButton.showAsMenu
                }

                onToggled: {
                    if (showAsMenu) {
                        if (checked) configMenu.openRelative();
                        else configMenu.close();
                    }
                }
                onClicked: if (singleAction && !showAsMenu) singleAction.trigger()

                PlasmaComponents3.ToolTip {
                    text: actionsButton.text
                }
                PlasmaExtras.Menu {
                    id: configMenu
                    visualParent: actionsButton
                    placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
                }

                Instantiator {
                    id: menuItemFactory
                    model: actionsButton.actions
                    delegate: PlasmaExtras.MenuItem {
                        required property PlasmaCore.Action modelData
                        action: modelData
                    }
                    onObjectAdded: (index, object) => configMenu.addMenuItem(object)
                    onObjectRemoved: (index, object) => configMenu.removeMenuItem(object)
                }
            }

            PlasmaComponents3.ToolButton {
                id: configureButton
                icon.name: "configure"
                visible: actionsButton.applet && actionsButton.applet.plasmoid.internalAction("configure")
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: actionsButton.applet?.plasmoid.internalAction("configure")?.text ?? ""
                PlasmaComponents3.ToolTip {
                    text: parent.visible ? parent.text : ""
                }
                onClicked: actionsButton.applet.plasmoid.internalAction("configure").trigger()
            }

            // Botones de edición (visibles en pestaña Centro de Control y Bandeja)
            PlasmaComponents3.ToolButton {
                id: resetLayoutButton
                visible: root.editMode && !systemTrayState.activeApplet
                icon.name: "edit-reset"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18nc("@action:button Restore the default order and size of the tiles", "Reset Layout")
                onClicked: {
                    if (popup.currentTab === 0) {
                        Plasmoid.configuration.controlCenterTileOrder = [];
                        Plasmoid.configuration.controlCenterTileSizes = [];
                    } else {
                        Plasmoid.configuration.tileOrder = [];
                        Plasmoid.configuration.tileSizes = [];
                    }
                }
                PlasmaComponents3.ToolTip {
                    text: resetLayoutButton.text
                }
            }

            PlasmaComponents3.ToolButton {
                id: editButton
                visible: !systemTrayState.activeApplet
                checkable: true
                checked: root.editMode
                onToggled: root.editMode = checked
                icon.name: checked ? "dialog-ok-apply" : "document-edit"
                highlighted: checked
                display: checked ? PlasmaComponents3.AbstractButton.TextBesideIcon : PlasmaComponents3.AbstractButton.IconOnly
                text: checked ? i18nc("@action:button Leave the mode in which tiles can be moved and resized", "Done")
                              : i18nc("@action:button Enter the mode in which tiles can be moved and resized", "Edit Controls")
                PlasmaComponents3.ToolTip {
                    text: i18nc("@info:tooltip", "Move and resize the controls")
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

        // ====================================================================
        // VISTA 1: Centro de Control (Pestaña 0 - Tablero modular interactivo)
        // ====================================================================
        ControlCenterView {
            id: controlCenterView
            Layout.fillWidth: true
            Layout.fillHeight: !systemTrayState.activeApplet && popup.currentTab === 0
            Layout.preferredHeight: (!systemTrayState.activeApplet && popup.currentTab === 0) ? -1 : 0
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: !systemTrayState.activeApplet && popup.currentTab === 0
            enabled: !systemTrayState.activeApplet && popup.currentTab === 0

            KeyNavigation.up: pinButton
        }

        // ====================================================================
        // VISTA 2: Bandeja del Sistema nativa (Pestaña 1)
        // ====================================================================
        HiddenItemsView {
            id: hiddenItemsView
            Layout.fillWidth: true
            Layout.fillHeight: !systemTrayState.activeApplet && popup.currentTab === 1
            Layout.preferredHeight: (!systemTrayState.activeApplet && popup.currentTab === 1) ? -1 : 0
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: !systemTrayState.activeApplet && popup.currentTab === 1
            enabled: !systemTrayState.activeApplet && popup.currentTab === 1

            KeyNavigation.up: pinButton

            onVisibleChanged: {
                if (visible) {
                    layout.forceActiveFocus();
                    systemTrayState.oldVisualIndex = systemTrayState.newVisualIndex = -1;
                }
            }
        }

        // ====================================================================
        // SUB-VISTA: Contenedor para detalles de applets (cuando se abre red/bluetooth/etc)
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
