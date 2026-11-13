/*
    SPDX-FileCopyrightText: 2026 Plasma Control Center contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
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

    Plasmoid.icon: inPanel ? "settings-configure-symbolic" : "systemsettings"
    Plasmoid.status: PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18nd(translationDomain, "System Settings")
    toolTipSubText: i18ndc(translationDomain, "@info:status System Settings tile subtitle", "Configure system")

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
        }
    }

    function openSettings(): void {
        const win = root.Window.window;
        if (win && win.appletInterface && win.appletInterface.systemTrayState) {
            win.appletInterface.systemTrayState.expanded = false;
        }
        executable.connectSource("systemsettings");
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.openSettings();
        }
    }

    MouseArea {
        id: compactRoot
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {}
        onClicked: root.openSettings()

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactRoot.containsMouse
        }
    }
}
