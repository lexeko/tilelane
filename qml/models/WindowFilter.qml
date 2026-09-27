import QtQuick
import "WindowState.js" as WindowState

Item {
    id: root

    required property var sourceModel
    property int sourceRevision: 0
    property int revision: 0
    property string monitorName: ""
    property string workspacePolicy: "all"
    property string workspaceName: ""
    property alias model: filtered

    function sourceRecords() {
        const records = [];
        if (!sourceModel)
            return records;

        for (let index = 0; index < sourceModel.count; index++)
            records.push(WindowState.copyRecord(sourceModel.get(index)));
        return records;
    }

    function indexForAddress(address, start) {
        for (let index = start; index < filtered.count; index++) {
            if (filtered.get(index).address === address)
                return index;
        }
        return -1;
    }

    function sync() {
        const desired = WindowState.filterRecords(sourceRecords(), monitorName, workspacePolicy, workspaceName);
        for (let targetIndex = 0; targetIndex < desired.length; targetIndex++) {
            const address = desired[targetIndex].address;
            const currentIndex = indexForAddress(address, targetIndex);
            if (currentIndex === -1) {
                filtered.insert(targetIndex, desired[targetIndex]);
            } else {
                if (currentIndex !== targetIndex)
                    filtered.move(currentIndex, targetIndex, 1);

                if (!WindowState.sameRecord(filtered.get(targetIndex), desired[targetIndex]))
                    filtered.set(targetIndex, desired[targetIndex]);
            }
        }
        while (filtered.count > desired.length)
            filtered.remove(filtered.count - 1);
        revision++;
    }

    visible: false
    onSourceRevisionChanged: sync()
    onMonitorNameChanged: sync()
    onWorkspacePolicyChanged: sync()
    onWorkspaceNameChanged: sync()
    Component.onCompleted: sync()

    ListModel {
        id: filtered

        dynamicRoles: true
    }
}
