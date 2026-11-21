pragma Singleton

import QtQuick

QtObject {
    property color selectedAccentFill: "#334488ff"
    property var font: ({
            family: "sans-serif",
            menuFamily: "sans-serif",
            subtitle: 14,
            body: 14
        })

    function space(value) {
        return value;
    }

    function pressedFillFor() {
        return "#22ffffff";
    }
}
