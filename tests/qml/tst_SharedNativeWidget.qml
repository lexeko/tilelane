import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: tests
    name: "SharedNativeWidget"
    when: windowShown
    visible: true
    width: 300
    height: 100
    property int instances: 0

    QtObject {
        id: fakeBar
        property real barHeight: 44
        function registerWidgetHost(host) {
        }
        function unregisterWidgetHost(host) {
        }
        function registerHostedWidget(item, name) {
        }
        function unregisterHostedWidget(item) {
        }
        function registerClickTarget(target) {
        }
        function unregisterClickTarget(target) {
        }
        function showTooltip(target, text, delay) {
        }
        function hideTooltip(target) {
        }
    }
    QtObject {
        id: registry
        property var widgets: ({})
    }
    Component {
        id: nativeComponent
        Item {
            id: native
            property var bar: null
            property var settings: ({})
            property bool updateAvailable: false
            property int clicks: 0
            visible: updateAvailable
            implicitWidth: 30
            implicitHeight: 44
            Component.onCompleted: tests.instances++
            Item {
                property Component iconComponent: null
                property bool labelVisible: false
                property string text: "\uf021"
                property string fontFamily: "monospace"
                property string tooltipText: "Pending updates"
                property color foreground: "white"
                property color activeColor: "red"
                property bool active: false
                property bool useActiveColor: false
                property real textRotation: 0
                function triggerPress(button) {
                    native.clicks++;
                }
            }
        }
    }
    HostedBarWidget {
        id: shared
        moduleName: "omarchy.system-update"
        registry: registry
        bar: fakeBar
        showVisual: true
        opacity: 0
    }
    NativeWidget {
        id: first
        x: 10
        y: 10
        moduleName: "omarchy.system-update"
        registry: registry
        sharedHost: shared
        bar: fakeBar
    }
    NativeWidget {
        id: second
        x: 100
        y: 10
        moduleName: "omarchy.system-update"
        registry: registry
        sharedHost: shared
        bar: fakeBar
    }
    function init() {
        registry.widgets = {};
        tryCompare(shared, "available", false);
        instances = 0;
        registry.widgets = {
            "omarchy.system-update": {
                component: nativeComponent,
                metadata: {}
            }
        };
        tryCompare(shared, "available", true);
    }
    function test_oneProviderDrivesBothIndicatorsAndClicks() {
        compare(instances, 1);
        compare(first.width, 0);
        compare(second.width, 0);
        shared.hostItem.updateAvailable = true;
        tryCompare(first, "width", 30);
        tryCompare(second, "width", 30);
        verify(first.normalizeGlyph && second.normalizeGlyph);
        compare(first.nativeHintTarget, second.nativeHintTarget);
        waitForRendering(first);
        mouseClick(first, 15, 16);
        mouseClick(second, 15, 16);
        compare(shared.hostItem.clicks, 2);
        shared.hostItem.updateAvailable = false;
        tryCompare(first, "width", 0);
        tryCompare(second, "width", 0);
        compare(instances, 1);
    }
    function test_lateMonitorUsesExistingStateAndRemovalKeepsPeer() {
        shared.hostItem.updateAvailable = true;
        const component = Qt.createComponent("../../qml/components/NativeWidget.qml");
        compare(component.status, Component.Ready);
        const third = component.createObject(tests, {
            moduleName: "omarchy.system-update",
            registry: registry,
            sharedHost: shared,
            bar: fakeBar
        });
        verify(third);
        tryCompare(third, "width", 30);
        compare(instances, 1);
        third.destroy();
        wait(0);
        compare(first.width, 30);
        compare(second.width, 30);
        registry.widgets = {};
        tryCompare(first, "width", 0);
        tryCompare(second, "width", 0);
    }
}
