pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../HintLogic.js" as HintLogic
import "../StartLogic.js" as StartLogic
import "../models"
import qs.Commons as Commons

PanelWindow {
    id: root

    required property var targetScreen
    required property var applicationCatalog
    required property var pinnedApplications
    property var bar: null
    property var barWidgetRegistry: null
    property bool open: false
    property bool focusPrimed: false
    property bool hoverReady: false
    property real uiScale: 1
    property real barHeight: 44
    property real reveal: open ? 1 : 0
    property var results: []
    property var openingPinnedIds: []
    property int lastSearchMs: 0
    readonly property int placeCount: placesModel.places.length
    readonly property int pinnedPlaceCount: placesModel.pinnedPlaces.length
    // Shared layout rhythm for the two columns and their headers/footers.
    readonly property real outerInset: px(24)
    readonly property real headerHeight: px(36)
    readonly property real headerGap: px(16)
    readonly property real paneGap: px(24)
    readonly property real appListInset: px(12)
    readonly property real columnInset: px(12)
    readonly property real footerGap: px(16)
    readonly property real footerHeight: px(42)
    readonly property real sectionGap: px(24)
    readonly property real rightColumnWidth: px(242)
    readonly property real appRowHeight: px(42)
    readonly property real placeRowHeight: px(38)
    readonly property real placeDividerHeight: sectionGap
    readonly property real trayIconSize: px(20) * 0.67
    readonly property real indicatorScale: trayIconSize / Math.max(1, Commons.Style.font.caption)
    readonly property int indicatorSlotCount: {
        const item = indicatorHost.hostItem;
        if (!item || !item.indicatorEntries || typeof item.indicatorEntries.length !== "number")
            return 0;
        return item.indicatorEntries.length;
    }
    readonly property var indicatorSettings: {
        const configured = bar && typeof bar.barWidgetSettings === "function" ? bar.barWidgetSettings("omarchy.indicators") : {
            "id": "omarchy.indicators"
        };
        const settings = ({});
        for (const key in configured)
            settings[key] = configured[key];
        settings.alwaysShow = true;
        return settings;
    }
    readonly property real menuWidth: Math.min(px(736), screen ? screen.width - px(24) : px(736))
    readonly property real menuHeight: Math.min(px(648), screen ? screen.height - barHeight - px(24) : px(648))

    function px(value) {
        return value * uiScale;
    }

    function indicatorEntryId(entry) {
        const item = indicatorHost.hostItem;
        if (item && typeof item.entryId === "function")
            return String(item.entryId(entry) || "");
        if (typeof entry === "string")
            return entry;
        return entry && entry.id !== undefined ? String(entry.id || "") : "";
    }

    function visibleIndicatorIds() {
        const item = indicatorHost.hostItem;
        if (!item || !item.indicatorEntries)
            return [];
        const states = item.indicatorActiveStates || ({});
        const ids = [];
        for (let index = 0; index < item.indicatorEntries.length; index++) {
            const id = indicatorEntryId(item.indicatorEntries[index]);
            if (id !== "" && states[id] !== true)
                ids.push(id);
        }
        const activeIds = item.activeIndicatorIds || [];
        for (let index = 0; index < activeIds.length; index++) {
            const id = String(activeIds[index] || "");
            if (id !== "" && ids.indexOf(id) === -1)
                ids.push(id);
        }
        return ids;
    }

    function indicatorHintFor(index) {
        const item = indicatorHost.hostItem;
        const ids = visibleIndicatorIds();
        const id = index >= 0 && index < ids.length ? ids[index] : "";
        const active = item && item.indicatorActiveStates && item.indicatorActiveStates[id] === true;
        return HintLogic.startIndicator(id, active);
    }

    function rebuild() {
        const started = Date.now();
        results = StartLogic.pinnedFirst(applicationCatalog.search(search.text), openingPinnedIds);
        lastSearchMs = Date.now() - started;
        appList.currentIndex = results.length ? 0 : -1;
        if (results.length)
            Qt.callLater(function () {
                appList.positionViewAtIndex(0, ListView.Contain);
            });
    }

    function moveSelection(offset) {
        appList.currentIndex = StartLogic.movedIndex(appList.currentIndex, offset, results.length);
        if (appList.currentIndex >= 0)
            appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
    }

    function launch(entry, floating) {
        if (entry && applicationCatalog.launch(entry.id, floating === true))
            close();
    }

    function launchFromPointer(entry, modifiers) {
        if (entry && applicationCatalog.launchFromPointer(entry.id, modifiers))
            close();
    }

    function launchSelection(floating) {
        if (appList.currentIndex >= 0 && appList.currentIndex < results.length)
            launch(results[appList.currentIndex], floating === true);
    }

    function togglePin(entry) {
        if (entry)
            pinnedApplications.toggle(entry.id);
    }

    function movePlaceSelection(offset) {
        const places = placesModel.places;
        if (!places.length) {
            placeList.currentIndex = -1;
            return;
        }
        let index = placeList.currentIndex;
        if (index < 0)
            index = offset > 0 ? -1 : places.length;
        let next = index + offset;
        while (next >= 0 && next < places.length && places[next].divider === true)
            next += offset;
        if (next < 0 || next >= places.length)
            return;
        placeList.currentIndex = next;
        placeList.positionViewAtIndex(next, ListView.Contain);
    }

    function openPlace(uri, modifiers, fromPointer) {
        if (applicationCatalog.launchPlace(uri, modifiers, fromPointer))
            close();
    }

    function openPowerControls() {
        close();
        if (bar && typeof bar.openPowerControls === "function")
            bar.openPowerControls();
    }

    function openOmarchyMenu() {
        close();
        if (bar && typeof bar.openOmarchyMenu === "function")
            bar.openOmarchyMenu("root");
    }

    function show() {
        if (open)
            return;
        if (bar)
            bar.requestPopout(root);
        hoverReady = false;
        openingPinnedIds = pinnedApplications.pins.slice(0);
        search.text = "";
        rebuild();
        open = true;
        Qt.callLater(function () {
            search.forceActiveFocus();
        });
    }

    function close() {
        if (!open && reveal <= 0)
            return;
        hoverReady = false;
        startHint.clear();
        open = false;
        if (bar)
            bar.releasePopout(root);
    }

    function toggle() {
        if (open)
            close();
        else
            show();
    }

    function beginFocusPrime() {
        if (open && backingWindowVisible)
            focusPrimeTimer.restart();
    }

    screen: targetScreen
    visible: open || reveal > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "tilelane-start-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    // Acquire keyboard focus on open/reopen, then release the compositor-wide
    // pointer grab so outside clicks can reach the other monitors.
    WlrLayershell.keyboardFocus: open ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    mask: Region {
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    onOpenChanged: {
        focusPrimed = false;
        if (open)
            beginFocusPrime();
        else
            focusPrimeTimer.stop();
    }

    onBackingWindowVisibleChanged: {
        beginFocusPrime();
        if (!backingWindowVisible || !open) {
            hoverReady = false;
            return;
        }
        Qt.callLater(function () {
            if (root.open && root.backingWindowVisible)
                root.hoverReady = true;
        });
    }

    Timer {
        id: focusPrimeTimer
        interval: 75
        onTriggered: if (root.open)
            root.focusPrimed = true
    }

    Variants {
        model: root.open ? Quickshell.screens : []

        delegate: Component {
            PanelWindow {
                required property var modelData

                screen: modelData
                visible: root.open && !!root.screen && modelData.name !== root.screen.name
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "tilelane-start-dismiss"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors {
                    top: true
                    right: true
                    bottom: true
                    left: true
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onPressed: root.close()
                }
            }
        }
    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.bar && typeof root.bar.motionDuration === "function" ? root.bar.motionDuration(140) : 140
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: root.applicationCatalog

        function onIndexRevisionChanged() {
            root.rebuild();
        }
    }

    PlacesModel {
        id: placesModel
    }

    Shortcut {
        enabled: root.open
        sequences: [StandardKey.Cancel]
        context: Qt.ApplicationShortcut
        onActivated: root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Commons.Color.menu.scrim
        opacity: root.reveal

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            acceptedButtons: Qt.AllButtons
            onPressed: root.close()
        }
    }

    Rectangle {
        id: menuCard

        enabled: root.open
        width: root.menuWidth
        height: root.menuHeight
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.px(5)
        anchors.bottomMargin: root.barHeight + root.px(7)
        radius: Commons.Style.cornerRadius
        color: Commons.Color.menu.background
        border.color: Commons.Color.menu.border
        border.width: Math.max(1, Math.round(root.px(2)))
        opacity: root.reveal
        scale: 0.98 + 0.02 * root.reveal
        transformOrigin: Item.BottomLeft

        MouseArea {
            anchors.fill: parent
            onClicked: function (event) {
                event.accepted = true;
            }
        }

        // During the brief Exclusive phase, a click from another monitor can
        // arrive with translated coordinates. Dismiss rather than launch an
        // app, while leaving keyboard search available immediately.
        MouseArea {
            z: 1
            anchors.fill: parent
            enabled: root.open && !root.focusPrimed
            acceptedButtons: Qt.AllButtons
            onPressed: root.close()
        }

        Column {
            anchors.fill: parent
            anchors.margins: root.outerInset
            spacing: root.headerGap

            Row {
                width: parent.width
                height: root.headerHeight
                spacing: root.paneGap

                Item {
                    width: Math.max(0, parent.width - placesHeader.width - parent.spacing)
                    height: parent.height

                    Rectangle {
                        id: omarchyMenuButton

                        width: Math.min(parent.width - anchors.leftMargin, omarchyMenuButtonContent.implicitWidth + root.px(22))
                        height: root.px(34)
                        anchors.left: parent.left
                        anchors.leftMargin: root.appListInset - root.px(11)
                        anchors.verticalCenter: parent.verticalCenter
                        activeFocusOnTab: true
                        readonly property bool tooltipHovered: omarchyMenuPointer.containsMouse
                        readonly property string hintText: root.bar ? root.bar.shortcut("Omarchy menu") : ""
                        radius: root.px(5)
                        color: omarchyMenuPointer.pressed ? Commons.Style.pressedFillFor(Commons.Color.menu.text, Commons.Color.accent, Commons.Color.urgent) : omarchyMenuPointer.containsMouse || activeFocus ? Commons.Color.menu.selectedBackground : "transparent"

                        Accessible.role: Accessible.Button
                        Accessible.name: "Open Omarchy menu"
                        Accessible.description: "Open the native Omarchy actions and settings menu"
                        Accessible.onPressAction: root.openOmarchyMenu()
                        Keys.onSpacePressed: root.openOmarchyMenu()
                        Keys.onReturnPressed: root.openOmarchyMenu()
                        Keys.onEnterPressed: root.openOmarchyMenu()

                        TextMetrics {
                            id: omarchyMenuLabelMetrics

                            font: omarchyMenuLabel.font
                            text: omarchyMenuLabel.text
                        }

                        TextMetrics {
                            id: omarchyMenuChevronMetrics

                            font.family: omarchyMenuChevron.fontFamily
                            font.pixelSize: omarchyMenuChevron.renderedFontSize
                            text: omarchyMenuChevron.text
                        }

                        Row {
                            id: omarchyMenuButtonContent

                            anchors.centerIn: parent
                            spacing: root.px(8)

                            Text {
                                id: omarchyMenuLabel

                                anchors.verticalCenter: parent.verticalCenter
                                text: "Omarchy menu"
                                textFormat: Text.PlainText
                                color: Commons.Color.menu.text
                                font.family: Commons.Style.font.menuFamily
                                font.pixelSize: Commons.Style.font.subtitle
                                font.weight: Font.Medium
                            }

                            OverflowIcon {
                                id: omarchyMenuChevron

                                compact: true
                                anchors.verticalCenter: omarchyMenuLabel.verticalCenter
                                // Align the painted glyphs, not their different font line boxes.
                                anchors.verticalCenterOffset: omarchyMenuLabel.baselineOffset + omarchyMenuLabelMetrics.tightBoundingRect.y + omarchyMenuLabelMetrics.tightBoundingRect.height / 2 - omarchyMenuLabel.height / 2 - (baselineY + omarchyMenuChevronMetrics.tightBoundingRect.y + omarchyMenuChevronMetrics.tightBoundingRect.height / 2 - height / 2)
                                width: fontSize
                                height: fontSize
                                color: Commons.Util.alpha(Commons.Color.menu.text, 0.76)
                            }
                        }

                        MouseArea {
                            id: omarchyMenuPointer

                            anchors.fill: parent
                            hoverEnabled: root.open && root.hoverReady
                            cursorShape: Qt.PointingHandCursor
                            onEntered: startHint.showFor(omarchyMenuButton, omarchyMenuButton.hintText, 550)
                            onExited: startHint.hideFor(omarchyMenuButton)
                            onClicked: root.openOmarchyMenu()
                        }
                    }
                }

                Item {
                    id: placesHeader

                    width: root.rightColumnWidth
                    height: parent.height

                    Item {
                        id: indicatorStrip

                        width: indicatorHost.available ? indicatorHost.implicitWidth * root.indicatorScale : 0
                        height: root.px(32)
                        anchors.right: parent.right
                        // The native indicator delegates center their glyphs in padded
                        // status slots. Extending the clipped host to the column edge
                        // aligns the visible final glyph with the Places row frame.
                        anchors.rightMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        HostedBarWidget {
                            id: indicatorHost

                            width: implicitWidth
                            height: implicitHeight
                            anchors.centerIn: parent
                            scale: root.indicatorScale
                            transformOrigin: Item.Center
                            moduleName: "omarchy.indicators"
                            registry: root.barWidgetRegistry
                            bar: root.bar
                            settings: root.indicatorSettings
                            fallbackEntryPoint: "Indicators.qml"
                            showVisual: true
                        }

                        Row {
                            anchors.fill: parent
                            visible: root.indicatorSlotCount > 0

                            Repeater {
                                id: indicatorHoverFrames

                                model: root.indicatorSlotCount

                                Rectangle {
                                    id: indicatorFrame

                                    required property int index
                                    readonly property string hintText: root.indicatorHintFor(index)
                                    readonly property bool tooltipHovered: indicatorHover.hovered

                                    width: indicatorStrip.width / Math.max(1, indicatorHoverFrames.count)
                                    height: indicatorStrip.height
                                    radius: root.px(4)
                                    color: indicatorHover.hovered ? Commons.Color.menu.selectedBackground : "transparent"

                                    HoverHandler {
                                        id: indicatorHover

                                        enabled: root.open && root.hoverReady
                                        blocking: false
                                        onHoveredChanged: {
                                            if (hovered) {
                                                Qt.callLater(function () {
                                                    if (indicatorHover.hovered)
                                                        startHint.showFor(indicatorFrame, indicatorFrame.hintText, 500);
                                                });
                                            } else {
                                                startHint.hideFor(indicatorFrame);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: parent.height - root.headerHeight - parent.spacing
                spacing: root.paneGap

                Rectangle {
                    id: appPane

                    width: parent.width - placesPane.width - parent.spacing
                    height: parent.height
                    radius: root.px(10)
                    color: Commons.Util.alpha(Commons.Color.menu.text, 0.045)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.appListInset
                        spacing: root.footerGap

                        ListView {
                            id: appList

                            width: parent.width
                            height: Math.max(0, parent.height - root.footerHeight - root.footerGap)
                            activeFocusOnTab: false
                            clip: true
                            model: root.results
                            boundsBehavior: Flickable.StopAtBounds
                            keyNavigationEnabled: false
                            keyNavigationWraps: false

                            Accessible.name: "Applications"
                            Accessible.description: "Use the search box to select and launch applications"

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                focusPolicy: Qt.NoFocus
                            }

                            delegate: Rectangle {
                                id: appRow

                                required property var modelData
                                required property int index
                                readonly property bool pinned: root.pinnedApplications.isPinned(modelData.id)

                                width: ListView.view.width
                                height: root.appRowHeight
                                color: "transparent"

                                Accessible.role: Accessible.Button
                                Accessible.name: "Launch " + String(modelData.name || modelData.id || "application")
                                Accessible.description: pinned ? "Application; pinned" : "Application"
                                Accessible.onPressAction: root.launch(modelData)

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: root.px(2)
                                    anchors.bottomMargin: root.px(2)
                                    radius: root.px(4)
                                    color: appList.currentIndex === appRow.index || rowHover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
                                }

                                HoverHandler {
                                    id: rowHover

                                    enabled: root.open && root.hoverReady
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: root.px(12)
                                    anchors.rightMargin: pinButton.width + root.px(16)
                                    spacing: root.px(12)

                                    Item {
                                        width: root.px(28)
                                        height: width
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: appIcon

                                            anchors.fill: parent
                                            source: root.applicationCatalog.iconSource(appRow.modelData.icon)
                                            sourceSize.width: width * Screen.devicePixelRatio
                                            sourceSize.height: height * Screen.devicePixelRatio
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            retainWhileLoading: true
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: appIcon.status === Image.Error
                                            text: String(appRow.modelData.name || "?").slice(0, 1).toUpperCase()
                                            color: Commons.Color.menu.text
                                            font.family: Commons.Style.font.menuFamily
                                            font.pixelSize: Commons.Style.font.title
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - root.px(52)
                                        text: appRow.modelData.name
                                        textFormat: Text.PlainText
                                        color: Commons.Color.menu.text
                                        font.family: Commons.Style.font.menuFamily
                                        font.pixelSize: Commons.Style.font.title
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: appPointer

                                    property bool controlOnPress: false

                                    anchors.fill: parent
                                    hoverEnabled: root.open && root.hoverReady
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        appList.currentIndex = appRow.index;
                                    }
                                    onPressed: function (event) {
                                        controlOnPress = event.button === Qt.LeftButton && (event.modifiers & Qt.ControlModifier) !== 0;
                                    }
                                    onCanceled: controlOnPress = false
                                    onClicked: function (event) {
                                        const modifiers = controlOnPress || (event.modifiers & Qt.ControlModifier) !== 0 ? Qt.ControlModifier : Qt.NoModifier;
                                        controlOnPress = false;
                                        root.launchFromPointer(appRow.modelData, modifiers);
                                    }
                                }

                                ToolButton {
                                    id: pinButton

                                    readonly property string actionName: appRow.pinned ? "Unpin " + appRow.modelData.name + " from Start" : "Pin " + appRow.modelData.name + " to Start"
                                    readonly property bool tooltipHovered: hovered && opacity > 0
                                    readonly property string hintText: HintLogic.withShortcut(appRow.pinned ? "Unpin from Start" : "Pin to Start", HintLogic.displayShortcut("Ctrl+Space"))

                                    z: 2
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.px(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.px(32)
                                    height: width
                                    focusPolicy: Qt.NoFocus
                                    hoverEnabled: root.open && root.hoverReady
                                    opacity: appRow.pinned || rowHover.hovered || hovered || activeFocus ? 1 : 0

                                    Accessible.name: actionName
                                    Accessible.description: "Change Start menu pins"
                                    Keys.onReturnPressed: clicked()
                                    Keys.onEnterPressed: clicked()
                                    onClicked: {
                                        search.forceActiveFocus();
                                        appList.currentIndex = appRow.index;
                                        root.togglePin(appRow.modelData);
                                    }
                                    onTooltipHoveredChanged: {
                                        if (tooltipHovered)
                                            startHint.showFor(pinButton, hintText, 550);
                                        else
                                            startHint.hideFor(pinButton);
                                    }

                                    contentItem: Text {
                                        text: appRow.pinned ? "\uDB81\uDC03" : "\uDB82\uDD31"
                                        color: appRow.pinned ? Commons.Color.accent : pinButton.hovered || pinButton.activeFocus ? Commons.Color.menu.text : Commons.Util.alpha(Commons.Color.menu.text, 0.66)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: Commons.Style.font.family
                                        font.pixelSize: root.px(15)
                                    }

                                    background: Rectangle {
                                        radius: root.px(4)
                                        color: pinButton.down ? Commons.Style.pressedFillFor(Commons.Color.menu.text, Commons.Color.accent, Commons.Color.urgent) : pinButton.hovered || pinButton.activeFocus ? Commons.Color.menu.selectedBackground : "transparent"
                                        border.color: Commons.Color.accent
                                        border.width: pinButton.activeFocus ? Math.max(1, Math.round(root.px(1))) : 0
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.results.length === 0
                                text: "No applications found"
                                color: Commons.Util.alpha(Commons.Color.menu.text, 0.66)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: Commons.Style.font.menuFamily
                                font.pixelSize: Commons.Style.font.body
                            }
                        }

                        TextField {
                            id: search

                            width: parent.width
                            height: root.footerHeight
                            leftPadding: root.px(14)
                            rightPadding: root.px(14)
                            placeholderText: "Search applications…"
                            color: Commons.Color.menu.text
                            placeholderTextColor: Commons.Util.alpha(Commons.Color.menu.text, 0.62)
                            selectionColor: Commons.Style.selectionFill
                            selectedTextColor: Commons.Color.menu.text
                            font.family: Commons.Style.font.menuFamily
                            selectByMouse: true
                            activeFocusOnTab: true
                            Accessible.name: "Search applications"
                            Accessible.description: "Type to search, use Up and Down to select, Enter to launch, and Ctrl+Space to pin or unpin"

                            background: Rectangle {
                                color: Commons.Util.alpha(Commons.Color.background, 0.36)
                                radius: root.px(4)
                                border.color: search.activeFocus ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.menu.text, 0.14)
                                border.width: Math.max(1, Math.round(root.px(1)))
                            }

                            onTextChanged: root.rebuild()
                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Up)
                                    root.moveSelection(-1);
                                else if (event.key === Qt.Key_Down)
                                    root.moveSelection(1);
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                    root.launchSelection((event.modifiers & Qt.ControlModifier) !== 0);
                                else if (event.key === Qt.Key_Space && event.modifiers === Qt.ControlModifier) {
                                    if (appList.currentIndex >= 0 && appList.currentIndex < root.results.length)
                                        root.togglePin(root.results[appList.currentIndex]);
                                } else
                                    return;
                                event.accepted = true;
                            }
                        }
                    }
                }

                Item {
                    id: placesPane

                    width: root.rightColumnWidth
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.columnInset
                        spacing: root.footerGap

                        ListView {
                            id: placeList

                            width: parent.width
                            height: Math.max(0, parent.height - root.footerHeight - root.footerGap)
                            clip: true
                            model: placesModel.places
                            boundsBehavior: Flickable.StopAtBounds
                            activeFocusOnTab: true

                            Accessible.name: "Places"
                            Accessible.description: "Folders and locations from Files; Ctrl+Click or Ctrl+Enter opens a floating window"

                            onActiveFocusChanged: {
                                if (activeFocus && (currentIndex < 0 || currentIndex >= placesModel.places.length || placesModel.places[currentIndex].divider === true)) {
                                    currentIndex = 0;
                                    positionViewAtIndex(0, ListView.Contain);
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Rectangle {
                                id: placeRow

                                required property var modelData
                                required property int index

                                width: ListView.view.width
                                height: modelData.divider === true ? root.placeDividerHeight : root.placeRowHeight
                                radius: root.px(4)
                                color: modelData.divider !== true && (placeMouse.containsMouse || placeList.activeFocus && placeList.currentIndex === index) ? Commons.Color.menu.selectedBackground : "transparent"
                                border.color: placeList.activeFocus && placeList.currentIndex === index ? Commons.Color.accent : Commons.Color.menu.selectedBorder
                                border.width: modelData.divider !== true && placeList.activeFocus && placeList.currentIndex === index ? Math.max(1, Math.round(root.px(1))) : 0

                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.divider === true ? "" : "Open " + String(modelData.name || "place") + " in Files"
                                Accessible.ignored: modelData.divider === true
                                Accessible.onPressAction: root.openPlace(modelData.uri)

                                Rectangle {
                                    visible: placeRow.modelData.divider === true
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: Commons.Style.space(4)
                                    anchors.rightMargin: Commons.Style.space(4)
                                    height: Commons.Style.spacing.hairline
                                    color: Commons.Util.alpha(Commons.Color.menu.text, 0.2)
                                }

                                Row {
                                    visible: placeRow.modelData.divider !== true
                                    anchors.fill: parent
                                    anchors.leftMargin: root.px(12)
                                    anchors.rightMargin: root.px(10)
                                    spacing: root.px(10)

                                    ToolButton {
                                        id: placeIcon

                                        width: root.px(18)
                                        height: width
                                        anchors.verticalCenter: parent.verticalCenter
                                        padding: 0
                                        focusPolicy: Qt.NoFocus
                                        icon.name: String(placeRow.modelData.iconName || "folder-symbolic")
                                        icon.width: root.px(16)
                                        icon.height: root.px(16)
                                        icon.color: Commons.Color.menu.text
                                        background: null
                                    }

                                    Text {
                                        width: parent.width - placeIcon.width - parent.spacing
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(placeRow.modelData.name || "")
                                        color: Commons.Color.menu.text
                                        font.family: Commons.Style.font.menuFamily
                                        font.pixelSize: Commons.Style.font.body
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: placeMouse

                                    property bool controlOnPress: false

                                    anchors.fill: parent
                                    enabled: placeRow.modelData.divider !== true
                                    hoverEnabled: root.open && root.hoverReady && enabled
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onEntered: placeList.currentIndex = placeRow.index
                                    onPressed: function (event) {
                                        controlOnPress = (event.modifiers & Qt.ControlModifier) !== 0;
                                    }
                                    onCanceled: controlOnPress = false
                                    onClicked: function (event) {
                                        const modifiers = controlOnPress || (event.modifiers & Qt.ControlModifier) !== 0 ? Qt.ControlModifier : Qt.NoModifier;
                                        controlOnPress = false;
                                        placeList.forceActiveFocus();
                                        root.openPlace(placeRow.modelData.uri, modifiers, true);
                                    }
                                }
                            }

                            Keys.onUpPressed: root.movePlaceSelection(-1)
                            Keys.onDownPressed: root.movePlaceSelection(1)
                            Keys.onReturnPressed: function (event) {
                                if (currentIndex >= 0 && currentIndex < placesModel.places.length)
                                    root.openPlace(placesModel.places[currentIndex].uri, event.modifiers, false);
                            }
                            Keys.onEnterPressed: function (event) {
                                if (currentIndex >= 0 && currentIndex < placesModel.places.length)
                                    root.openPlace(placesModel.places[currentIndex].uri, event.modifiers, false);
                            }
                        }

                        Rectangle {
                            id: powerButton

                            width: parent.width
                            height: root.footerHeight
                            activeFocusOnTab: true
                            readonly property bool tooltipHovered: powerMouse.containsMouse
                            readonly property string hintText: root.bar ? root.bar.shortcut("System menu") : ""
                            radius: root.px(4)
                            color: powerMouse.containsMouse || activeFocus ? Commons.Color.menu.selectedBackground : Commons.Util.alpha(Commons.Color.menu.text, 0.045)
                            border.color: activeFocus ? Commons.Color.accent : Commons.Color.menu.selectedBorder
                            border.width: activeFocus ? Math.max(1, Math.round(root.px(1))) : 0

                            Accessible.role: Accessible.Button
                            Accessible.name: "System"
                            Accessible.description: "Open Omarchy system controls"
                            Accessible.onPressAction: root.openPowerControls()
                            Keys.onReturnPressed: root.openPowerControls()
                            Keys.onEnterPressed: root.openPowerControls()

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: root.px(12)
                                anchors.rightMargin: root.px(10)
                                spacing: root.px(10)

                                Text {
                                    width: root.px(18)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "⏻"
                                    color: Commons.Color.menu.text
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Commons.Style.font.menuFamily
                                    font.pixelSize: Commons.Style.font.title
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "System"
                                    color: Commons.Color.menu.text
                                    font.family: Commons.Style.font.menuFamily
                                    font.pixelSize: Commons.Style.font.body
                                }
                            }

                            MouseArea {
                                id: powerMouse

                                anchors.fill: parent
                                hoverEnabled: root.open && root.hoverReady
                                cursorShape: Qt.PointingHandCursor
                                onEntered: startHint.showFor(powerButton, powerButton.hintText, 550)
                                onExited: startHint.hideFor(powerButton)
                                onClicked: {
                                    powerButton.forceActiveFocus();
                                    root.openPowerControls();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    BarHint {
        id: startHint

        barWindow: root
        uiScale: root.uiScale
    }
}
