pragma Singleton

import QtQml

QtObject {
    property var detachedCommands: []

    function statePath(name) {
        return "/mock-state/" + name;
    }
    function execDetached(command) {
        detachedCommands = detachedCommands.concat([command]);
    }

    function env(name) {
        return "";
    }
}
