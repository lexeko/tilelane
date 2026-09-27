import QtQuick
import QtTest
import "../../qml/models"
import "../../qml/BarGeometry.js" as BarGeometry

TestCase {
    id: testCase

    name: "TaskModel"
    when: windowShown

    ListModel {
        id: windows
    }

    QtObject {
        id: catalog

        property string iconName: "application"

        function identityFor(record) {
            return {
                desktopId: record.appId,
                name: record.appId,
                icon: iconName
            };
        }
    }

    TaskModel {
        id: tasks

        sourceModel: windows
        sourceRevision: 0
        applicationCatalog: catalog
        applicationRevision: 0
    }

    Flickable {
        id: viewport

        width: 100
        height: 32
        contentWidth: taskRow.implicitWidth
        onContentWidthChanged: contentX = BarGeometry.taskScrollOffset(contentX, 0, contentWidth, width)

        Row {
            id: taskRow

            Repeater {
                id: buttons

                model: tasks.model

                delegate: Item {
                    required property string address
                    required property string title
                    required property string iconName
                    required property bool minimized
                    required property bool maximized

                    width: 80
                    height: 32
                }
            }
        }
    }

    SignalSpy {
        id: removed

        target: buttons
        signalName: "itemRemoved"
    }

    SignalSpy {
        id: added

        target: buttons
        signalName: "itemAdded"
    }

    function windowRecord(address, order) {
        return {
            address: address,
            title: "Window " + order,
            appId: "example",
            active: false,
            urgent: false,
            minimized: false,
            fullscreen: false,
            maximized: false,
            floating: false,
            orderKey: order
        };
    }

    function addresses() {
        const result = [];
        for (let index = 0; index < buttons.count; index++)
            result.push(buttons.itemAt(index).address);
        return result.join(",");
    }

    function init() {
        windows.clear();
        catalog.iconName = "application";
        windows.append(windowRecord("0xa", 1));
        windows.append(windowRecord("0xb", 2));
        windows.append(windowRecord("0xc", 3));
        tasks.sourceRevision++;
        tryCompare(buttons, "count", 3);
        removed.clear();
        added.clear();
    }

    function cleanup() {
        windows.clear();
        tasks.sourceRevision++;
    }

    function test_stateAndMetadataUpdatesKeepButtonsInOpeningOrder() {
        const original = [buttons.itemAt(0), buttons.itemAt(1), buttons.itemAt(2)];
        tryCompare(viewport, "contentWidth", 240);
        viewport.contentX = 80;
        for (const change of [
            {
                minimized: true
            },
            {
                minimized: false,
                active: true
            },
            {
                maximized: true
            },
            {
                maximized: false
            },
            {
                title: "Renamed",
                urgent: true
            }
        ]) {
            windows.set(0, change);
            tasks.sourceRevision++;
            compare(addresses(), "0xa,0xb,0xc");
            for (let index = 0; index < original.length; index++)
                compare(buttons.itemAt(index), original[index]);
            for (const role in change) {
                compare(tasks.model.get(0)[role], change[role]);
            }
            compare(viewport.contentX, 80);
        }
        catalog.iconName = "resolved-icon";
        tasks.applicationRevision++;
        compare(buttons.itemAt(0).iconName, "resolved-icon");
        compare(buttons.itemAt(0).title, "Renamed");
        compare(viewport.contentX, 80);
        compare(removed.count, 0);
        compare(added.count, 0);
    }

    function test_sourceReorderingDoesNotChangeTaskOrder() {
        const first = buttons.itemAt(0);
        windows.move(2, 0, 1);
        tasks.sourceRevision++;
        compare(addresses(), "0xa,0xb,0xc");
        compare(buttons.itemAt(0), first);
        compare(removed.count, 0);
        compare(added.count, 0);
    }

    function test_newWindowsAppendAndClosingPreservesSurvivors() {
        const first = buttons.itemAt(0);
        const third = buttons.itemAt(2);
        windows.insert(0, windowRecord("0xd", 4));
        tasks.sourceRevision++;
        compare(addresses(), "0xa,0xb,0xc,0xd");
        compare(added.count, 1);
        compare(removed.count, 0);

        windows.remove(2);
        tasks.sourceRevision++;
        compare(addresses(), "0xa,0xc,0xd");
        compare(buttons.itemAt(0), first);
        compare(buttons.itemAt(1), third);
        compare(removed.count, 1);
        compare(added.count, 1);

        windows.append(windowRecord("0xb", 5));
        tasks.sourceRevision++;
        compare(addresses(), "0xa,0xc,0xd,0xb");
    }
}
