pragma ComponentBehavior: Bound

import QtQuick
import "../models"

Item {
    id: root

    property var bar: null
    property var barWidgetRegistry: null
    property var barConfig: ({})
    property string screenName: ""
    property real uiScale: 1
    property real rightHitPadding: 0
    property bool compact: false
    property bool active: true
    property int itemRevision: 0
    readonly property var tray: itemFor("omarchy.tray")
    readonly property var clock: itemFor("omarchy.clock")
    readonly property var dropbox: itemFor("omarchy.dropbox")
    readonly property bool excludeDropbox: !!dropbox && dropbox.available
    readonly property int visibleControlCount: {
        itemRevision;
        let count = 0;
        for (let index = 0; index < slots.count; index++) {
            const slot = slots.itemAt(index);
            if (slot && slot.widget.width > 0 && slot.widgetId !== "omarchy.tray")
                count++;
        }
        return count;
    }

    function slotFor(id) {
        itemRevision;
        for (let index = 0; index < slots.count; index++) {
            const slot = slots.itemAt(index);
            if (slot && slot.widgetId === id)
                return slot.widget;
        }
        return null;
    }

    function itemFor(id) {
        const slot = slotFor(id);
        return slot ? slot.item : null;
    }

    function activateTarget(id, button) {
        const slot = slotFor(id);
        return !!slot && slot.visible && slot.width > 0 && slot.activate(button);
    }

    function targetState(id) {
        const slot = slotFor(id);
        return slot ? slot.nativeState() : {
            present: false,
            configured: false,
            visible: false
        };
    }

    function widgetState() {
        const result = [];
        for (let index = 0; index < slots.count; index++) {
            const slot = slots.itemAt(index);
            if (slot)
                result.push({
                    id: slot.widgetId,
                    section: slot.section,
                    state: slot.widget.nativeState()
                });
        }
        return result;
    }

    implicitWidth: statusRow.implicitWidth
    implicitHeight: statusRow.implicitHeight

    StatusWidgetModel {
        id: widgetModel
        config: root.active ? root.barConfig : ({})
        registry: root.barWidgetRegistry
    }

    Row {
        id: statusRow
        anchors.fill: parent

        Repeater {
            id: slots
            model: widgetModel.model
            onItemAdded: root.itemRevision++
            onItemRemoved: root.itemRevision++

            delegate: Item {
                id: slot
                required property int index
                required property string widgetId
                required property string section
                required property string presentation
                required property string settingsJson
                property alias widget: widget
                readonly property real sectionGap: {
                    widgetModel.revision;
                    root.itemRevision;
                    for (let previous = index - 1; previous >= 0; previous--) {
                        const sibling = slots.itemAt(previous);
                        if (sibling && sibling.widget.width > 0)
                            return sibling.section !== section ? root.uiScale * 18 : 0;
                    }
                    return 0;
                }
                readonly property bool lastVisible: {
                    root.itemRevision;
                    for (let next = index + 1; next < slots.count; next++) {
                        const sibling = slots.itemAt(next);
                        if (sibling && sibling.widget.width > 0)
                            return false;
                    }
                    return true;
                }

                width: widget.width > 0 ? sectionGap + widget.width : 0
                height: widget.height
                anchors.verticalCenter: parent.verticalCenter

                StatusWidgetSlot {
                    id: widget
                    x: slot.sectionGap
                    anchors.verticalCenter: parent.verticalCenter
                    widgetId: slot.widgetId
                    presentation: slot.presentation
                    settings: JSON.parse(slot.settingsJson)
                    registry: root.barWidgetRegistry
                    bar: root.bar
                    uiScale: root.uiScale
                    screenName: root.screenName
                    compact: root.compact
                    excludeDropbox: root.excludeDropbox
                    rightHitPadding: slot.lastVisible ? root.rightHitPadding : 0
                    onItemChanged: root.itemRevision++
                }
            }
        }
    }
}
