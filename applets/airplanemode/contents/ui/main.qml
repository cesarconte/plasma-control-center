/*
    SPDX-FileCopyrightText: 2026 Plasma Control Center contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.config as KConfig
import org.kde.kcmutils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.networkmanagement as PlasmaNM
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

    PlasmaNM.Handler {
        id: nmHandler
    }

    readonly property bool active: PlasmaNM.Configuration.airplaneModeEnabled

    Plasmoid.icon: {
        if (root.active) {
            return inPanel ? "network-flightmode-on-symbolic" : "network-flightmode-on";
        }
        return inPanel ? "network-flightmode-off-symbolic" : "network-flightmode-off";
    }
    Plasmoid.status: PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18nd(translationDomain, "Airplane Mode")
    toolTipSubText: root.active
        ? i18ndc(translationDomain, "@info:status Airplane mode status", "On")
        : i18ndc(translationDomain, "@info:status Airplane mode status", "Off")

    function toggleAirplaneMode(): void {
        const next = !PlasmaNM.Configuration.airplaneModeEnabled;
        nmHandler.enableAirplaneMode(next);
        PlasmaNM.Configuration.airplaneModeEnabled = next;
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.toggleAirplaneMode();
        }
    }

    PlasmaCore.Action {
        id: configureAction
        text: i18ndc(root.translationDomain, "@action:inmenu", "Configure Network Connections…")
        icon.name: "configure"
        visible: KConfig.KAuthorized.authorizeControlModule("kcm_networkmanagement")
        onTriggered: KCMLauncher.openSystemSettings("kcm_networkmanagement")
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
        onClicked: root.toggleAirplaneMode()

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactRoot.containsMouse
        }
    }
}
