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

    property alias hiddenLayout: hiddenItemsView.layout
    property alias plasmoidContainer: container

    // Hardware applets that already have their own dedicated tiles in Control Center
    readonly property var redundantAppletIds: [
        "org.kde.plasma.volume",
        "org.kde.plasma.brightness",
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.bluetooth",
        "org.kde.plasma.battery",
        "org.cesar.plasmacontrolcenter.darkmode",
        "org.cesar.plasmacontrolcenter.donotdisturb",
        "org.cesar.plasmacontrolcenter.systemsettings",
        "org.cesar.plasmacontrolcenter.screenshot",
        "org.cesar.plasmacontrolcenter.airplanemode"
    ]

    // Filter to show only true passive system tray items in the bottom grid
    readonly property alias filteredTrayModel: filteredTrayModel
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
        : Math.min(Kirigami.Units.gridUnit * 38, hiddenItemsView.implicitHeight + plasmoidHeading.height + Kirigami.Units.smallSpacing * 2)

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

            // Restablecer diseño a macOS por defecto
            PlasmaComponents3.ToolButton {
                id: resetLayoutButton
                visible: (typeof root !== "undefined" && root.editMode) && !systemTrayState.activeApplet
                icon.name: "edit-reset"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18n("Restablecer diseño")
                onClicked: {
                    Plasmoid.configuration.tileOrder = [];
                    Plasmoid.configuration.tileSizes = [];
                }
                PlasmaComponents3.ToolTip {
                    text: resetLayoutButton.text
                }
            }

            // Modo edición de controles (Mover y cambiar tamaño)
            PlasmaComponents3.ToolButton {
                id: editButton
                visible: !systemTrayState.activeApplet
                checkable: true
                checked: (typeof root !== "undefined" && root.editMode)
                onToggled: if (typeof root !== "undefined") root.editMode = editButton.checked
                icon.name: editButton.checked ? "dialog-ok-apply" : "document-edit"
                highlighted: editButton.checked
                display: editButton.checked ? PlasmaComponents3.AbstractButton.TextBesideIcon : PlasmaComponents3.AbstractButton.IconOnly
                text: editButton.checked ? i18n("Hecho") : i18n("Editar controles")
                PlasmaComponents3.ToolTip {
                    text: editButton.checked ? i18n("Guardar organización de controles") : i18n("Reorganizar y redimensionar controles")
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
        // VISTA PRINCIPAL: Cuadrícula Modular macOS Sequoia (Golden Gate)
        // Tablero unificado de 4 columnas para controles del sistema y bandeja
        // ====================================================================
        HiddenItemsView {
            id: hiddenItemsView
            Layout.fillWidth: true
            Layout.fillHeight: !systemTrayState.activeApplet
            Layout.preferredHeight: systemTrayState.activeApplet ? 0 : -1
            visible: systemTrayState.activeApplet === null
            enabled: systemTrayState.activeApplet === null
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
