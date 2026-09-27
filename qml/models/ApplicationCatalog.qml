pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../AppIdentity.js" as AppIdentity
import "../StartLogic.js" as StartLogic

QtObject {
    id: root

    property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    property var appLibrary: null
    property var identityOverrides: ({})
    property int revision: 0
    property int indexRevision: 0
    readonly property var entries: DesktopEntries.applications.values || []
    property var applicationIndex: []
    property var configuredHiddenEntryIds: ({})
    property var desktopHiddenEntryIds: ({})
    readonly property string hiddenScannerPath: decodeURIComponent(String(Qt.resolvedUrl("../../scripts/hidden-desktop-entries")).replace(/^file:\/\//, ""))
    readonly property string launchHelperPath: decodeURIComponent(String(Qt.resolvedUrl("../../scripts/launch-application")).replace(/^file:\/\//, ""))

    onIdentityOverridesChanged: revision++

    function entryForId(desktopId) {
        return DesktopEntries.byId(String(desktopId || "")) || AppIdentity.entryById(entries, desktopId);
    }

    function presentationForId(desktopId) {
        return AppIdentity.entryById(applicationIndex, desktopId);
    }

    function entryIsHidden(entry) {
        if (!entry)
            return true;
        const id = String(entry.id || "");
        return entry.noDisplay === true || configuredHiddenEntryIds[id] === true || desktopHiddenEntryIds[id] === true;
    }

    function identityEntries() {
        const visible = [];
        for (let index = 0; index < entries.length; index++) {
            if (!entryIsHidden(entries[index]))
                visible.push(entries[index]);
        }
        return visible;
    }

    function entryFor(record) {
        const visibleEntries = identityEntries();
        const resolved = AppIdentity.findEntry(visibleEntries, record, identityOverrides);
        if (resolved)
            return resolved;
        const candidates = AppIdentity.identityCandidates(record);
        for (let index = 0; index < candidates.length; index++) {
            const heuristic = DesktopEntries.heuristicLookup(candidates[index]);
            if (heuristic && !entryIsHidden(heuristic))
                return heuristic;
        }
        return null;
    }

    function identityFor(record) {
        return AppIdentity.identity(entryFor(record), record);
    }

    function iconSource(iconName) {
        const value = String(iconName || "");
        if (appLibrary && typeof appLibrary.iconSource === "function")
            return appLibrary.iconSource(value);
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0)
            return value;
        if (value.charAt(0) === "/")
            return "file://" + value.split("/").map(encodeURIComponent).join("/");
        return Quickshell.iconPath(value || "application-x-executable", true);
    }

    function launchRequest(desktopId) {
        const entry = entryForId(desktopId);
        if (!entry)
            return null;
        const fileId = StartLogic.desktopFileId(entry.id);
        if (fileId === "")
            return null;
        return {
            "entry": entry,
            "fileId": fileId,
            "expectedWindowId": AppIdentity.expectedWindowId(entry),
            "webAppHost": AppIdentity.webAppHost(entry),
            "runInTerminal": entry.runInTerminal === true
        };
    }

    function launchWithHelper(request, mode, controlReported) {
        try {
            Quickshell.execDetached(["bash", launchHelperPath, mode, controlReported === true ? "1" : "0", request.fileId, request.expectedWindowId, request.webAppHost, request.runInTerminal ? "1" : "0"]);
            return true;
        } catch (error) {
            return false;
        }
    }

    function launch(desktopId, floating) {
        const request = launchRequest(desktopId);
        if (!request)
            return false;
        if (floating === true)
            return launchWithHelper(request, "floating", true);
        try {
            Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", request.fileId]);
            return true;
        } catch (error) {
            return false;
        }
    }

    function launchFromPointer(desktopId, modifiers) {
        const request = launchRequest(desktopId);
        if (!request)
            return false;
        return launchWithHelper(request, "auto", AppIdentity.controlPressed(modifiers));
    }

    function launchPlace(uri, modifiers, fromPointer) {
        if (!uri)
            return false;
        const control = AppIdentity.controlPressed(modifiers);
        const mode = fromPointer ? "auto" : control ? "floating" : "normal";
        try {
            Quickshell.execDetached(["bash", launchHelperPath, mode, control ? "1" : "0", "org.gnome.Nautilus.desktop", "org.gnome.Nautilus", "", "0", String(uri)]);
            return true;
        } catch (error) {
            return false;
        }
    }

    function reindex() {
        const hidden = ({});
        for (const id in configuredHiddenEntryIds)
            hidden[id] = true;
        for (const id in desktopHiddenEntryIds)
            hidden[id] = true;
        applicationIndex = StartLogic.indexEntries(entries, hidden);
        indexRevision++;
    }

    function search(query) {
        return StartLogic.filter(applicationIndex, query);
    }

    function loadConfiguredHides(text) {
        configuredHiddenEntryIds = StartLogic.idSet(text);
        reindex();
        revision++;
    }

    function loadDesktopHides(text) {
        desktopHiddenEntryIds = StartLogic.idSet(text);
        reindex();
        revision++;
    }

    function currentDesktopNames() {
        return [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")].filter(function (value) {
            return String(value || "") !== "";
        }).join(":");
    }

    property Connections applicationChanges: Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            root.reindex();
            root.revision++;
            root.hiddenScanDebounce.restart();
        }
    }

    property FileView configuredHides: FileView {
        path: root.omarchyPath + "/default/omarchy/launcher.hides"
        watchChanges: true
        printErrors: false

        onLoaded: root.loadConfiguredHides(text())
        onFileChanged: root.loadConfiguredHides(text())
        onLoadFailed: root.loadConfiguredHides("")
    }

    property Process desktopHideScanner: Process {
        command: ["bash", root.hiddenScannerPath, root.currentDesktopNames()]
        stdout: StdioCollector {
            onStreamFinished: root.loadDesktopHides(text)
        }
    }

    property Timer hiddenScanDebounce: Timer {
        interval: 250
        onTriggered: if (!root.desktopHideScanner.running)
            root.desktopHideScanner.running = true
    }

    Component.onCompleted: {
        reindex();
        desktopHideScanner.running = true;
    }
}
