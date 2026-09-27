pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var objectRoot: null
    property var objects: []
    property var watchers: []
    property bool stopped: false
    property bool refreshing: false
    signal refreshed

    function scheduleRefresh() {
        if (!stopped)
            Qt.callLater(refresh);
    }

    function refresh() {
        if (stopped)
            return;
        if (refreshing) {
            scheduleRefresh();
            return;
        }
        refreshing = true;
        const found = [];
        function visit(object, depth) {
            if (!object || depth > 32 || found.indexOf(object) !== -1)
                return;
            found.push(object);
            if (object instanceof Loader)
                visit(object.item, depth + 1);
            const children = object.data || [];
            for (let index = 0; index < children.length; index++)
                visit(children[index], depth + 1);
        }
        // Read data imperatively: QObject's data list has no notify signal.
        visit(objectRoot, 0);
        const next = [];
        for (let index = 0; index < found.length; index++) {
            const object = found[index];
            const existing = watchers.find(watcher => watcher.target === object);
            next.push(existing || observer.createObject(root, {
                target: object
            }));
        }
        for (let index = 0; index < watchers.length; index++) {
            if (next.indexOf(watchers[index]) === -1)
                watchers[index].destroy();
        }
        watchers = next;
        objects = found;
        refreshing = false;
        refreshed();
    }

    onObjectRootChanged: refresh()

    Component {
        id: observer
        Connections {
            id: connection
            ignoreUnknownSignals: true
            function onEnabledChanged() {
                if (!root.stopped)
                    root.refreshed();
            }
            function onItemChanged() {
                root.refresh();
            }
            function onChildrenChanged() {
                if (connection.target instanceof Loader)
                    root.refresh();
                else
                    root.scheduleRefresh();
            }
        }
    }

    Component.onDestruction: stopped = true
}
