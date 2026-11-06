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
        compare(WorkspaceLogic.workspaceIds(values, 5), [1, 2, 3, 4, 5, 8, 11]);
        compare(WorkspaceLogic.validId("7"), 7);
        compare(WorkspaceLogic.validId(0), 0);
        compare(WorkspaceLogic.validId("bad"), 0);
        compare(WorkspaceLogic.validId(11), 11);
        compare(WorkspaceLogic.validId(2.5), 0);
        compare(WorkspaceLogic.validId(Infinity), 0);
        compare(WorkspaceLogic.validId(2147483648), 0);
    }

    function test_monitorListsUseTheirOwnBlock() {
        const values = [
            {
                id: 1,
                monitor: {
                    name: "eDP-1"
                }
            },
            {
                id: 12,
                monitor: {
                    name: "DP-1"
                }
            },
            {
                id: 18,
                monitor: {
                    name: "DP-1"
                }
            },
            {
                id: 20,
                monitor: {
                    name: "DP-1"
                }
            },
            {
                id: 27,
                monitor: {
                    name: "DP-2"
                }
            },
            {
                id: -99,
                monitor: {
                    name: "DP-1"
                }
            }
        ];
        compare(WorkspaceLogic.monitorWorkspaceIds(values, 5, 0, "eDP-1"), [1, 2, 3, 4, 5]);
        compare(WorkspaceLogic.monitorWorkspaceIds(values, 5, 1, "DP-1"), [11, 12, 13, 14, 15, 18, 20]);
        compare(WorkspaceLogic.monitorWorkspaceIds(values, 5, 2, "DP-2"), [21, 22, 23, 24, 25, 27]);
        compare(WorkspaceLogic.monitorWorkspaceIds(values, 5, 1, ""), []);
        compare(WorkspaceLogic.records(values, 12, 5).map(record => record.id), [1, 2, 3, 4, 5, 12, 18, 20, 27]);
    }

    function test_labelsKeepGlobalIdsSeparate() {
        compare([1, 10, 11, 12, 20, 21, 30].map(WorkspaceLogic.label), ["1", "10", "1", "2", "10", "1", "10"]);
        compare(WorkspaceLogic.label(0), "");
        compare(WorkspaceLogic.label(-99), "");
    }

    function test_savedBlocksSurviveGuestWorkspacesAndConnectorChanges() {
        const blocks = WorkspaceLogic.parseBlocks("0\teDP-1\tLaptop\n2\tDP-7\tExternal\ninvalid\tDP-2\tBad\n-1\tDP-3\tBad\n1.5\tDP-4\tBad\n9999999999\tDP-5\tBad\n1\t\tMissing\n");
        compare(blocks, {
            "eDP-1": 0,
            "DP-7": 2
        });
        const values = [
            {
                id: 31,
                active: true,
                monitor: {
                    name: "DP-7"
                }
            }
        ];
        compare(WorkspaceLogic.monitorBlock(blocks, values, "DP-7"), 2);
        compare(WorkspaceLogic.monitorWorkspaceIds(values, 5, 2, "DP-7"), [21, 22, 23, 24, 25, 31]);
        compare(WorkspaceLogic.monitorBlock({}, values, "DP-7"), 3);
        compare(WorkspaceLogic.monitorBlock({}, [], "DP-7"), 0);
        compare(WorkspaceLogic.parseBlocks(""), {});
    }

    function test_unpluggedWorkspacesAreListedOnlyOnTheirCurrentMonitor() {
        const guest = {
            id: 23,
            active: true,
            monitor: {
                name: "DP-1"
            }
        };
        compare(WorkspaceLogic.monitorWorkspaceIds([guest], 5, 1, "DP-1"), [11, 12, 13, 14, 15, 23]);
        guest.monitor = {
            name: "DP-2"
        };
        compare(WorkspaceLogic.monitorWorkspaceIds([guest], 5, 1, "DP-1"), [11, 12, 13, 14, 15]);
        compare(WorkspaceLogic.monitorWorkspaceIds([guest], 5, 2, "DP-2"), [21, 22, 23, 24, 25]);
    }

    function test_ownWorkspaceActivationUsesMonitorAwareOmarchyHelper() {
        compare(WorkspaceLogic.focusCommand(11, 1, "DP-1"), 'o.workspaces.focus(1, "DP-1")');
        compare(WorkspaceLogic.focusCommand(20, 1, "DP-1"), 'o.workspaces.focus(10, "DP-1")');
        compare(WorkspaceLogic.focusCommand(2, 0, "eDP-1"), 'o.workspaces.focus(2, "eDP-1")');
        compare(WorkspaceLogic.focusCommand(23, 1, "DP-1"), 'hl.dsp.focus({ workspace = "23" })');
        compare(WorkspaceLogic.focusCommand(11, 1, 'DP-"1'), 'o.workspaces.focus(1, "DP-\\"1")');
        compare(WorkspaceLogic.focusCommand(-1, 1, "DP-1"), "");
        compare(WorkspaceLogic.focusCommand(11, 1, ""), "");
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

    function monitorWorkspaces() {
        return [
            {
                "id": 1,
                "active": true,
                "focused": true,
                "monitor": {
                    "name": "eDP-1"
                }
            },
            {
                "id": 2,
                "active": false,
                "focused": false,
                "monitor": {
                    "name": "eDP-1"
                }
            },
            {
                "id": 3,
                "active": true,
                "focused": false,
                "monitor": {
                    "name": "DP-1"
                }
            }
        ];
    }

    function test_monitorIndicatorsIgnoreFocusChanges() {
        const values = monitorWorkspaces();
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 1);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 3);
        values[0].focused = false;
        values[2].focused = true;
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 1);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 3);
    }

    function test_workspaceChangeOnlyUpdatesItsMonitor() {
        const values = monitorWorkspaces();
        values[0].active = false;
        values[1].active = true;
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 2);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 3);
    }

    function test_monitorReassignmentAndRemoval() {
        const values = monitorWorkspaces();
        values[0].monitor = {
            "name": "DP-1"
        };
        values[2].monitor = {
            "name": "eDP-1"
        };
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 3);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 1);
        values[2].monitor = null;
        compare(WorkspaceLogic.activeIdForMonitor(values, "eDP-1"), 0);
        compare(WorkspaceLogic.activeIdForMonitor(values, "DP-1"), 1);
        compare(WorkspaceLogic.activeIdForMonitor(values, "FALLBACK"), 0);
        compare(WorkspaceLogic.activeIdForMonitor(values, ""), 0);
        compare(WorkspaceLogic.activeIdForMonitor(null, "DP-1"), 0);
    }
}
