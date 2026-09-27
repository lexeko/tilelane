pragma ComponentBehavior: Bound

import QtQuick
import "../StatusWidgetLogic.js" as StatusWidgetLogic

Item {
    id: root

    property var config: ({})
    property var registry: null
    readonly property var widgets: registry && registry.widgets ? registry.widgets : ({})
    property alias model: entries
    property int revision: 0

    function sync() {
        const desired = StatusWidgetLogic.records(config, widgets);
        let changed = false;
        for (let index = 0; index < desired.length; index++) {
            let found = -1;
            for (let current = index; current < entries.count; current++) {
                if (entries.get(current).key === desired[index].key) {
                    found = current;
                    break;
                }
            }
            if (found < 0) {
                entries.insert(index, desired[index]);
                changed = true;
            } else {
                if (found !== index) {
                    entries.move(found, index, 1);
                    changed = true;
                }
                if (!StatusWidgetLogic.sameRecord(entries.get(index), desired[index])) {
                    entries.set(index, desired[index]);
                    changed = true;
                }
            }
        }
        while (entries.count > desired.length) {
            entries.remove(entries.count - 1);
            changed = true;
        }
        if (changed)
            revision++;
    }

    visible: false
    onConfigChanged: sync()
    onWidgetsChanged: sync()
    Component.onCompleted: sync()

    ListModel {
        id: entries
        dynamicRoles: true
    }
}
