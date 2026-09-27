pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import "../HintLogic.js" as HintLogic
import qs.Commons as Commons

Item {
    id: root

    required property var workspaceModel
    property var bar: null
    property real uiScale: 1
    property bool expanded: false
    property bool fanHovered: false
    property int hoveredWorkspace: 0
    property int keyboardIndex: 0
    readonly property var anchorWindow: root.QsWindow.window
    readonly property string monitorName: anchorWindow && anchorWindow.screen ? String(anchorWindow.screen.name || "") : ""
    readonly property int activeWorkspaceId: {
        workspaceModel.revision;
        return workspaceModel.activeIdForMonitor(monitorName);
    }
    readonly property string activeWorkspaceText: activeWorkspaceId > 0 ? String(activeWorkspaceId) : ""
    readonly property bool tooltipHovered: buttonMouse.containsMouse
    readonly property string hintText: HintLogic.workspace(bar ? bar.shortcut("Switch to workspace 1") : "", Quickshell.screens.length, bar ? [bar.shortcut("Move workspace to left monitor"), bar.shortcut("Move workspace to right monitor"), bar.shortcut("Move workspace to up monitor"), bar.shortcut("Move workspace to down monitor")] : [])
    readonly property var workspaceIds: {
        workspaceModel.revision;
        return workspaceModel.ids();
    }
    readonly property real bladeScale: 0.75
    readonly property real bladeHeight: px(190) * bladeScale
    readonly property real fanAngle: 72 + Math.max(0, Math.min(5, workspaceIds.length - 5)) * 12 / 5
    readonly property real bladeStep: workspaceIds.length > 1 ? fanAngle / (workspaceIds.length - 1) : 0
    readonly property real bladeWidth: workspaceIds.length <= 1 ? px(54) * bladeScale : Math.min(px(54) * bladeScale, Math.max(px(24) * bladeScale, 2 * bladeHeight * Math.sin(bladeStep * Math.PI / 360) * 0.92))
    readonly property real bladeBaseGap: workspaceIds.length > 1 ? px(1) : 0
    readonly property real bladeStrokeWidth: Math.max(1, Math.round(px(1)))
    readonly property real bladeBaseWidth: (width - Math.max(0, workspaceIds.length - 1) * bladeBaseGap) / Math.max(1, workspaceIds.length)
    readonly property real fanPadding: px(8)
    readonly property real fanHeight: Math.max(px(190), bladeHeight + workspaceHint.implicitHeight + px(16))
    readonly property real baseRowWidth: width
    readonly property real baseStartX: fanPadding + bladeWidth / 2 - bladeBaseWidth / 2
    readonly property real pivotX: baseStartX + baseRowWidth / 2
    readonly property real pivotY: fanHeight - px(4)
    readonly property real popupTopY: -fanHeight + px(4)
    readonly property real bladeFanWidth: baseStartX + baseRowWidth - bladeBaseWidth / 2 + bladeHeight * Math.sin(fanAngle * Math.PI / 180) + bladeWidth / 2 + fanPadding
    readonly property real fanWidth: Math.max(bladeFanWidth, px(190), workspaceHint.implicitWidth + fanPadding * 2)
    property real openProgress: expanded ? 1 : 0

    function px(value) {
        return value * uiScale;
    }

    function workspaceById(id) {
        return workspaceModel.recordFor(id);
    }

    function bladeAngle(index, count) {
        return count <= 1 ? 0 : index * fanAngle / (count - 1);
    }

    function baseCenter(index) {
        return baseStartX + bladeBaseWidth / 2 + index * (bladeBaseWidth + bladeBaseGap);
    }

    function bladeFill(focused, hovered) {
        const background = Commons.Util.alpha(Commons.Color.menu.background, 1);
        if (focused)
            return Qt.tint(background, Commons.Util.alpha(Commons.Color.accent, 0.34));
        if (hovered)
            return Qt.tint(background, Commons.Util.alpha(Commons.Color.menu.text, 0.16));
        return background;
    }

    function bladeStroke(focused, urgent) {
        if (urgent)
            return Commons.Color.urgent;
        if (focused)
            return Commons.Color.accent;
        return Commons.Util.alpha(Commons.Color.menu.text, 0.28);
    }

    function bladeText(focused, hovered, occupied) {
        if (focused || hovered || occupied)
            return Commons.Color.menu.text;
        return Commons.Util.alpha(Commons.Color.menu.text, 0.38);
    }

    function bladeBaseLeft(width, height, angle) {
        const radians = angle * Math.PI / 180;
        return Qt.point(width / 2 - bladeBaseWidth / 2 * Math.cos(radians), height + bladeBaseWidth / 2 * Math.sin(radians));
    }

    function bladeBaseRight(width, height, angle) {
        const radians = angle * Math.PI / 180;
        return Qt.point(width / 2 + bladeBaseWidth / 2 * Math.cos(radians), height - bladeBaseWidth / 2 * Math.sin(radians));
    }

    function distanceToSegment(point, start, end) {
        const dx = end.x - start.x;
        const dy = end.y - start.y;
        const lengthSquared = dx * dx + dy * dy;
        if (lengthSquared <= 0.0001)
            return Math.hypot(point.x - start.x, point.y - start.y);
        const position = Math.max(0, Math.min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared));
        return Math.hypot(point.x - (start.x + position * dx), point.y - (start.y + position * dy));
    }

    function bladeContains(point, width, height, padding, angle) {
        const tolerance = Math.max(0, Number(padding || 0));
        const corner = Math.min(px(18) * bladeScale, width / 2);
        const vertices = [bladeBaseLeft(width, height, angle), Qt.point(0, corner), Qt.point(0, 0), Qt.point(corner, 0), Qt.point(width - corner, 0), Qt.point(width, 0), Qt.point(width, corner), bladeBaseRight(width, height, angle)];
        let inside = false;
        for (let index = 0, previous = vertices.length - 1; index < vertices.length; previous = index++) {
            const currentPoint = vertices[index];
            const previousPoint = vertices[previous];
            if ((currentPoint.y > point.y) !== (previousPoint.y > point.y) && point.x < (previousPoint.x - currentPoint.x) * (point.y - currentPoint.y) / (previousPoint.y - currentPoint.y) + currentPoint.x)
                inside = !inside;
            if (distanceToSegment(point, previousPoint, currentPoint) <= Math.max(0.01, tolerance))
                return true;
        }
        return inside;
    }

    function workspaceAtPoint(point, padding) {
        let bestWorkspace = 0;
        let bestScore = Number.POSITIVE_INFINITY;
        for (let index = 0; index < bladeRepeater.count; index++) {
            const blade = bladeRepeater.itemAt(index);
            if (!blade)
                continue;
            const local = blade.mapFromItem(fanSurface, point.x, point.y);
            if (!bladeContains(local, blade.width, blade.height, padding, blade.rotation))
                continue;
            const score = Math.abs(local.x - blade.width / 2);
            if (score < bestScore) {
                bestScore = score;
                bestWorkspace = workspaceIds[index];
            }
        }
        return bestWorkspace;
    }

    function open() {
        collapseTimer.stop();
        openTimer.stop();
        if (bar)
            bar.hideTooltip(root);
        keyboardIndex = Math.max(0, workspaceIds.indexOf(activeWorkspaceId));
        expanded = true;
        if (bar)
            bar.requestPopout(root);
    }

    function close() {
        openTimer.stop();
        collapseTimer.stop();
        expanded = false;
        hoveredWorkspace = 0;
        if (bar)
            bar.releasePopout(root);
    }

    function toggle() {
        if (expanded)
            close();
        else
            open();
    }

    function activate(id) {
        if (workspaceModel.activate(id))
            close();
    }

    width: px(32)
    height: px(32)
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: "Workspace " + activeWorkspaceText
    Accessible.description: expanded ? "Workspace selector open; use Left and Right, then Enter" : "Open workspace selector"
    Accessible.onPressAction: toggle()

    Behavior on openProgress {
        NumberAnimation {
            duration: root.bar && typeof root.bar.motionDuration === "function" ? root.bar.motionDuration(110) : 110
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: openTimer

        interval: 200
        onTriggered: root.open()
    }

    Timer {
        id: collapseTimer

        interval: 160
        onTriggered: {
            if (!buttonMouse.containsMouse && !root.fanHovered)
                root.close();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.px(4)
        color: buttonMouse.pressed ? Commons.Style.pressedFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : buttonMouse.containsMouse || root.expanded || root.activeFocus ? Commons.Style.hoverFillFor(Commons.Color.bar.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"

        Item {
            anchors.centerIn: parent
            width: root.px(18)
            height: root.px(18)

            Rectangle {
                anchors.fill: parent
                radius: root.px(3)
                color: "transparent"
                border.color: Commons.Color.bar.text
                border.width: Math.max(1, Math.round(root.px(1)))

                Text {
                    anchors.centerIn: parent
                    text: root.activeWorkspaceText
                    color: Commons.Color.bar.text
                    font.family: Commons.Style.font.family
                    font.pixelSize: Commons.Style.font.body
                }
            }
        }

        BarMouseArea {
            id: buttonMouse

            bar: root.bar
            forwardPress: function (button) {
                if (button !== Qt.LeftButton)
                    return false;
                root.toggle();
                return true;
            }

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                collapseTimer.stop();
                if (!root.expanded)
                    openTimer.restart();
            }
            onExited: {
                openTimer.stop();
                collapseTimer.restart();
            }
            onClicked: {
                root.toggle();
            }
        }
    }

    Keys.onSpacePressed: toggle()
    Keys.onEscapePressed: close()
    Keys.onLeftPressed: {
        if (expanded)
            keyboardIndex = Math.max(0, keyboardIndex - 1);
        else
            open();
    }
    Keys.onRightPressed: {
        if (expanded)
            keyboardIndex = Math.min(workspaceIds.length - 1, keyboardIndex + 1);
        else
            open();
    }
    Keys.onReturnPressed: {
        if (expanded)
            activate(workspaceIds[keyboardIndex]);
        else
            open();
    }
    Keys.onEnterPressed: {
        if (expanded)
            activate(workspaceIds[keyboardIndex]);
        else
            open();
    }

    PopupWindow {
        id: fanWindow

        visible: root.expanded || root.openProgress > 0.01
        color: "transparent"
        implicitWidth: Math.ceil(root.fanWidth)
        implicitHeight: Math.ceil(root.fanHeight)
        mask: Region {
            item: fanSurface
        }

        anchor {
            window: root.anchorWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            onAnchoring: {
                if (!root.anchorWindow)
                    return;
                const point = root.anchorWindow.contentItem.mapFromItem(root, root.width / 2 - root.pivotX, 0);
                fanWindow.anchor.rect.x = Math.round(point.x);
                fanWindow.anchor.rect.y = Math.round(root.popupTopY);
            }
        }

        Item {
            id: fanSurface

            anchors.fill: parent
            visible: root.openProgress > 0.01

            HoverHandler {
                onHoveredChanged: {
                    root.fanHovered = hovered;
                    if (hovered) {
                        collapseTimer.stop();
                        root.open();
                    } else {
                        collapseTimer.restart();
                    }
                }
            }

            HintBubble {
                id: workspaceHint

                x: Math.max(root.fanPadding, Math.min(root.fanWidth - width - root.fanPadding, root.pivotX - width / 2))
                y: root.px(4)
                z: 1100
                text: root.hintText
                uiScale: root.uiScale
            }

            Repeater {
                id: bladeRepeater

                model: root.workspaceIds

                delegate: Item {
                    id: blade

                    required property int index
                    required property int modelData
                    readonly property var workspace: root.workspaceById(modelData)
                    readonly property bool occupied: workspace ? workspace.occupied === true : false
                    readonly property bool focused: modelData === root.activeWorkspaceId
                    readonly property bool urgent: workspace ? workspace.urgent === true : false
                    readonly property bool hovered: root.hoveredWorkspace === modelData || root.expanded && root.keyboardIndex === index && root.activeFocus
                    readonly property real targetAngle: root.bladeAngle(index, root.workspaceIds.length)
                    readonly property real renderPadding: Math.ceil(root.bladeStrokeWidth * 2 + root.bladeBaseWidth / 2)
                    readonly property point baseLeft: root.bladeBaseLeft(width, height, rotation)
                    readonly property point baseRight: root.bladeBaseRight(width, height, rotation)

                    x: root.baseCenter(index) - width / 2
                    y: root.pivotY - height
                    width: root.bladeWidth
                    height: root.bladeHeight
                    transformOrigin: Item.Bottom
                    rotation: targetAngle * root.openProgress
                    scale: 0.92 + 0.08 * root.openProgress
                    opacity: root.openProgress > 0.01 ? 1 : 0
                    z: focused ? 100 : index

                    Shape {
                        x: -blade.renderPadding
                        y: -blade.renderPadding
                        width: parent.width + 2 * blade.renderPadding
                        height: parent.height + 2 * blade.renderPadding
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: root.bladeFill(blade.focused, blade.hovered)
                            strokeColor: root.bladeStroke(blade.focused, blade.urgent)
                            strokeWidth: root.bladeStrokeWidth
                            joinStyle: ShapePath.RoundJoin
                            startX: blade.renderPadding + blade.baseLeft.x
                            startY: blade.renderPadding + blade.baseLeft.y

                            PathLine {
                                x: blade.renderPadding
                                y: blade.renderPadding + Math.min(root.px(18) * root.bladeScale, blade.width / 2)
                            }

                            PathQuad {
                                controlX: blade.renderPadding
                                controlY: blade.renderPadding
                                x: blade.renderPadding + Math.min(root.px(18) * root.bladeScale, blade.width / 2)
                                y: blade.renderPadding
                            }

                            PathLine {
                                x: blade.renderPadding + blade.width - Math.min(root.px(18) * root.bladeScale, blade.width / 2)
                                y: blade.renderPadding
                            }

                            PathQuad {
                                controlX: blade.renderPadding + blade.width
                                controlY: blade.renderPadding
                                x: blade.renderPadding + blade.width
                                y: blade.renderPadding + Math.min(root.px(18) * root.bladeScale, blade.width / 2)
                            }

                            PathLine {
                                x: blade.renderPadding + blade.baseRight.x
                                y: blade.renderPadding + blade.baseRight.y
                            }

                            PathLine {
                                x: blade.renderPadding + blade.baseLeft.x
                                y: blade.renderPadding + blade.baseLeft.y
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(1, parent.width - root.px(6) * root.bladeScale)
                        y: root.px(12) * root.bladeScale
                        text: String(blade.modelData)
                        horizontalAlignment: Text.AlignHCenter
                        color: blade.urgent ? Commons.Color.urgent : root.bladeText(blade.focused, blade.hovered, blade.occupied)
                        font.family: Commons.Style.font.family
                        font.pixelSize: Math.max(1, Math.round(Commons.Style.font.subtitle * (root.workspaceIds.length > 7 ? 1.15 : 1.35)))
                        font.weight: blade.focused ? Font.DemiBold : Font.Medium
                        fontSizeMode: Text.HorizontalFit
                    }
                }
            }

            MouseArea {
                id: fanMouse

                anchors.fill: parent
                z: 1000
                hoverEnabled: true
                readonly property int targetWorkspace: root.workspaceAtPoint(Qt.point(mouseX, mouseY), root.px(3))
                cursorShape: targetWorkspace > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onTargetWorkspaceChanged: {
                    if (containsMouse)
                        root.hoveredWorkspace = targetWorkspace;
                }
                onExited: root.hoveredWorkspace = 0
                onClicked: function (mouse) {
                    const workspace = root.workspaceAtPoint(Qt.point(mouse.x, mouse.y), root.px(3));
                    if (workspace > 0)
                        root.activate(workspace);
                    else
                        mouse.accepted = false;
                }
            }
        }
    }
}
