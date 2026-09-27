import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase

    name: "HostedBarWidget"
    when: windowShown

    QtObject {
        id: registry

        property var widgets: ({})
    }

    QtObject {
        id: fakeBar

        property var clickTargets: []
        property var widgetHosts: []

        function registerWidgetHost(host) {
            if (widgetHosts.indexOf(host) === -1)
                widgetHosts = widgetHosts.concat([host]);
        }

        function unregisterWidgetHost(host) {
            widgetHosts = widgetHosts.filter(function (item) {
                return item !== host;
            });
        }

        function registerClickTarget(target) {
            if (clickTargets.indexOf(target) === -1)
                clickTargets = clickTargets.concat([target]);
        }

        function unregisterClickTarget(target) {
            clickTargets = clickTargets.filter(function (item) {
                return item !== target;
            });
        }
    }

    Item {
        id: visibleControl

        property int lastButton: -1

        function triggerPress(button) {
            lastButton = button;
        }
    }

    Component {
        id: fakeWidget

        Item {
            property var bar: null
            property var settings: ({})
            property bool controllerOpen: false
            readonly property bool opened: controllerOpen
            property alias panel: panel

            Item {
                id: panel

                property bool centerOnBar: true
            }

            function toggle() {
                controllerOpen = !controllerOpen;
            }

            function open() {
                controllerOpen = true;
            }

            function close() {
                controllerOpen = false;
            }
        }
    }

    HostedBarWidget {
        id: host

        moduleName: "test.widget"
        registry: registry
        lazy: true
    }

    Component {
        id: buttonWidget

        Item {
            id: widget

            property var bar: null
            property var settings: ({})
            property bool opened: false
            property int lastButton: -1
            property int pressCount: 0
            property int fallbackCount: 0
            property alias button: nativeButton

            onBarChanged: if (bar)
                bar.registerClickTarget(nativeButton)

            function toggle() {
                fallbackCount++;
                opened = !opened;
            }

            Item {
                Item {
                    id: nativeButton

                    function triggerPress(button) {
                        widget.lastButton = button;
                        widget.pressCount++;
                        if (button === Qt.LeftButton)
                            widget.opened = !widget.opened;
                    }
                }
            }
        }
    }

    function init() {
        registry.widgets = ({
                "test.widget": {
                    "component": fakeWidget,
                    "metadata": ({})
                }
            });
        host.loadRequested = false;
        tryCompare(host, "available", false);
    }

    function cleanup() {
        registry.widgets = ({});
        tryCompare(host, "available", false);
        host.clickTarget = null;
        host.bar = null;
        fakeBar.clickTargets = [];
    }

    function test_lazyWidgetLoadsOnFirstAction() {
        verify(host.trigger(Qt.LeftButton));
        tryCompare(host, "available", true);
        tryCompare(host, "opened", true);
        verify(host.trigger(Qt.LeftButton));
        tryCompare(host, "opened", false);
        tryCompare(host, "available", false, 1000);
    }

    function test_shortcutCanSummonUnloadedPanelAndReopenAfterUnload() {
        host.bar = fakeBar;
        compare(fakeBar.widgetHosts.length, 1);
        compare(fakeBar.widgetHosts[0], host);
        compare(host.available, false);
        for (let cycle = 0; cycle < 2; cycle++) {
            verify(host.open());
            tryCompare(host, "opened", true);
            verify(host.open());
            compare(host.opened, true);
            verify(host.close());
            tryCompare(host, "available", false, 1000);
            compare(fakeBar.widgetHosts.length, 1);
        }
        host.bar = null;
        compare(fakeBar.widgetHosts.length, 0);
    }

    function test_hideCancelsPendingShortcutOpen() {
        verify(host.open());
        verify(host.close());
        compare(host.pendingOpen, false);
        tryCompare(host, "available", false, 1000);
        compare(host.opened, false);
    }

    function test_shortcutCannotLoadRemovedWidget() {
        registry.widgets = ({});
        verify(!host.open());
        compare(host.pendingOpen, false);
        compare(host.available, false);
    }

    function test_registryRemovalUnloadsWidget() {
        verify(host.trigger(Qt.LeftButton));
        tryCompare(host, "available", true);
        registry.widgets = ({});
        tryCompare(host, "available", false);
        compare(host.loadRequested, false);
        verify(!host.trigger(Qt.LeftButton));
    }

    function test_externalPanelCloseUnloadsWidget() {
        verify(host.trigger(Qt.LeftButton));
        tryCompare(host, "opened", true);
        host.hostItem.controllerOpen = false;
        tryCompare(host, "opened", false);
        tryCompare(host, "available", false, 1000);
    }

    function test_capabilityStateOmitsInternalComponentIdentity() {
        const state = host.capabilityState();
        verify(state.hasEntry);
        verify(state.hasComponent);
        verify(!("componentType" in state));
        verify(!("sourceDir" in state));
    }

    function test_panelCanAlignToHostedButton() {
        host.alignPanelToHost = true;
        verify(host.trigger(Qt.LeftButton));
        tryCompare(host, "available", true);
        tryCompare(host.hostItem.panel, "centerOnBar", false);
        host.alignPanelToHost = false;
    }

    function test_nativeButtonReceivesOriginalMouseButtonAfterLazyLoad() {
        registry.widgets = ({
                "test.widget": {
                    "component": buttonWidget,
                    "metadata": ({})
                }
            });
        verify(host.trigger(Qt.RightButton));
        tryCompare(host, "available", true);
        tryCompare(host.hostItem, "pressCount", 1);
        compare(host.hostItem.lastButton, Qt.RightButton);
        compare(host.hostItem.fallbackCount, 0);
        compare(host.opened, false);
        verify(host.trigger(Qt.MiddleButton));
        compare(host.hostItem.lastButton, Qt.MiddleButton);
        compare(host.hostItem.pressCount, 2);
        compare(host.opened, false);
        verify(host.trigger(Qt.LeftButton));
        compare(host.hostItem.lastButton, Qt.LeftButton);
        compare(host.hostItem.pressCount, 3);
        compare(host.opened, true);
        compare(host.hostItem.fallbackCount, 0);
    }

    function test_secondaryButtonsDoNotFallBackToPrimaryAction() {
        verify(host.trigger(Qt.LeftButton));
        tryCompare(host, "opened", true);
        verify(!host.trigger(Qt.RightButton));
        verify(!host.trigger(Qt.MiddleButton));
        compare(host.opened, true);
    }

    function test_visibleControlKeepsForwardedClicksAfterNativeWidgetLoads() {
        host.bar = fakeBar;
        host.clickTarget = visibleControl;
        fakeBar.registerClickTarget(visibleControl);
        registry.widgets = ({
                "test.widget": {
                    "component": buttonWidget,
                    "metadata": ({})
                }
            });
        verify(host.trigger(Qt.LeftButton));
        tryCompare(host, "opened", true);
        compare(fakeBar.clickTargets.length, 1);
        compare(fakeBar.clickTargets[0], visibleControl);
        verify(fakeBar.clickTargets.indexOf(host.hostItem.button) === -1);
        fakeBar.clickTargets[0].triggerPress(Qt.RightButton);
        compare(visibleControl.lastButton, Qt.RightButton);
        compare(host.hostItem.pressCount, 1);
    }
}
