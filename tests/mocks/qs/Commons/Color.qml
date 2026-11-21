pragma Singleton

import QtQuick

QtObject {
    property var bar: ({
            text: "#ffffff"
        })
    property var menu: ({
            text: "#ffffff",
            selectedBackground: "#333333"
        })
    property color accent: "#4488ff"
    property color urgent: "#ff4444"
}
