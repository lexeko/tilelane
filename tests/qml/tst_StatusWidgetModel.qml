import QtQuick
import QtTest
import "../../qml/models"
import "../../qml/StatusWidgetLogic.js" as Logic

TestCase {
    id: testCase
    name: "StatusWidgetModel"

    QtObject {
        id: registry
        property var widgets: ({})
    }

    StatusWidgetModel {
        id: widgets
        registry: registry
    }

    Repeater {
        id: delegates
        model: widgets.model
        delegate: Item {
            required property string widgetId
            required property string settingsJson
            property bool panelOpen: false
        }
    }

    function init() {
        widgets.config = {};
        registry.widgets = {
            "test.first": {
                metadata: {
                    defaults: {
                        label: "Default"
                    }
                }
            },
            "test.second": {
                metadata: {}
            },
            "omarchy.menu": {},
            "omarchy.workspaces": {},
            "omarchy.indicators": {},
            "omarchy.tray": {}
        };
    }

    function ids() {
        const result = [];
        for (let i = 0; i < widgets.model.count; i++)
            result.push(widgets.model.get(i).widgetId);
        return result;
    }

    function test_configuredOrderAndCoreSurfaces() {
        widgets.config = {
            layout: {
                left: ["omarchy.menu", "omarchy.workspaces", "test.second"],
                center: ["omarchy.indicators",
                    {
                        id: "test.first",
                        label: "Custom"
                    }
                ],
                right: ["omarchy.tray", "not.installed", "test.second"]
            }
        };
        compare(ids(), ["test.second", "omarchy.tray", "test.first"]);
        compare(JSON.parse(widgets.model.get(2).settingsJson).label, "Custom");
        compare(widgets.model.get(2).presentation, "native");
    }

    function test_reorderingAndSettingsKeepInstancesAndOpenPanels() {
        widgets.config = {
            layout: {
                right: ["test.first", "test.second"]
            }
        };
        compare(delegates.count, 2);
        const first = delegates.itemAt(0);
        first.panelOpen = true;
        widgets.config = {
            layout: {
                right: ["test.second",
                    {
                        id: "test.first",
                        label: "Changed"
                    }
                ]
            }
        };
        compare(delegates.itemAt(1), first);
        verify(first.panelOpen);
        compare(JSON.parse(first.settingsJson).label, "Changed");
        widgets.config = {
            layout: {
                center: ["test.first"],
                right: ["test.second"]
            }
        };
        compare(delegates.itemAt(1), first);
        verify(first.panelOpen);
    }

    function test_clockFollowsInformationGroupWithoutReversingItems() {
        registry.widgets = {
            "omarchy.clock": {},
            "omarchy.keyboard-layout": {},
            "omarchy.weather": {},
            "omarchy.system-update": {},
            "omarchy.tray": {},
            "omarchy.power": {}
        };
        widgets.config = {
            layout: {
                center: ["omarchy.clock", "omarchy.keyboard-layout", "omarchy.weather", "omarchy.system-update"],
                right: ["omarchy.tray", "omarchy.power"]
            }
        };
        compare(ids(), ["omarchy.tray", "omarchy.power", "omarchy.keyboard-layout", "omarchy.weather", "omarchy.system-update", "omarchy.clock"]);
        compare(widgets.model.get(0).groupName, "controls");
        compare(widgets.model.get(2).groupName, "information");
        compare(widgets.model.get(5).groupName, "clock");
    }

    function test_stockOmarchyLayoutLoadsCenterEndAndKeepsClockLast() {
        registry.widgets = {
            "omarchy.menu": {},
            "omarchy.workspaces": {},
            "omarchy.indicators": {},
            "omarchy.clock": {},
            "omarchy.elsewhen": {},
            "omarchy.weather": {},
            "omarchy.system-update": {},
            "omarchy.tray": {},
            "omarchy.keyboard-layout": {},
            "omarchy.agents": {},
            "omarchy.bluetooth": {},
            "omarchy.network": {},
            "omarchy.audio": {},
            "omarchy.monitor": {},
            "omarchy.power": {}
        };
        widgets.config = {
            layout: {
                left: [
                    {
                        id: "omarchy.menu"
                    },
                    {
                        id: "omarchy.workspaces"
                    }
                ],
                centerBegin: [
                    {
                        id: "omarchy.indicators",
                        items: ["Dnd", "NightLight"]
                    }
                ],
                center: [
                    {
                        id: "omarchy.clock",
                        format: "dddd HH:mm"
                    }
                ],
                centerEnd: [
                    {
                        id: "omarchy.elsewhen",
                        cities: ["Tokyo"]
                    },
                    {
                        id: "omarchy.weather"
                    },
                    {
                        id: "omarchy.system-update",
                        interval: 900
                    }
                ],
                right: [
                    {
                        id: "omarchy.tray"
                    },
                    {
                        id: "omarchy.keyboard-layout"
                    },
                    {
                        id: "omarchy.agents"
                    },
                    {
                        id: "omarchy.bluetooth"
                    },
                    {
                        id: "omarchy.network"
                    },
                    {
                        id: "omarchy.audio"
                    },
                    {
                        id: "omarchy.monitor"
                    },
                    {
                        id: "omarchy.power"
                    }
                ]
            }
        };
        compare(ids(), ["omarchy.tray", "omarchy.keyboard-layout", "omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.monitor", "omarchy.power", "omarchy.elsewhen", "omarchy.weather", "omarchy.system-update", "omarchy.clock"]);
        compare(widgets.model.get(0).groupName, "controls");
        compare(widgets.model.get(7).groupName, "controls");
        compare(widgets.model.get(8).groupName, "information");
        compare(widgets.model.get(9).groupName, "information");
        compare(widgets.model.get(10).groupName, "information");
        compare(widgets.model.get(11).groupName, "clock");
        compare(JSON.parse(widgets.model.get(8).settingsJson).cities, ["Tokyo"]);
        compare(JSON.parse(widgets.model.get(11).settingsJson).format, "dddd HH:mm");
        compare(Logic.widgetSettings(widgets.config, "omarchy.indicators").items, ["Dnd", "NightLight"]);
        compare(Logic.widgetSettings(widgets.config, "omarchy.system-update").interval, 900);
    }

    function test_centerSectionsOrderDeduplicateAndPreserveInstances() {
        registry.widgets = {
            "omarchy.clock": {},
            "omarchy.indicators": {},
            "test.begin": {
                metadata: {
                    defaults: {
                        label: "BeginDefault"
                    }
                }
            },
            "test.middle": {
                metadata: {}
            },
            "test.end": {
                metadata: {}
            },
            "omarchy.tray": {}
        };
        widgets.config = {
            layout: {
                centerBegin: ["omarchy.indicators",
                    {
                        id: "test.begin",
                        label: "BeginCustom"
                    }
                ],
                center: ["omarchy.clock", "test.middle"],
                centerEnd: ["test.begin", "test.end"],
                right: ["omarchy.tray"]
            }
        };
        compare(ids(), ["omarchy.tray", "test.begin", "test.middle", "test.end", "omarchy.clock"]);
        compare(widgets.model.get(0).groupName, "controls");
        compare(widgets.model.get(1).groupName, "information");
        compare(widgets.model.get(2).groupName, "information");
        compare(widgets.model.get(3).groupName, "information");
        compare(widgets.model.get(4).groupName, "clock");
        compare(JSON.parse(widgets.model.get(1).settingsJson).label, "BeginCustom");

        const beginDelegate = delegates.itemAt(1);
        beginDelegate.panelOpen = true;
        widgets.config = {
            layout: {
                centerBegin: ["omarchy.indicators"],
                center: ["omarchy.clock", "test.middle"],
                centerEnd: ["test.end", "test.begin"],
                right: ["omarchy.tray"]
            }
        };
        compare(ids(), ["omarchy.tray", "test.middle", "test.end", "test.begin", "omarchy.clock"]);
        compare(delegates.itemAt(3), beginDelegate);
        verify(beginDelegate.panelOpen);
    }

    function test_registryInstallDisableAndConfigRemoval() {
        widgets.config = {
            layout: {
                right: ["test.first", "new.plugin"]
            }
        };
        compare(ids(), ["test.first"]);
        const first = delegates.itemAt(0);
        registry.widgets = {
            "test.first": {
                metadata: {}
            },
            "new.plugin": {
                metadata: {}
            }
        };
        compare(ids(), ["test.first", "new.plugin"]);
        compare(delegates.itemAt(0), first);
        registry.widgets = {
            "new.plugin": {
                metadata: {}
            }
        };
        compare(ids(), ["new.plugin"]);
        widgets.config = {
            layout: {
                right: []
            }
        };
        compare(ids(), []);
    }

    function test_multipleInstancesOnlyWhenSupported() {
        registry.widgets = {
            "test.first": {
                metadata: {
                    allowMultiple: true
                }
            },
            "test.second": {
                metadata: {}
            }
        };
        widgets.config = {
            layout: {
                right: ["test.first", "test.first", "test.second", "test.second"]
            }
        };
        compare(ids(), ["test.first", "test.first", "test.second"]);
        verify(widgets.model.get(0).key !== widgets.model.get(1).key);
    }

    function test_manifestUsesDeclaredEntryPointAndRejectsInvalidPaths() {
        compare(Logic.manifestEntryPoint('{"entryPoints":{"barWidget":"ui/Custom.qml"}}'), "ui/Custom.qml");
        compare(Logic.manifestEntryPoint('{"entryPoints":{"panel":"Panel.qml"}}'), "");
        compare(Logic.manifestEntryPoint('{"entryPoints":{"barWidget":"../Other.qml"}}'), "");
        compare(Logic.manifestEntryPoint('{"entryPoints":{"barWidget":"%2e%2e/Other.qml"}}'), "");
        compare(Logic.manifestEntryPoint('broken JSON'), "");
    }
}
