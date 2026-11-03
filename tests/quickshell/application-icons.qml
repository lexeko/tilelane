import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"
import "qml/components"
import "services"

ShellRoot {
    id: root

    readonly property string appId: "tilelane-late-icon"
    property int refreshRequests: 0
    property int localScans: 0

    AppLibrary {
        id: library
        omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    }

    // Use the same detached callback boundary as an installed third-party bar.
    PluginAppLibraryApi {
        id: api
        ownerPluginId: "tilelane-icon-test"
        _iconSource: function (name) {
            return library.iconSource(name);
        }
        _refreshIcons: function () {
            root.refreshRequests++;
            library.refreshIcons();
        }
    }

    QtObject {
        id: legacyLibrary
        function iconSource(name) {
            return library.iconSource(name);
        }
    }

    ApplicationCatalog {
        id: catalog
        appLibrary: Quickshell.env("TILELANE_ICON_LIBRARY") === "native" ? api : null
    }

    Connections {
        target: catalog.iconScanner
        function onStarted() {
            root.localScans++;
        }
    }

    QtObject {
        id: pins
        property var pins: [root.appId]
        function contains(id) {
            return pins.indexOf(id) >= 0;
        }
    }

    // Start's image binding, without its compositor-only PanelWindow.
    Item {
        id: menu
        Repeater {
            model: catalog.applicationIndex
            Image {
                required property var modelData
                source: catalog.iconSource(modelData.icon)
                sourceSize.width: 28
                sourceSize.height: 28
                asynchronous: true
            }
        }
    }

    TaskButton {
        id: task
        iconName: root.appId
        applicationCatalog: catalog
    }

    PinnedLauncher {
        id: pin
        desktopId: root.appId
        applicationCatalog: catalog
        pinnedApplications: pins
    }

    function readyImages(item, source) {
        if (!item)
            return 0;
        let count = item.source !== undefined && decodeURIComponent(String(item.source)) === decodeURIComponent(source) && item.status === Image.Ready ? 1 : 0;
        const children = item.children || [];
        for (let i = 0; i < children.length; i++)
            count += readyImages(children[i], source);
        return count;
    }

    IpcHandler {
        target: "test.icons"

        function openMenu(): void {
            if (typeof catalog.refreshIcons === "function")
                catalog.refreshIcons();
        }
        function useLibrary(mode: string): void {
            catalog.appLibrary = mode === "missing" ? null : mode === "legacy" ? legacyLibrary : api;
            catalog.refreshIcons();
        }
        function state(): string {
            const source = catalog.iconSource(root.appId);
            return JSON.stringify({
                listed: catalog.search(root.appId).length === 1,
                refreshRequests: root.refreshRequests + root.localScans,
                refreshesRemaining: catalog.iconRefreshesRemaining,
                indexed: !!(catalog.appLibrary ? library.iconIndex[root.appId] : catalog.iconIndex[root.appId]),
                source: source,
                taskSource: task.iconSource,
                pinSource: pin.iconSource,
                taskReady: root.readyImages(task, source),
                pinReady: root.readyImages(pin, source),
                menuReady: root.readyImages(menu, source)
            });
        }
    }
}
