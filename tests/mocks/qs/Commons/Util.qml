pragma Singleton

import QtQuick

QtObject {
    function alpha(color, amount) {
        return Qt.rgba(0.5, 0.5, 0.5, amount);
    }
}
