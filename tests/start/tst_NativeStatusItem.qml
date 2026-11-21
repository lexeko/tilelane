import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase

    name: "NativeStatusItem"
    when: windowShown
    visible: true
    width: 200
    height: 80
    property int weatherLoads: 0
    property int weatherRefreshes: 0
    property string lastRunCommand: ""

    QtObject {
        id: widgetRegistry

        property var widgets: ({})
    }

    QtObject {
        id: fakeBar

        property real barHeight: 44
        property color statusHoverFill: "#334455"
        property var clickTargets: []
        property var widgetHosts: []

        function registerClickTarget(target) {
            if (clickTargets.indexOf(target) === -1)
                clickTargets = clickTargets.concat([target]);
        }
        function unregisterClickTarget(target) {
            clickTargets = clickTargets.filter(item => item !== target);
        }
        function registerWidgetHost(host) {
            if (widgetHosts.indexOf(host) === -1)
                widgetHosts = widgetHosts.concat([host]);
        }
        function unregisterWidgetHost(host) {
            widgetHosts = widgetHosts.filter(item => item !== host);
        }
        function showTooltip(target, text) {
        }
        function hideTooltip(target) {
        }
        function run(command) {
            testCase.lastRunCommand = String(command || "");
        }
    }

    Component {
        id: fakeWeatherWidget

        Item {
            id: weatherRoot

            property string moduleName: "omarchy.weather"
            property string label: "\ue30d"
            property bool opened: false

            Component.onCompleted: testCase.weatherLoads++

            function open() {
                opened = true;
            }
            function close() {
                opened = false;
            }
            function togglePanel() {
                opened = !opened;
            }
            function refresh() {
                testCase.weatherRefreshes++;
            }
        }
    }

    Component {
        id: fakeKeyboardWidget

        Item {
            property string inputLabel: "EN"
            property bool multipleInputs: true
            property int cycles: 0

            function cycleLayout() {
                cycles++;
            }
        }
    }

    Component {
        id: weatherStatusFactory

        NativeStatusItem {
            moduleName: "omarchy.weather"
            presentation: "icon"
            registry: widgetRegistry
            bar: fakeBar
        }
    }

    Component {
        id: keyboardStatusFactory

        NativeStatusItem {
            moduleName: "omarchy.keyboard-layout"
            presentation: "text"
            registry: widgetRegistry
            bar: fakeBar
        }
    }

    function init() {
        weatherLoads = 0;
        weatherRefreshes = 0;
        lastRunCommand = "";
        widgetRegistry.widgets = ({
                "omarchy.weather": {
                    "component": fakeWeatherWidget,
                    "metadata": ({})
                },
                "omarchy.keyboard-layout": {
                    "component": fakeKeyboardWidget,
                    "metadata": ({})
                }
            });
    }

    function test_weatherLoadsLazilyAndUnloadsAfterClose() {
        const item = createTemporaryObject(weatherStatusFactory, testCase);
        verify(item.visible);
        compare(item.statusText, "\ue302");
        compare(weatherLoads, 0);
        compare(item.nativeState().available, false);

        // Right-click uses the notification command without loading the panel.
        verify(item.activate(Qt.RightButton));
        compare(lastRunCommand, "omarchy-notification-send \"$(omarchy-weather-status)\"");
        compare(weatherLoads, 0);
        compare(item.nativeState().available, false);

        // Middle-click while unloaded is a safe no-op.
        verify(!item.activate(Qt.MiddleButton));
        compare(weatherLoads, 0);

        // Left-click loads the native widget on demand and opens its panel.
        verify(item.activate(Qt.LeftButton));
        tryCompare(item, "opened", true);
        compare(weatherLoads, 1);
        compare(item.nativeState().available, true);
        tryCompare(item, "statusText", "\ue30d");

        // Middle-click refreshes while loaded.
        verify(item.activate(Qt.MiddleButton));
        compare(weatherRefreshes, 1);

        // Closing unloads the native widget again and returns to the idle glyph.
        verify(item.activate(Qt.LeftButton));
        tryCompare(item, "opened", false);
        tryVerify(function () {
            return item.nativeState().available === false;
        }, 1000);
        compare(item.statusText, "\ue302");
        verify(item.visible);
    }

    function test_keyboardLayoutStaysPersistent() {
        const item = createTemporaryObject(keyboardStatusFactory, testCase);
        tryCompare(item, "visible", true);
        compare(item.statusText, "EN");
        compare(item.nativeState().available, true);
    }
}
