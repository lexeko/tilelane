pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import "qml/BarGeometry.js" as BarGeometry
import "qml/HintLogic.js" as HintLogic
import "qml/PanelRouting.js" as PanelRouting
import "qml/components"
import "qml/models"
import qs.Commons as Commons
import qs.Ui as Ui

Item {
    id: root

    // Public Quattro full-bar injection points. Defaults keep construction safe
    // in lint/test harnesses and when a capability is unavailable.
    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    property var barWidgetRegistry: null
    property var barConfig: ({})
    readonly property real barScale: BarGeometry.barScale(Commons.Style.spacingScale, Commons.Style.barScaleWithFont, Commons.Style.fontScale)
    readonly property real barHeight: BarGeometry.barHeight(barScale)
    readonly property real sectionGap: Math.round(12 * barScale)
    // Public bar surface consumed by host panels and future hosted widgets.
    // Keeping these scalar bindings available also lets persistent first-party
    // panels survive a stock/custom-bar transition without assuming internals.
    readonly property color foreground: Commons.Color.bar.text
    readonly property color barForeground: foreground
    readonly property color background: Commons.Color.bar.background
    readonly property color urgent: Commons.Color.bar.active
    readonly property string fontFamily: Commons.Style.font.family
    readonly property string position: "bottom"
    readonly property bool vertical: false
    readonly property int barSize: Math.round(barHeight)
    readonly property bool barHidden: false
    readonly property bool transparent: background.a < 1
    readonly property bool reducedMotion: tilelaneSettings.values.reducedMotion
    readonly property bool foregroundAnimationEnabled: !reducedMotion
    property var activePopout: null
    property var startMenus: []
    property var workspaceSwitchers: []
    property var statusViews: []
    property var taskLanes: []
    property var clickTargets: []
    property var hostedWidgets: []
    property var widgetHosts: []
    property var tooltipHosts: []
    property bool centerSectionRevealHeld: false
    property bool centerHoverRevealSuppressed: false
    property alias windowModel: globalWindows
    property alias workspaceModel: globalWorkspaces

    function registerTooltipHost(host) {
        if (!host || tooltipHosts.indexOf(host) !== -1)
            return;
        const next = tooltipHosts.slice(0);
        next.push(host);
        tooltipHosts = next;
    }

    function unregisterTooltipHost(host) {
        tooltipHosts = tooltipHosts.filter(function (candidate) {
            return candidate !== host;
        });
    }

    function showTooltip(target, text, delay) {
        for (let index = 0; index < tooltipHosts.length; index++) {
            const host = tooltipHosts[index];
            if (!host)
                continue;
            if (host.owns(target))
                host.showFor(target, text, delay);
            else
                host.clear();
        }
    }

    function hideTooltip(target) {
        for (let index = 0; index < tooltipHosts.length; index++) {
            const host = tooltipHosts[index];
            if (host)
                host.hideFor(target);
        }
    }

    function clearTooltip() {
        for (let index = 0; index < tooltipHosts.length; index++) {
            if (tooltipHosts[index])
                tooltipHosts[index].clear();
        }
    }

    function shortcut(description) {
        return shortcutCatalog.shortcut(description);
    }

    function actionHint(action, shortcutDescription) {
        return HintLogic.withShortcut(action, shortcut(shortcutDescription));
    }

    function requestPopout(owner) {
        clearTooltip();
        if (activePopout && activePopout !== owner && typeof activePopout.close === "function")
            activePopout.close();

        activePopout = owner;
    }

    function releasePopout(owner) {
        if (activePopout === owner)
            activePopout = null;
    }

    function switchPanelFrom(owner, direction) {
        const candidates = hostedWidgets.filter(function (record) {
            return record && record.item && typeof record.item.open === "function";
        });
        if (candidates.length < 2)
            return false;
        let currentIndex = -1;
        for (let index = 0; index < candidates.length; index++) {
            if (candidates[index].item === owner) {
                currentIndex = index;
                break;
            }
        }
        if (currentIndex < 0)
            return false;
        const step = direction < 0 ? -1 : 1;
        const next = candidates[(currentIndex + step + candidates.length) % candidates.length].item;
        next.open();
        return true;
    }

    function run(command) {
        if (command)
            Commons.Util.execDetached(command);
    }

    function motionDuration(duration) {
        return BarGeometry.motionDuration(duration, reducedMotion);
    }

    function setCenterHoverRevealSuppressed(value) {
        centerHoverRevealSuppressed = !!value;
    }

    function registerClickTarget(target) {
        if (!target || clickTargets.indexOf(target) !== -1)
            return;
        const next = clickTargets.slice(0);
        next.push(target);
        clickTargets = next;
    }

    function unregisterClickTarget(target) {
        clickTargets = clickTargets.filter(function (candidate) {
            return candidate !== target;
        });
    }

    function targetBelongsToWindow(target, window) {
        return !!target && target.QsWindow.window === window;
    }

    function registerHostedWidget(item, moduleName) {
        if (!item)
            return;
        for (let index = 0; index < hostedWidgets.length; index++) {
            if (hostedWidgets[index].item === item)
                return;
        }
        const next = hostedWidgets.slice(0);
        next.push({
            "item": item,
            "moduleName": String(moduleName || "")
        });
        hostedWidgets = next;
    }

    function unregisterHostedWidget(item) {
        hostedWidgets = hostedWidgets.filter(function (record) {
            return record && record.item !== item;
        });
    }

    function moduleWidgets(moduleName) {
        const result = [];
        for (let index = 0; index < hostedWidgets.length; index++) {
            const record = hostedWidgets[index];
            if (record && record.item && record.moduleName === String(moduleName || ""))
                result.push(record.item);
        }
        return result;
    }

    function registerWidgetHost(host) {
        if (host && widgetHosts.indexOf(host) === -1)
            widgetHosts = widgetHosts.concat([host]);
    }

    function unregisterWidgetHost(host) {
        widgetHosts = widgetHosts.filter(function (candidate) {
            return candidate !== host;
        });
    }

    function panelHostCandidates() {
        const candidates = [];
        for (let index = 0; index < widgetHosts.length; index++) {
            const host = widgetHosts[index];
            if (!host || !host.panelCapable || !host.hasLoadSource)
                continue;
            const window = host.QsWindow.window;
            if (!window || !window.visible)
                continue;
            candidates.push({
                host: host,
                screenName: window.screen ? String(window.screen.name || "") : "",
                opened: host.opened || host.pendingOpen,
                visible: host.visible && host.width > 0,
                x: host.mapToItem(null, 0, 0).x
            });
        }
        return candidates;
    }

    function findPanelHost(pluginId) {
        const candidates = panelHostCandidates().filter(function (row) {
            return row.host.moduleName === pluginId;
        });
        const monitor = Hyprland.focusedMonitor;
        return PanelRouting.pickHost(candidates, monitor ? String(monitor.name || "") : "");
    }

    function panelWidgetIdAt(section, index) {
        if (section !== "right")
            return "";
        const monitor = Hyprland.focusedMonitor;
        return PanelRouting.panelIdAt(panelHostCandidates(), index, monitor ? String(monitor.name || "") : "");
    }

    // Standard shell.summon/hide/toggle entry points used by Omarchy hotkeys.
    function summonBarWidget(pluginId) {
        const host = findPanelHost(pluginId);
        return !!host && host.open();
    }

    function hideBarWidget(pluginId) {
        const host = findPanelHost(pluginId);
        return !!host && host.close();
    }

    function isBarWidgetOpen(pluginId) {
        const host = findPanelHost(pluginId);
        return !!host && (host.opened || host.pendingOpen);
    }

    function barWidgetSetting(id, key, fallback) {
        const layout = barConfig && barConfig.layout ? barConfig.layout : ({});
        const sections = ["left", "center", "right"];
        for (let sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
            const entries = layout[sections[sectionIndex]] || [];
            for (let entryIndex = 0; entryIndex < entries.length; entryIndex++) {
                const entry = entries[entryIndex];
                if (entry && String(entry.id || entry) === id && entry[key] !== undefined)
                    return entry[key];
            }
        }
        return fallback;
    }

    function barWidgetSettings(id) {
        const layout = barConfig && barConfig.layout ? barConfig.layout : ({});
        const sections = ["left", "center", "right"];
        for (let sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
            const entries = layout[sections[sectionIndex]] || [];
            for (let entryIndex = 0; entryIndex < entries.length; entryIndex++) {
                const entry = entries[entryIndex];
                if (entry && String(entry.id || entry) === id)
                    return typeof entry === "object" ? entry : {
                        "id": id
                    };
            }
        }
        return {
            "id": id
        };
    }

    function toggleHostPanel(id, screenName, button) {
        if (!shell || typeof shell.toggle !== "function")
            return false;
        return shell.toggle(id, JSON.stringify({
            "screen": String(screenName || ""),
            "button": Number(button || Qt.LeftButton)
        }));
    }

    function openOmarchyMenu(menu) {
        if (!shell || typeof shell.summon !== "function")
            return false;
        return shell.summon("omarchy.menu", JSON.stringify({
            "menu": String(menu || "root")
        }));
    }

    function openPowerControls() {
        return openOmarchyMenu("system");
    }

    function registerStartMenu(menu) {
        const next = startMenus.slice(0);
        if (next.indexOf(menu) === -1)
            next.push(menu);
        startMenus = next;
    }

    function unregisterStartMenu(menu) {
        const next = startMenus.slice(0);
        const index = next.indexOf(menu);
        if (index !== -1)
            next.splice(index, 1);
        startMenus = next;
    }

    function startMenuFor(screenName) {
        const expected = String(screenName || "");
        for (let index = 0; index < startMenus.length; index++) {
            const menu = startMenus[index];
            if (menu && (expected === "" || String(menu.targetScreen ? menu.targetScreen.name || "" : "") === expected))
                return menu;
        }
        return null;
    }

    function registerWorkspaceSwitcher(switcher) {
        const next = workspaceSwitchers.slice(0);
        if (next.indexOf(switcher) === -1)
            next.push(switcher);
        workspaceSwitchers = next;
    }

    function unregisterWorkspaceSwitcher(switcher) {
        const next = workspaceSwitchers.slice(0);
        const index = next.indexOf(switcher);
        if (index !== -1)
            next.splice(index, 1);
        workspaceSwitchers = next;
    }

    function workspaceSwitcherFor(screenName) {
        const expected = String(screenName || "");
        for (let index = 0; index < workspaceSwitchers.length; index++) {
            const switcher = workspaceSwitchers[index];
            const window = switcher ? switcher.QsWindow.window : null;
            if (switcher && (expected === "" || String(window && window.screen ? window.screen.name || "" : "") === expected))
                return switcher;
        }
        return null;
    }

    function registerStatusView(view) {
        const next = statusViews.slice(0);
        if (next.indexOf(view) === -1)
            next.push(view);
        statusViews = next;
    }

    function unregisterStatusView(view) {
        const next = statusViews.slice(0);
        const index = next.indexOf(view);
        if (index !== -1)
            next.splice(index, 1);
        statusViews = next;
    }

    function statusViewFor(screenName) {
        const expected = String(screenName || "");
        for (let index = 0; index < statusViews.length; index++) {
            const view = statusViews[index];
            if (view && (expected === "" || view.screenName === expected))
                return view;
        }
        return null;
    }

    function registerTaskLane(lane) {
        const next = taskLanes.slice(0);
        if (next.indexOf(lane) === -1)
            next.push(lane);
        taskLanes = next;
    }

    function unregisterTaskLane(lane) {
        taskLanes = taskLanes.filter(function (candidate) {
            return candidate !== lane;
        });
    }

    function openTaskContextMenu(address, screenName) {
        const expectedScreen = String(screenName || "");
        for (let index = 0; index < taskLanes.length; index++) {
            const lane = taskLanes[index];
            if (!lane || expectedScreen !== "" && lane.screenName !== expectedScreen)
                continue;
            if (lane.openContextMenu(address))
                return true;
        }
        return false;
    }

    WindowModel {
        id: globalWindows
    }

    WindowActions {
        id: globalActions

        windowModel: globalWindows
    }

    TilelaneSettings {
        id: tilelaneSettings

        shell: root.shell
        barConfig: root.barConfig
        pluginId: root.manifest ? root.manifest.id : "io.github.lexeko.tilelane"
    }

    PinnedApplications {
        id: taskbarPinnedApplications

        settings: tilelaneSettings
        settingsKey: "tilelanePins"
    }

    PinnedApplications {
        id: startPinnedApplications

        settings: tilelaneSettings
        settingsKey: "tilelaneStartPins"
    }

    ApplicationCatalog {
        id: applicationCatalog

        omarchyPath: root.omarchyPath
        appLibrary: root.shell ? root.shell.appLibrary : null
        identityOverrides: tilelaneSettings.values.tilelaneIdentityOverrides
    }

    ShortcutCatalog {
        id: shortcutCatalog
    }

    WorkspaceModel {
        id: globalWorkspaces
    }

    Branding {
        id: branding
    }

    IpcHandler {
        target: "tilelane"

        function windowCount(): string {
            return String(globalWindows.model.count);
        }

        function revision(): string {
            return String(globalWindows.revision);
        }

        function windowState(address: string): string {
            const record = globalWindows.recordFor(address);
            if (!record)
                return JSON.stringify({
                    "present": false
                });
            return JSON.stringify({
                "present": true,
                "active": record.active,
                "urgent": record.urgent,
                "minimized": record.minimized,
                "fullscreen": record.fullscreen,
                "maximized": record.maximized,
                "floating": record.floating,
                "workspaceId": record.workspaceId,
                "workspaceName": record.workspaceName,
                "monitorName": record.monitorName
            });
        }

        function windowAction(address: string, action: string): string {
            if (["activate", "minimize", "restore", "maximize", "float", "close"].indexOf(action) === -1)
                return "unsupported";
            return globalActions.invoke(address, action) ? "queued" : "not-found";
        }

        function taskMenuOpen(address: string, screenName: string): string {
            if (!globalWindows.recordFor(address))
                return "not-found";
            return root.openTaskContextMenu(address, screenName) ? "opened" : "not-found";
        }

        function windowAddressForPid(pid: string): string {
            return globalWindows.addressForPid(Number(pid));
        }

        function windowAddressForAppId(appId: string): string {
            return globalWindows.addressForAppId(appId);
        }

        function pinCount(): string {
            return String(taskbarPinnedApplications.pins.length);
        }

        function pinAction(desktopId: string, action: string): string {
            if (action === "pin")
                return taskbarPinnedApplications.pin(desktopId) ? "queued" : "unchanged";
            if (action === "unpin")
                return taskbarPinnedApplications.unpin(desktopId) ? "queued" : "unchanged";
            if (action === "left")
                return taskbarPinnedApplications.move(desktopId, -1) ? "queued" : "unchanged";
            if (action === "right")
                return taskbarPinnedApplications.move(desktopId, 1) ? "queued" : "unchanged";
            if (action === "launch")
                return applicationCatalog.launch(desktopId) ? "launched" : "not-found";
            return "unsupported";
        }

        function startPinCount(): string {
            return String(startPinnedApplications.pins.length);
        }

        function startPinAction(desktopId: string, action: string): string {
            if (action === "pin")
                return startPinnedApplications.pin(desktopId) ? "queued" : "unchanged";
            if (action === "unpin")
                return startPinnedApplications.unpin(desktopId) ? "queued" : "unchanged";
            return "unsupported";
        }

        function reducedMotionState(): string {
            return JSON.stringify({
                "enabled": root.reducedMotion,
                "stored": tilelaneSettings.values.reducedMotion
            });
        }

        function reducedMotionSet(enabled: string): string {
            if (enabled !== "true" && enabled !== "false")
                return "unsupported";
            return tilelaneSettings.setValue("reducedMotion", enabled === "true") ? "updated" : "unchanged";
        }

        function workspaceState(): string {
            const records = [];
            for (let index = 0; index < globalWorkspaces.model.count; index++) {
                const workspace = globalWorkspaces.model.get(index);
                records.push({
                    "id": workspace.id,
                    "focused": workspace.focused,
                    "active": workspace.active,
                    "urgent": workspace.urgent,
                    "fullscreen": workspace.fullscreen,
                    "occupied": workspace.occupied,
                    "monitorName": workspace.monitorName
                });
            }
            return JSON.stringify(records);
        }

        function workspaceAction(id: string): string {
            return globalWorkspaces.activate(Number(id)) ? "queued" : "unsupported";
        }

        function workspaceToggle(screenName: string): string {
            const switcher = root.workspaceSwitcherFor(screenName);
            if (!switcher)
                return "not-found";
            switcher.toggle();
            return switcher.expanded ? "opened" : "closed";
        }

        function applicationIndexCount(): string {
            return String(applicationCatalog.applicationIndex.length);
        }

        function startSearch(query: string): string {
            const started = Date.now();
            const results = applicationCatalog.search(query);
            return JSON.stringify({
                "count": results.length,
                "elapsedMs": Date.now() - started
            });
        }

        function startToggle(screenName: string): string {
            const menu = root.startMenuFor(screenName);
            if (!menu)
                return "not-found";
            menu.toggle();
            return menu.open ? "opened" : "closed";
        }

        function startState(screenName: string): string {
            const menu = root.startMenuFor(screenName);
            if (!menu)
                return JSON.stringify({
                    "present": false
                });
            return JSON.stringify({
                "present": true,
                "open": menu.open,
                "screen": String(menu.targetScreen ? menu.targetScreen.name || "" : ""),
                "results": menu.results.length,
                "places": menu.placeCount,
                "pinnedPlaces": menu.pinnedPlaceCount,
                "searchMs": menu.lastSearchMs
            });
        }

        function trayCount(): string {
            const values = SystemTray.items.values || [];
            let count = 0;
            for (let index = 0; index < values.length; index++) {
                if (values[index] && values[index].status !== Status.Passive)
                    count++;
            }
            return String(count);
        }

        function trayToggle(screenName: string): string {
            const view = root.statusViewFor(screenName);
            if (!view || view.tray.itemCount === 0)
                return "not-found";
            view.tray.toggle();
            return view.tray.expanded ? "opened" : "closed";
        }

        function trayMenuOpen(screenName: string): string {
            const view = root.statusViewFor(screenName);
            return view && view.tray.openFirstMenu() ? "opened" : "not-found";
        }

        function statusState(screenName: string): string {
            const view = root.statusViewFor(screenName);
            if (!view)
                return JSON.stringify({
                    "present": false
                });
            return JSON.stringify({
                "present": true,
                "screen": view.screenName,
                "trayCount": view.tray.itemCount,
                "trayExpanded": view.tray.expanded,
                "panelControls": view.controls.visibleControlCount,
                "clock": view.clock.displayText
            });
        }

        function hostPanelToggle(id: string, screenName: string): string {
            const allowed = ["omarchy.clock", "omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.monitor", "omarchy.power", "omarchy.dropbox"];
            if (allowed.indexOf(id) === -1)
                return "unsupported";
            if (id === "omarchy.clock") {
                const view = root.statusViewFor(screenName);
                return view && view.clock.activate(Qt.LeftButton) ? "toggled" : "unavailable";
            }
            const view = root.statusViewFor(screenName);
            if (id === "omarchy.dropbox")
                return view && view.dropbox.visible && view.dropbox.activate(Qt.LeftButton) ? "toggled" : "unavailable";
            if (id === "omarchy.power")
                return view && view.power.visible && view.power.activate(Qt.LeftButton) ? "toggled" : "unavailable";
            if (view && view.controls.activateTarget(id, Qt.LeftButton))
                return "toggled";
            return root.toggleHostPanel(id, screenName, Qt.LeftButton) ? "toggled" : "unavailable";
        }

        function hostPanelState(id: string, screenName: string): string {
            const view = root.statusViewFor(screenName);
            if (!view)
                return JSON.stringify({
                    "present": false
                });
            if (id === "omarchy.clock")
                return JSON.stringify({
                    "present": true,
                    "available": view.clock.nativeAvailable
                });
            if (id === "omarchy.power") {
                const powerState = view.power.nativeState();
                powerState.present = true;
                return JSON.stringify(powerState);
            }
            if (id === "omarchy.dropbox") {
                const dropboxState = view.dropbox.nativeState();
                dropboxState.present = true;
                return JSON.stringify(dropboxState);
            }
            const state = view.controls.targetState(id);
            state.present = true;
            return JSON.stringify(state);
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            BarPanel {
                required property var modelData

                screen: modelData
            }
        }
    }

    component BarPanel: PanelWindow {
        id: barWindow

        property alias taskModel: screenWindows.model

        implicitHeight: root.barHeight
        color: Commons.Color.bar.background
        exclusionMode: ExclusionMode.Auto
        surfaceFormat.opaque: Commons.Color.bar.background.a >= 1
        WlrLayershell.namespace: "tilelane-bar"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            left: true
            right: true
            bottom: true
        }

        Component.onCompleted: {
            root.registerStartMenu(startMenu);
            root.registerWorkspaceSwitcher(workspaceSwitcher);
            root.registerStatusView(rightStatus);
            root.registerTaskLane(taskLane);
            root.registerTooltipHost(barHint);
        }
        Component.onDestruction: {
            root.unregisterStartMenu(startMenu);
            root.unregisterWorkspaceSwitcher(workspaceSwitcher);
            root.unregisterStatusView(rightStatus);
            root.unregisterTaskLane(taskLane);
            root.unregisterTooltipHost(barHint);
        }

        Ui.ScreenMoveRemap {
            window: barWindow
        }

        WindowFilter {
            id: screenWindows

            sourceModel: globalWindows.model
            sourceRevision: globalWindows.revision
            // Qt creates a synthetic FALLBACK screen while a real output is
            // temporarily unavailable. Hyprland has no matching monitor name
            // for it, so let the single fallback view show the global model.
            monitorName: barWindow.screen && barWindow.screen.name !== "FALLBACK" ? String(barWindow.screen.name || "") : ""
            workspacePolicy: "all"
        }

        TaskModel {
            id: tasks

            sourceModel: screenWindows.model
            sourceRevision: screenWindows.revision
            applicationCatalog: applicationCatalog
            applicationRevision: applicationCatalog.revision
        }

        Rectangle {
            anchors.fill: parent
            color: Commons.Color.bar.background
        }

        StartMenu {
            id: startMenu

            targetScreen: barWindow.screen
            applicationCatalog: applicationCatalog
            pinnedApplications: startPinnedApplications
            bar: root
            barWidgetRegistry: root.barWidgetRegistry
            uiScale: root.barScale
            barHeight: root.barHeight
        }

        StartButton {
            id: startButton

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            leftHitPadding: Math.round(5 * root.barScale)
            bottomHitPadding: Math.max(0, (barWindow.height - visualHeight) / 2)
            artwork: branding.artwork
            bar: root
            menuOpen: startMenu.open
            uiScale: root.barScale
            onClicked: startMenu.toggle()
        }

        WorkspaceSwitcher {
            id: workspaceSwitcher

            anchors.left: startButton.right
            anchors.leftMargin: root.sectionGap
            anchors.verticalCenter: parent.verticalCenter
            workspaceModel: globalWorkspaces
            bar: root
            uiScale: root.barScale
        }

        RightStatus {
            id: rightStatus

            readonly property bool primary: Quickshell.screens.length === 0 || barWindow.screen === Quickshell.screens[0]

            width: primary ? implicitWidth : 0
            height: implicitHeight
            visible: primary
            anchors.right: parent.right
            anchors.rightMargin: Math.round(5 * root.barScale)
            rightHitPadding: anchors.rightMargin
            anchors.verticalCenter: parent.verticalCenter
            bar: root
            barWidgetRegistry: root.barWidgetRegistry
            clockSettings: root.barWidgetSettings("omarchy.clock")
            screenName: barWindow.screen ? String(barWindow.screen.name || "") : ""
            uiScale: root.barScale
            compact: BarGeometry.statusCompact(barWindow.width, root.barScale)
            clockFormat: String(root.barWidgetSetting("omarchy.clock", "format", "h:mm AP"))
        }

        TaskLane {
            id: taskLane

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: workspaceSwitcher.right
            anchors.leftMargin: root.sectionGap
            anchors.right: rightStatus.left
            anchors.rightMargin: root.sectionGap
            sectionGap: root.sectionGap
            model: tasks.model
            actions: globalActions
            applicationCatalog: applicationCatalog
            pinnedApplications: taskbarPinnedApplications
            bar: root
            barHeight: root.barHeight
            uiScale: root.barScale
            screenName: barWindow.screen ? String(barWindow.screen.name || "") : ""
        }

        BarHint {
            id: barHint

            barWindow: barWindow
            uiScale: root.barScale
        }
    }
}
