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

    Plasmoid.icon: inPanel ? "camera-photo-symbolic" : "spectacle"
    Plasmoid.status: PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18nd(translationDomain, "Screenshot")
    toolTipSubText: i18ndc(translationDomain, "@info:status Screenshot tile subtitle", "Capture screen")

    property string pendingCommand: ""

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
        }
    }

    Timer {
        id: launchTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root.pendingCommand.length > 0) {
                executable.connectSource(root.pendingCommand);
                root.pendingCommand = "";
            }
        }
    }

    function runSpectacle(args: string): void {
        const win = root.Window.window;
        if (win && win.appletInterface && win.appletInterface.systemTrayState) {
            win.appletInterface.systemTrayState.expanded = false;
        }
        root.pendingCommand = "spectacle " + args;
        launchTimer.restart();
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.runSpectacle("-r");
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Capture Rectangular Region")
            icon.name: "select-rectangular"
            onTriggered: root.runSpectacle("-r")
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Capture Entire Desktop")
            icon.name: "Monitor"
            onTriggered: root.runSpectacle("-f")
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Capture Active Window")
            icon.name: "window"
            onTriggered: root.runSpectacle("-a")
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Record Screen")
            icon.name: "camera-video"
            onTriggered: root.runSpectacle("-R screen")
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Open Spectacle")
            icon.name: "spectacle"
            onTriggered: root.runSpectacle("-l")
        }
    ]

    MouseArea {
        id: compactRoot
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {}
        onClicked: root.runSpectacle("-r")

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactRoot.containsMouse
        }
    }
}
