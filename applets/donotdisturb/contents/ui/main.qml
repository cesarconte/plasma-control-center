/*
    SPDX-FileCopyrightText: 2026 Plasma Control Center contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.config as KConfig
import org.kde.kcmutils
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string translationDomain: "plasma_applet_org.cesar.plasmacontrolcenter"

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge,
    ].includes(Plasmoid.location)

    preferredRepresentation: fullRepresentation

    NotificationManager.Settings {
        id: notificationSettings
        live: true
    }

    readonly property bool inhibited: {
        const until = notificationSettings.notificationsInhibitedUntil;
        const timeValid = until !== undefined && until !== null && !isNaN(until.getTime()) && until.getTime() > Date.now();
        return timeValid || notificationSettings.notificationsInhibitedByApplication;
    }

    Plasmoid.icon: {
        if (root.inhibited) {
            return inPanel ? "notifications-disabled-symbolic" : "notifications-disabled";
        }
        return inPanel ? "notification-inactive-symbolic" : "notification-inactive";
    }
    Plasmoid.status: PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18nd(translationDomain, "Do Not Disturb")
    toolTipSubText: root.inhibited
        ? i18ndc(translationDomain, "@info:status Do Not Disturb status", "On")
        : i18ndc(translationDomain, "@info:status Do Not Disturb status", "Off")

    function disableDoNotDisturb(): void {
        notificationSettings.notificationsInhibitedUntil = undefined;
        notificationSettings.revokeApplicationInhibitions();
        notificationSettings.save();
    }

    function enableForHours(hours: int): void {
        const d = new Date();
        d.setHours(d.getHours() + hours);
        notificationSettings.notificationsInhibitedUntil = d;
        notificationSettings.save();
    }

    function enableIndefinitely(): void {
        const d = new Date();
        d.setFullYear(d.getFullYear() + 1);
        notificationSettings.notificationsInhibitedUntil = d;
        notificationSettings.save();
    }

    function toggleDoNotDisturb(): void {
        if (root.inhibited) {
            disableDoNotDisturb();
        } else {
            enableIndefinitely();
        }
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.toggleDoNotDisturb();
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "For 1 hour")
            onTriggered: root.enableForHours(1)
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "For 4 hours")
            onTriggered: root.enableForHours(4)
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Until manually disabled")
            checkable: true
            checked: root.inhibited
            onTriggered: root.toggleDoNotDisturb()
        }
    ]

    PlasmaCore.Action {
        id: configureAction
        text: i18ndc(root.translationDomain, "@action:inmenu", "Configure Notifications…")
        icon.name: "configure"
        visible: KConfig.KAuthorized.authorizeControlModule("kcm_notifications")
        onTriggered: KCMLauncher.openSystemSettings("kcm_notifications")
    }

    Component.onCompleted: {
        Plasmoid.setInternalAction("configure", configureAction);
    }

    MouseArea {
        id: compactRoot
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {}
        onClicked: root.toggleDoNotDisturb()

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactRoot.containsMouse
        }
    }
}
