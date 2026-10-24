pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import qs.Commons as Commons

Item {
    id: root

    required property var barWindow
    required property var controller
    property var tip: null
    property real uiScale: 1
    property bool compact: false
    property bool cardOpen: false
    readonly property real buttonHeight: px(30)
    readonly property real buttonWidth: compact ? px(32) : Math.max(px(80), buttonLabel.implicitWidth + px(36))

    function px(value) {
        return value * uiScale;
    }

    function close() {
        cardOpen = false;
    }

    function openCard() {
        if (!tip)
            return;
        if (controller && controller.saveError)
            controller.saveError = "";
        if (controller && controller.bar)
            controller.bar.requestPopout(root);
        cardOpen = true;
    }

    implicitWidth: buttonWidth
    implicitHeight: buttonHeight
    width: visible ? implicitWidth : 0
    height: implicitHeight
    activeFocusOnTab: visible

    onVisibleChanged: if (!visible)
        close()
    onCardOpenChanged: {
        if (!cardOpen && controller && controller.bar)
            controller.bar.releasePopout(root);
    }
    Component.onDestruction: if (controller && controller.bar)
        controller.bar.releasePopout(root)

    Commons.Translations {
        id: strings

        directory: Qt.resolvedUrl("../../i18n")
    }

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: root.px(7)
        color: pointer.pressed ? Commons.Util.alpha(Commons.Color.accent, 0.32) : pointer.containsMouse || root.activeFocus ? Commons.Util.alpha(Commons.Color.accent, 0.24) : Commons.Util.alpha(Commons.Color.accent, 0.15)
        border.width: Math.max(1, Math.round(root.px(1)))
        border.color: Commons.Color.accent

        Row {
            anchors.centerIn: parent
            spacing: root.px(5)

            Text {
                text: "i"
                textFormat: Text.PlainText
                color: Commons.Color.accent
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.bodySmall
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                width: root.px(13)
                height: root.buttonHeight
            }

            Text {
                id: buttonLabel

                visible: !root.compact
                text: root.tip ? strings.t(root.tip.buttonKey) : ""
                textFormat: Text.PlainText
                color: Commons.Color.bar.text
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.bodySmall
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                height: root.buttonHeight
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.cardOpen ? root.close() : root.openCard()
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.tip ? strings.t(root.tip.buttonKey) : ""
    Accessible.onPressAction: root.cardOpen ? root.close() : root.openCard()
    Keys.onReturnPressed: root.cardOpen ? root.close() : root.openCard()
    Keys.onEnterPressed: root.cardOpen ? root.close() : root.openCard()
    Keys.onSpacePressed: root.cardOpen ? root.close() : root.openCard()

    PopupWindow {
        id: cardWindow

        visible: root.cardOpen && root.visible && root.tip !== null
        color: "transparent"
        implicitWidth: root.px(370)
        implicitHeight: card.implicitHeight
        mask: Region {
            item: card
        }

        onVisibleChanged: if (!visible && root.cardOpen)
            root.close()

        HyprlandFocusGrab {
            active: root.cardOpen
            windows: root.barWindow ? [cardWindow, root.barWindow] : [cardWindow]
            onCleared: root.close()
        }

        anchor {
            window: root.barWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            onAnchoring: {
                if (!root.barWindow)
                    return;
                const point = root.barWindow.contentItem.mapFromItem(root, root.width / 2 - cardWindow.implicitWidth / 2, -cardWindow.implicitHeight - root.px(8));
                cardWindow.anchor.rect.x = Math.round(point.x);
                cardWindow.anchor.rect.y = Math.round(point.y);
            }
        }

        Rectangle {
            id: card

            implicitWidth: cardWindow.implicitWidth
            implicitHeight: content.implicitHeight + root.px(30)
            width: implicitWidth
            height: implicitHeight
            radius: root.px(9)
            color: Commons.Color.menu.background
            border.color: Commons.Color.menu.border
            border.width: Math.max(1, Math.round(root.px(1)))

            Keys.onEscapePressed: root.close()

            Column {
                id: content

                x: root.px(15)
                y: root.px(15)
                width: parent.width - root.px(30)
                spacing: root.px(9)

                Row {
                    width: parent.width
                    spacing: root.px(8)

                    Text {
                        width: parent.width - closeButton.width - parent.spacing
                        text: root.tip ? strings.t(root.tip.titleKey) : ""
                        textFormat: Text.PlainText
                        color: Commons.Color.menu.text
                        font.family: Commons.Style.font.family
                        font.pixelSize: Commons.Style.font.subtitle
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Button {
                        id: closeButton

                        width: root.px(24)
                        height: root.px(24)
                        text: "×"
                        Accessible.name: strings.t("tips.close")
                        onClicked: root.close()
                        background: Rectangle {
                            radius: root.px(4)
                            color: closeButton.hovered || closeButton.activeFocus ? Commons.Color.menu.selectedBackground : "transparent"
                        }
                        contentItem: Text {
                            text: closeButton.text
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Commons.Style.font.title
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.tip ? strings.t(root.tip.bodyKey) : ""
                    textFormat: Text.PlainText
                    color: Commons.Color.menu.text
                    font.family: Commons.Style.font.family
                    font.pixelSize: Commons.Style.font.body
                    wrapMode: Text.Wrap
                }

                Row {
                    spacing: root.px(8)

                    Button {
                        id: settingsButton

                        text: root.tip ? strings.t(root.tip.actionKey) : ""
                        onClicked: {
                            if (root.controller.runAction(root.tip.id))
                                root.close();
                        }
                        background: Rectangle {
                            radius: root.px(5)
                            color: Commons.Color.accent
                        }
                        contentItem: Text {
                            text: settingsButton.text
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.background
                            font.family: Commons.Style.font.family
                            font.pixelSize: Commons.Style.font.body
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        id: laterButton

                        text: strings.t("tips.later")
                        onClicked: {
                            root.controller.later(root.tip.id);
                            root.close();
                        }
                        background: Rectangle {
                            radius: root.px(5)
                            color: laterButton.hovered || laterButton.activeFocus ? Commons.Color.menu.selectedBackground : "transparent"
                        }
                        contentItem: Text {
                            text: laterButton.text
                            textFormat: Text.PlainText
                            color: Commons.Color.menu.text
                            font.family: Commons.Style.font.family
                            font.pixelSize: Commons.Style.font.body
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Button {
                    id: dismissButton

                    text: strings.t("tips.dismiss")
                    onClicked: if (root.controller.dismiss(root.tip.id))
                        root.close()
                    background: Rectangle {
                        radius: root.px(5)
                        color: dismissButton.hovered || dismissButton.activeFocus ? Commons.Color.menu.selectedBackground : "transparent"
                    }
                    contentItem: Text {
                        text: dismissButton.text
                        textFormat: Text.PlainText
                        color: Commons.Color.menu.text
                        font.family: Commons.Style.font.family
                        font.pixelSize: Commons.Style.font.body
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    visible: root.controller && root.controller.saveError !== ""
                    width: parent.width
                    text: visible ? strings.t("tips.saveError") : ""
                    textFormat: Text.PlainText
                    color: Commons.Color.urgent
                    font.family: Commons.Style.font.family
                    font.pixelSize: Commons.Style.font.caption
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
