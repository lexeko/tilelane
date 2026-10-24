pragma ComponentBehavior: Bound

import QtQuick
import "../IndicatorLogic.js" as IndicatorLogic
import "../HintLogic.js" as HintLogic

Item {
    id: root

    property var registry: null
    property var bar: null
    property var settings: ({})
    property real targetGlyphSize: 0
    property var registeredBar: null
    property int revision: 0
    readonly property var entry: registry && registry.widgets ? registry.widgets["omarchy.indicators"] : null
    readonly property var metadata: entry && entry.metadata ? entry.metadata : ({})
    readonly property var configuredEntries: entry ? IndicatorLogic.records(settings, metadata) : []
    readonly property bool revealInactiveIndicators: true
    readonly property int count: slots.count

    signal refreshRequested

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function refresh() {
        refreshRequested();
    }

    function syncRegistration() {
        if (registeredBar === bar)
            return;
        if (registeredBar)
            registeredBar.unregisterHostedWidget(root);
        registeredBar = bar;
        if (registeredBar)
            registeredBar.registerHostedWidget(root, "omarchy.indicators");
    }

    function syncEntries() {
        for (let index = 0; index < configuredEntries.length; index++) {
            const desired = configuredEntries[index];
            let found = -1;
            for (let current = index; current < entries.count; current++) {
                if (entries.get(current).key === desired.key) {
                    found = current;
                    break;
                }
            }
            if (found < 0)
                entries.insert(index, desired);
            else {
                if (found !== index)
                    entries.move(found, index, 1);
                if (entries.get(index).settingsJson !== desired.settingsJson)
                    entries.setProperty(index, "settingsJson", desired.settingsJson);
            }
        }
        while (entries.count > configuredEntries.length)
            entries.remove(entries.count - 1);
        revision++;
    }

    function slotAt(index) {
        revision;
        return slots.itemAt(index);
    }

    function hintFor(index) {
        const slot = slotAt(index);
        return slot && slot.shown ? HintLogic.startIndicator(slot.indicatorId, slot.nativeItem.active === true) : "";
    }

    function snapshot() {
        const result = [];
        for (let index = 0; index < slots.count; index++) {
            const slot = slotAt(index);
            result.push({
                id: slot.indicatorId,
                active: !!slot.nativeItem && slot.nativeItem.active === true,
                available: !!slot.nativeItem,
                x: slot.x,
                width: slot.width
            });
        }
        return result;
    }

    onConfiguredEntriesChanged: syncEntries()
    onBarChanged: syncRegistration()
    Component.onCompleted: {
        syncEntries();
        syncRegistration();
    }
    Component.onDestruction: {
        if (registeredBar)
            registeredBar.unregisterHostedWidget(root);
    }

    ListModel {
        id: entries
    }

    Row {
        id: row

        Repeater {
            id: slots
            model: entries

            delegate: Item {
                id: slot

                required property string indicatorId
                required property string settingsJson
                readonly property var nativeItem: source.item
                readonly property var indicatorSettings: JSON.parse(settingsJson)
                readonly property bool shown: !!nativeItem && nativeItem.visible && nativeItem.opacity > 0 && nativeItem.hasVisualContent !== false
                readonly property real visualScale: {
                    const fontSize = nativeItem ? Number(nativeItem.fontSize) : 0;
                    if (root.targetGlyphSize <= 0 || !isFinite(fontSize) || fontSize <= 0)
                        return 1;
                    return Math.max(0.5, Math.min(2, root.targetGlyphSize / fontSize));
                }
                width: shown ? nativeItem.implicitWidth * visualScale : 0
                height: shown ? nativeItem.implicitHeight * visualScale : 0

                Loader {
                    id: source
                    width: slot.nativeItem ? slot.nativeItem.implicitWidth : 0
                    height: slot.nativeItem ? slot.nativeItem.implicitHeight : 0
                    anchors.centerIn: parent
                    scale: slot.visualScale
                    transformOrigin: Item.Center
                    source: root.metadata.sourceDir ? "file://" + root.metadata.sourceDir + "/../indicators/" + slot.indicatorId + ".qml" : ""
                    onLoaded: {
                        const target = item;
                        if ("bar" in target)
                            target.bar = Qt.binding(function () {
                                return root.bar;
                            });
                        if ("settings" in target)
                            target.settings = Qt.binding(function () {
                                return slot.indicatorSettings;
                            });
                        if ("moduleName" in target)
                            target.moduleName = slot.indicatorId;
                        if ("indicatorBlock" in target)
                            target.indicatorBlock = "single";
                        if ("indicatorHost" in target)
                            target.indicatorHost = root;
                        if ("activeOverride" in target)
                            target.activeOverride = null;
                        Qt.callLater(root.refresh);
                    }
                }
            }
        }
    }
}
