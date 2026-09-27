import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase
    name: "HostedObjectTree"
    when: windowShown

    Item {
        id: widget
        property alias nested: nested
        Loader {
            id: nested
            active: false
            sourceComponent: Item {
                property string label: "ready"
            }
        }
    }
    HostedObjectTree {
        id: tree
        objectRoot: widget
    }

    function cleanup() {
        nested.active = false;
        tree.objectRoot = widget;
    }

    function test_nestedLoaderArrivalAndRemoval() {
        compare(tree.objects.indexOf(nested.item), -1);
        nested.active = true;
        tryVerify(() => tree.objects.indexOf(nested.item) !== -1);
        compare(tree.objects.find(object => object && object.label === "ready"), nested.item);
        nested.active = false;
        tryVerify(() => !tree.objects.some(object => object && object.label === "ready"));
    }

    function test_replacingRootDisconnectsOldTree() {
        tree.objectRoot = null;
        compare(tree.objects.length, 0);
        nested.active = true;
        wait(1);
        compare(tree.objects.length, 0);
        tree.objectRoot = widget;
        tryVerify(() => tree.objects.indexOf(nested.item) !== -1);
    }
}
