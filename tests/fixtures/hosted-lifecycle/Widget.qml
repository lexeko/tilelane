import QtQuick

Item {
    id: root
    property var bar: null
    property var settings: ({})
    property string moduleName: ""
    property bool panelActive: true
    property int refreshCount: 0
    function refresh() {
        refreshCount++;
    }
    function inject() {
        if (nested.item) {
            nested.item.bar = bar;
            nested.item.settings = settings;
        }
    }
    onBarChanged: inject()
    onSettingsChanged: inject()
    Loader {
        id: nested
        active: root.panelActive
        source: "Panel.qml"
        onLoaded: root.inject()
    }
}
