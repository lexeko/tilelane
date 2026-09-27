import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase
    name: "NativeWidget"
    when: windowShown
    visible: true
    width: 400
    height: 100

    QtObject {
        id: registry
        property var widgets: ({})
    }

    QtObject {
        id: fakeBar
        property real barHeight: 44
        property var hosts: []
        property var clickTargets: []
        function registerWidgetHost(host) {
            hosts = hosts.concat([host]);
        }
        function unregisterWidgetHost(host) {
            hosts = hosts.filter(function (item) {
                return item !== host;
            });
        }
        function registerClickTarget(target) {
            if (clickTargets.indexOf(target) < 0)
                clickTargets = clickTargets.concat([target]);
        }
        function unregisterClickTarget(target) {
            clickTargets = clickTargets.filter(function (item) {
                return item !== target;
            });
        }
        function showTooltip(target, text) {
        }
        function hideTooltip(target) {
        }
    }

    Component {
        id: pluginComponent
        Item {
            id: plugin
            property var bar: null
            property var settings: ({})
            property string moduleName: ""
            property bool opened: false
            property int clicks: 0
            property int secondClicks: 0
            property int wheels: 0
            property int lastButton: -1
            implicitWidth: settings.wide ? 180 : 120
            implicitHeight: 32
            function open() {
                opened = true;
            }
            function close() {
                opened = false;
            }
            function toggle() {
                opened = !opened;
            }
            function triggerPress(button) {
                lastButton = button;
                clicks++;
                if (button === Qt.LeftButton)
                    toggle();
            }
            MouseArea {
                width: parent.width / 2
                height: parent.height
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: function (mouse) {
                    plugin.triggerPress(mouse.button);
                }
                onWheel: plugin.wheels++
            }
            MouseArea {
                x: parent.width / 2
                width: parent.width / 2
                height: parent.height
                onClicked: plugin.secondClicks++
            }
        }
    }

    NativeWidget {
        id: widget
        x: 10
        y: 10
        moduleName: "example.unfamiliar"
        registry: registry
        bar: fakeBar
    }

    function init() {
        registry.widgets = {
            "example.unfamiliar": {
                component: pluginComponent,
                metadata: {
                    displayName: "Example"
                }
            }
        };
        widget.settings = {};
        tryCompare(widget, "available", true);
    }

    function cleanup() {
        registry.widgets = {};
        tryCompare(widget, "available", false);
    }

    function plugin() {
        return fakeBar.hosts[0].hostItem;
    }

    function test_unfamiliarWidgetLoadsAndReceivesIdentityAndSettings() {
        compare(widget.width, 120);
        compare(plugin().moduleName, "example.unfamiliar");
        compare(plugin().bar, fakeBar);
        const original = plugin();
        original.open();
        widget.settings = {
            wide: true
        };
        compare(plugin(), original);
        compare(widget.width, 180);
        verify(widget.indicatorVisible);
        original.close();
        verify(!widget.indicatorVisible);
    }

    function test_nativeControlsKeepMouseWheelAndSecondaryButtons() {
        const item = plugin();
        mouseClick(widget, 20, 16, Qt.RightButton);
        compare(item.lastButton, Qt.RightButton);
        compare(item.clicks, 1);
        mouseClick(widget, 90, 16, Qt.LeftButton);
        compare(item.secondClicks, 1);
        compare(item.clicks, 1);
        mouseWheel(widget, 20, 16, 0, 120);
        compare(item.wheels, 1);
        verify(!widget.activeFocus);
        mouseClick(widget, 20, 16, Qt.LeftButton);
        verify(widget.opened);
        verify(widget.indicatorVisible);
        item.close();
        verify(!widget.indicatorVisible);
    }

    function test_disableUnloadsAndReenableLoadsReplacement() {
        const original = plugin();
        original.open();
        registry.widgets = {};
        tryCompare(widget, "width", 0);
        verify(!widget.opened);
        registry.widgets = {
            "example.unfamiliar": {
                component: pluginComponent,
                metadata: {}
            }
        };
        tryCompare(widget, "available", true);
        verify(!widget.opened);
        compare(plugin().clicks, 0);
    }
}
