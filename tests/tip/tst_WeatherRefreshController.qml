import QtQuick
import QtTest
import Quickshell.Networking
import "../../qml/models"

TestCase {
    id: tests
    name: "WeatherWakeRefresh"

    QtObject {
        id: weather
        property int refreshes: 0
        function refresh() {
            refreshes++;
        }
    }
    QtObject {
        id: secondWeather
        property int refreshes: 0
        function refresh() {
            refreshes++;
        }
    }
    QtObject {
        id: fakeBar
        property var items: []
        function moduleWidgets(name) {
            if (name !== "omarchy.weather")
                throw new Error("Unexpected widget refresh target");
            return items;
        }
    }
    Component {
        id: factory
        WeatherRefreshController {
            bar: fakeBar
        }
    }
    function init() {
        Networking.devices = {
            values: []
        };
        weather.refreshes = 0;
        secondWeather.refreshes = 0;
        fakeBar.items = [weather];
    }
    QtObject {
        id: device
        property bool connected: false
    }
    function test_nativeNetworkDeviceChangeTriggersRefresh() {
        device.connected = false;
        Networking.devices = {
            values: [device]
        };
        const object = createTemporaryObject(factory, tests);
        object.refreshDelay.interval = 20;
        compare(object.networkAvailable, false);
        device.connected = true;
        tryCompare(weather, "refreshes", 1);
    }
    function controller(online) {
        const object = createTemporaryObject(factory, tests, {
            networkAvailable: online
        });
        object.refreshDelay.interval = 20;
        return object;
    }
    function wake(object) {
        object.sleepEvents.stdout.read("   boolean true");
        object.sleepEvents.stdout.read("signal time=1 sender=:1.4 -> destination=(null destination)");
        object.sleepEvents.stdout.read("   boolean false");
    }
    function test_wakeRefreshesBothMonitorWidgetsWithoutOpeningPanels() {
        fakeBar.items = [weather, secondWeather];
        const object = controller(true);
        wake(object);
        tryCompare(weather, "refreshes", 1);
        compare(secondWeather.refreshes, 1);
        wait(60);
        compare(weather.refreshes, 1);
    }
    function test_wakeWaitsForNetworkAndReconnectRefreshesAgain() {
        const object = controller(false);
        wake(object);
        wait(50);
        compare(weather.refreshes, 0);
        verify(object.pending);
        object.networkAvailable = true;
        tryCompare(weather, "refreshes", 1);
        object.networkAvailable = false;
        object.networkAvailable = true;
        tryCompare(weather, "refreshes", 2);
    }
    function test_sleepCancelsQueuedRefreshAndIgnoresOtherLines() {
        const object = controller(true);
        wake(object);
        object.sleepEvents.stdout.read("boolean true");
        object.sleepEvents.stdout.read("false");
        object.sleepEvents.stdout.read("NameAcquired");
        wait(50);
        compare(weather.refreshes, 0);
        verify(object.sleeping);
        object.networkAvailable = false;
        object.networkAvailable = true;
        wait(50);
        compare(weather.refreshes, 0);
        object.sleepEvents.stdout.read("boolean false");
        tryCompare(weather, "refreshes", 1);
    }
    function test_burstCoalescesAndRemovedWidgetsAreNotRefreshed() {
        fakeBar.items = [weather, secondWeather];
        const object = controller(true);
        wake(object);
        wake(object);
        fakeBar.items = [secondWeather];
        tryCompare(secondWeather, "refreshes", 1);
        compare(weather.refreshes, 0);
        fakeBar.items = [];
        verify(!object.sleepEvents.running);
        verify(!object.pending);
        verify(!object.refreshDelay.running);
    }
    function test_failedMonitorReconnectsOnlyWhileConfigured() {
        const object = controller(true);
        object.sleepEvents.running = false;
        object.sleepEvents.exited(1);
        verify(object.reconnect.running);
        fakeBar.items = [];
        verify(!object.reconnect.running);
        object.sleepEvents.exited(1);
        verify(!object.reconnect.running);
    }
}
