import QtQuick
import QtTest
import "../../qml/WorkspaceLogic.js" as WorkspaceLogic

TestCase {
    name: "WorkspaceLogic"

    function test_defaultAndLiveWorkspaceIdsAreBoundedAndSorted() {
        const values = [
            {
                "id": 8
            },
            {
                "id": -99
            },
            {
                "id": 3
            },
            {
                "id": 11
            }
        ];
        compare(WorkspaceLogic.workspaceIds(values, 5), [1, 2, 3, 4, 5, 8]);
        compare(WorkspaceLogic.validId("7"), 7);
        compare(WorkspaceLogic.validId(0), 0);
        compare(WorkspaceLogic.validId("bad"), 0);
    }

    function test_recordsPreserveEventBackedState() {
        const records = WorkspaceLogic.records([
            {
                "id": 2,
                "name": "work",
                "active": true,
                "urgent": true,
                "hasFullscreen": true,
                "monitor": {
                    "name": "DP-1"
                },
                "toplevels": {
                    "values": [
                        {}
                    ]
                }
            }
        ], 2, 2);
        compare(records.length, 2);
        verify(records[1].focused);
        verify(records[1].active);
        verify(records[1].urgent);
        verify(records[1].fullscreen);
        verify(records[1].occupied);
        compare(records[1].monitorName, "DP-1");
        verify(WorkspaceLogic.sameRecord(records[1], records[1]));
    }
}
