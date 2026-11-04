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
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.plasma.private.brightnesscontrolplugin

PlasmoidItem {
    id: root

    // Translation domain shared with Plasma Control Center
    readonly property string translationDomain: "plasma_applet_org.cesar.plasmacontrolcenter"

    property bool automaticMode: false

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge,
    ].includes(Plasmoid.location)

    preferredRepresentation: fullRepresentation

    Plasmoid.icon: {
        if (DarkModeControl.darkMode) {
            return inPanel ? "weather-clear-night-symbolic" : "weather-clear-night";
        }
        return inPanel ? "weather-clear-symbolic" : "weather-clear";
    }
    Plasmoid.status: PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18nd(translationDomain, "Dark Mode")
    toolTipSubText: {
        if (root.automaticMode) {
            return DarkModeControl.darkMode
                ? i18ndc(translationDomain, "@info:status Dark mode status", "Automatic (Dark)")
                : i18ndc(translationDomain, "@info:status Dark mode status", "Automatic (Light)");
        }
        return DarkModeControl.darkMode
            ? i18ndc(translationDomain, "@info:status Dark mode status", "On")
            : i18ndc(translationDomain, "@info:status Dark mode status", "Off");
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            if (sourceName === root.readCmd) {
                const out = (data["stdout"] ?? "").trim().toLowerCase();
                root.automaticMode = (out === "true" || out === "1");
            }
            disconnectSource(sourceName);
            if (sourceName !== root.readCmd) {
                executable.connectSource(root.readCmd);
            }
        }
    }

    readonly property string readCmd: "kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --default false"

    function refreshAutomaticState(): void {
        executable.connectSource(readCmd);
    }

    function setMode(mode: string): void {
        if (mode === "light") {
            root.automaticMode = false;
            executable.connectSource("kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --notify false");
            if (DarkModeControl.darkMode) {
                DarkModeControl.darkMode = false;
            }
        } else if (mode === "dark") {
            root.automaticMode = false;
            executable.connectSource("kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --notify false");
            if (!DarkModeControl.darkMode) {
                DarkModeControl.darkMode = true;
            }
        } else if (mode === "auto") {
            root.automaticMode = true;
            executable.connectSource("kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --notify true");
        }
    }

    function cycleMode(): void {
        if (root.automaticMode) {
            setMode("light");
        } else if (!DarkModeControl.darkMode) {
            setMode("dark");
        } else {
            setMode("auto");
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAutomaticState()
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.cycleMode();
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Light")
            icon.name: "weather-clear"
            checkable: true
            checked: !root.automaticMode && !DarkModeControl.darkMode
            onTriggered: root.setMode("light")
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Dark")
            icon.name: "weather-clear-night"
            checkable: true
            checked: !root.automaticMode && DarkModeControl.darkMode
            onTriggered: root.setMode("dark")
        },
        PlasmaCore.Action {
            text: i18ndc(root.translationDomain, "@action:inmenu", "Automatic (Time of Day)")
            icon.name: "preferences-system-time"
            checkable: true
            checked: root.automaticMode
            onTriggered: root.setMode("auto")
        }
    ]

    PlasmaCore.Action {
        id: configureAction
        text: i18ndc(root.translationDomain, "@action:inmenu", "Configure Global Theme…")
        icon.name: "configure"
        visible: KConfig.KAuthorized.authorizeControlModule("kcm_lookandfeel")
        onTriggered: KCMLauncher.openSystemSettings("kcm_lookandfeel")
    }

    Component.onCompleted: {
        Plasmoid.setInternalAction("configure", configureAction);
        refreshAutomaticState();
    }

    MouseArea {
        id: compactRoot
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {}
        onClicked: root.cycleMode()

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactRoot.containsMouse
        }
    }
}
