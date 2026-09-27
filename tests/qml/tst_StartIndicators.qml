import QtQuick
import QtTest
import "../../qml/components"
import "../../qml/IndicatorLogic.js" as IndicatorLogic

TestCase {
    id: testCase
    name: "StartIndicators"
    when: windowShown
    visible: true
    width: 400
    height: 100
    readonly property string firstHint: indicators.hintFor(0)

    QtObject {
        id: registry
        property var widgets: ({})
    }

    QtObject {
        id: bar
        property var hosted: []
        function registerHostedWidget(item, moduleName) {
            hosted = hosted.concat([item]);
        }
        function unregisterHostedWidget(item) {
            hosted = hosted.filter(function (candidate) {
                return candidate !== item;
            });
        }
    }

    StartIndicators {
        id: indicators
        registry: registry
        bar: bar
        width: implicitWidth
        height: implicitHeight
    }

    function init() {
        registry.widgets = {
            "omarchy.indicators": {
                metadata: {
                    sourceDir: String(Qt.resolvedUrl("../fixtures/indicators")).replace(/^file:\/\//, ""),
                    schema: [
                        {
                            key: "items",
                            options: [
                                {
                                    value: "Example"
                                },
                                {
                                    value: "Future"
                                }
                            ]
                        }
                    ]
                }
            }
        };
        indicators.settings = {};
        tryCompare(indicators, "count", 2);
        tryVerify(function () {
            return indicators.slotAt(0).nativeItem && indicators.slotAt(1).nativeItem;
        });
        indicators.slotAt(0).nativeItem.active = false;
        indicators.slotAt(1).nativeItem.active = false;
        wait(0);
    }

    function test_nativeClickUpdatesStateWithoutMovingSlots() {
        const first = indicators.slotAt(0);
        const second = indicators.slotAt(1);
        waitForRendering(indicators);
        const positions = [first.x, second.x, indicators.implicitWidth];
        mouseClick(first.nativeItem, 10, 10);
        verify(first.nativeItem.active);
        compare([first.x, second.x, indicators.implicitWidth], positions);
        mouseClick(second.nativeItem, 10, 10);
        verify(second.nativeItem.active);
        compare([first.x, second.x, indicators.implicitWidth], positions);
        mouseClick(first.nativeItem, 10, 10);
        verify(!first.nativeItem.active);
        compare([first.x, second.x, indicators.implicitWidth], positions);
        compare(first.nativeItem.indicatorBlock, "single");
        compare(first.nativeItem.activeOverride, null);
        verify(first.nativeItem.indicatorHost.revealInactiveIndicators);
    }

    function test_configReordersAndUpdatesExistingNativeItems() {
        const first = indicators.slotAt(0).nativeItem;
        const second = indicators.slotAt(1).nativeItem;
        indicators.settings = {
            items: ["Future",
                {
                    id: "Example",
                    slotWidth: 56
                }
            ]
        };
        tryCompare(indicators.slotAt(1), "width", 56);
        compare(indicators.slotAt(0).nativeItem, second);
        compare(firstHint, "Future");
        compare(indicators.slotAt(1).nativeItem, first);
        compare(indicators.slotAt(1).nativeItem.settings.slotWidth, 56);
        compare(indicators.slotAt(1).nativeItem.moduleName, "Example");
        compare(indicators.slotAt(1).nativeItem.bar, bar);
        indicators.settings = {
            items: ["Future"]
        };
        tryCompare(indicators, "count", 1);
        compare(indicators.slotAt(0).nativeItem, second);
        indicators.settings = {
            items: ["Future", "Example"]
        };
        tryCompare(indicators, "count", 2);
        tryVerify(function () {
            return indicators.slotAt(1).nativeItem;
        });
    }

    function test_metadataChangesAndRefreshStayDynamic() {
        indicators.settings = {};
        const first = indicators.slotAt(0).nativeItem;
        const refreshed = first.refreshes;
        indicators.refresh();
        compare(first.refreshes, refreshed + 1);
        verify(bar.hosted.indexOf(indicators) >= 0);
        const meta = registry.widgets["omarchy.indicators"].metadata;
        registry.widgets = {
            "omarchy.indicators": {
                metadata: {
                    sourceDir: meta.sourceDir,
                    schema: [
                        {
                            key: "items",
                            options: [
                                {
                                    value: "Future"
                                }
                            ]
                        }
                    ]
                }
            }
        };
        tryCompare(indicators, "count", 1);
        compare(indicators.slotAt(0).indicatorId, "Future");
        registry.widgets = {};
        tryCompare(indicators, "count", 0);
    }

    function test_entrySettingsAliasesAndUnsafeIds() {
        const records = IndicatorLogic.records({
            indicators: ["Future",
                {
                    id: "Example",
                    custom: true
                },
                "../Outside", "bad/name", "file:bad", "", null]
        }, {});
        compare(records.map(function (entry) {
            return entry.indicatorId;
        }), ["Future", "Example"]);
        compare(JSON.parse(records[1].settingsJson), {
            custom: true
        });
        compare(IndicatorLogic.records({
            items: ["Example"],
            indicators: ["Future"]
        }, {})[0].indicatorId, "Example");
        compare(IndicatorLogic.records({}, {}), []);
    }
}
