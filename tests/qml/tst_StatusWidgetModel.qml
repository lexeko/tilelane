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
        compare(ids(), ["test.second", "test.first", "omarchy.tray"]);
        compare(JSON.parse(widgets.model.get(1).settingsJson).label, "Custom");
        compare(widgets.model.get(1).presentation, "native");
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
        compare(delegates.itemAt(0), first);
        verify(first.panelOpen);
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
