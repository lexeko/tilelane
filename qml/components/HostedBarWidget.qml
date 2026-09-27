pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property string moduleName
    property var registry: null
    property var bar: null
    property Item clickTarget: null
    property var settings: ({})
    property string fallbackEntryPoint: ""
    property bool lazy: false
    property bool showVisual: false
    property bool alignPanelToHost: false
    property real minimumVisualWidth: 0
    property real visualHeight: 0
    property bool loadRequested: !lazy
    property int pendingButton: -1
    property bool pendingOpen: false
    property var registeredBar: null
    property var registeredItem: null
    readonly property var entry: registry && registry.widgets ? registry.widgets[moduleName] : null
    readonly property string sourceDir: entry && entry.metadata ? String(entry.metadata.sourceDir || "") : ""
    readonly property string manifestEntryPoint: manifestLoader.item ? manifestLoader.item.entryPoint : ""
    readonly property string fallbackSource: {
        const path = fallbackEntryPoint || manifestEntryPoint;
        if (!entry || entry.component || sourceDir === "" || path === "")
            return "";
        return "file://" + sourceDir + "/" + path;
    }
    readonly property bool hasLoadSource: !!entry && (!!entry.component || fallbackSource !== "")
    readonly property var hostItem: registryLoader.item || fallbackLoader.item
    readonly property bool available: !!hostItem
    readonly property bool opened: available && hostItem.opened === true
    readonly property bool panelCapable: lazy || (available && typeof hostItem.open === "function" && typeof hostItem.close === "function" && hostItem.opened !== undefined)

    implicitWidth: showVisual && available && hostItem.visible !== false ? Math.max(minimumVisualWidth, Number(hostItem.implicitWidth || 0)) : 0
    implicitHeight: showVisual && available && hostItem.visible !== false ? Math.max(visualHeight, Number(hostItem.implicitHeight || 0)) : 0

    // Register the host even while its native panel is unloaded, so shell
    // shortcuts can find and summon lazy panels before their first click.
    function syncHostRegistration() {
        if (registeredBar === bar)
            return;
        if (registeredBar && typeof registeredBar.unregisterWidgetHost === "function")
            registeredBar.unregisterWidgetHost(root);
        registeredBar = bar;
        if (registeredBar && typeof registeredBar.registerWidgetHost === "function")
            registeredBar.registerWidgetHost(root);
    }

    function open() {
        if (!hostItem) {
            if (!hasLoadSource)
                return false;
            pendingButton = -1;
            pendingOpen = true;
            loadRequested = true;
            return true;
        }
        pendingOpen = false;
        pendingButton = -1;
        configure();
        if (typeof hostItem.open !== "function")
            return false;
        hostItem.open();
        return true;
    }

    function close() {
        pendingOpen = false;
        pendingButton = -1;
        if (hostItem && typeof hostItem.close === "function")
            hostItem.close();
        if (lazy)
            unloadTimer.restart();
        return hasLoadSource;
    }

    function syncRegistration() {
        if (registeredItem === hostItem)
            return;
        if (registeredItem && bar && typeof bar.unregisterHostedWidget === "function")
            bar.unregisterHostedWidget(registeredItem);
        registeredItem = hostItem;
        if (registeredItem && bar && typeof bar.registerHostedWidget === "function")
            bar.registerHostedWidget(registeredItem, moduleName);
    }

    function configure() {
        const item = hostItem;
        if (!item)
            return;
        if ("bar" in item)
            item.bar = bar;
        if ("settings" in item)
            item.settings = settings;
        if ("moduleName" in item)
            item.moduleName = moduleName;
        if (alignPanelToHost)
            alignNestedPanels(item, [], 0);
        // Pointer events belong to the visible Tilelane control, including
        // clicks forwarded by an open panel over the bar.
        if (clickTarget && bar) {
            const nativeButton = findPressTarget(item, 0);
            if (nativeButton && nativeButton !== clickTarget)
                bar.unregisterClickTarget(nativeButton);
            bar.registerClickTarget(clickTarget);
        }
    }

    function alignNestedPanels(owner, visited, depth) {
        if (!owner || depth > 8 || visited.indexOf(owner) !== -1)
            return false;
        visited.push(owner);
        let aligned = false;
        if ("centerOnBar" in owner) {
            owner.centerOnBar = false;
            aligned = true;
        }
        if ("item" in owner && owner.item)
            aligned = alignNestedPanels(owner.item, visited, depth + 1) || aligned;
        const objects = owner.data ? owner.data : [];
        for (let index = 0; index < objects.length; index++)
            aligned = alignNestedPanels(objects[index], visited, depth + 1) || aligned;
        return aligned;
    }

    function capabilityState() {
        const item = hostItem;
        return {
            "moduleName": moduleName,
            "hasEntry": !!entry,
            "hasComponent": !!entry && !!entry.component,
            "available": available,
            "status": registryLoader.active ? registryLoader.status : fallbackLoader.status,
            "opened": opened,
            "togglePanel": !!item && typeof item.togglePanel === "function",
            "toggle": !!item && typeof item.toggle === "function",
            "open": !!item && typeof item.open === "function",
            "controller": !!item && !!item.controller
        };
    }

    function findPressTarget(item, depth) {
        if (!item || depth > 6)
            return null;
        if (typeof item.triggerPress === "function")
            return item;
        const children = item.children || [];
        for (let index = 0; index < children.length; index++) {
            const target = findPressTarget(children[index], depth + 1);
            if (target)
                return target;
        }
        return null;
    }

    function trigger(button) {
        pendingOpen = false;
        const item = hostItem;
        if (!item) {
            if (!hasLoadSource)
                return false;
            pendingButton = button;
            loadRequested = true;
            return true;
        }
        pendingButton = -1;
        let handled = false;
        const pressTarget = findPressTarget(item, 0);
        if (pressTarget) {
            pressTarget.triggerPress(button);
            handled = true;
        } else if (button === Qt.RightButton && typeof item.cycleFormat === "function") {
            item.cycleFormat();
            handled = true;
        } else if (button === Qt.RightButton && typeof item.togglePercentage === "function") {
            item.togglePercentage();
            handled = true;
        } else if (button !== Qt.LeftButton) {
            handled = false;
        } else if (typeof item.togglePanel === "function") {
            item.togglePanel();
            handled = true;
        } else if (typeof item.toggle === "function") {
            item.toggle();
            handled = true;
        } else if (item.controller && typeof item.controller.toggle === "function") {
            item.controller.toggle();
            handled = true;
        } else if (typeof item.open === "function") {
            item.open();
            handled = true;
        }
        if (lazy) {
            Qt.callLater(function () {
                if (root.hostItem && !root.opened)
                    unloadTimer.restart();
            });
        }
        return handled;
    }

    onBarChanged: {
        configure();
        syncHostRegistration();
    }
    onSettingsChanged: configure()
    onAlignPanelToHostChanged: configure()
    onHostItemChanged: syncRegistration()
    onEntryChanged: {
        if (!entry) {
            pendingButton = -1;
            pendingOpen = false;
            loadRequested = !lazy;
        }
    }

    function finishLoading() {
        configure();
        syncRegistration();
        Qt.callLater(function () {
            root.configure();
            if (root.pendingOpen)
                root.open();
            else if (root.pendingButton >= 0)
                root.trigger(root.pendingButton);
            if (root.lazy && root.hostItem && root.hostItem.opened !== true)
                unloadTimer.restart();
        });
    }

    onOpenedChanged: {
        if (opened)
            unloadTimer.stop();
        else if (lazy)
            unloadTimer.restart();
    }

    Timer {
        id: unloadTimer

        interval: 250
        onTriggered: {
            if (root.lazy && root.hostItem && !root.opened)
                root.loadRequested = false;
        }
    }

    Loader {
        id: manifestLoader

        active: !!root.entry && !root.entry.component && root.sourceDir !== "" && root.fallbackEntryPoint === ""
        source: active ? "WidgetManifest.qml" : ""
        onLoaded: item.sourceDir = Qt.binding(function () {
            return root.sourceDir;
        })
    }

    Loader {
        id: registryLoader

        anchors.fill: parent
        active: root.loadRequested && !!root.entry && !!root.entry.component
        sourceComponent: root.entry ? root.entry.component : null
        opacity: root.showVisual ? 1 : 0
        onLoaded: root.finishLoading()
    }

    Loader {
        id: fallbackLoader

        anchors.fill: parent
        active: root.loadRequested && !!root.entry && !root.entry.component && root.fallbackSource !== ""
        source: root.fallbackSource
        opacity: root.showVisual ? 1 : 0
        onLoaded: root.finishLoading()
    }

    Component.onCompleted: syncHostRegistration()
    Component.onDestruction: {
        if (registeredBar && typeof registeredBar.unregisterWidgetHost === "function")
            registeredBar.unregisterWidgetHost(root);
        if (registeredItem && bar && typeof bar.unregisterHostedWidget === "function")
            bar.unregisterHostedWidget(registeredItem);
    }
}
