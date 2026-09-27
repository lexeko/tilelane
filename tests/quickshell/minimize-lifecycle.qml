import QtQuick
import Quickshell
import "qml/models"

ShellRoot {
    QtObject {
        id: nativeHandle
        property bool minimized: true
        property int activations: 0
        function activate() {
            activations++;
        }
    }
    QtObject {
        id: model
        property bool initialized: true
        property int revision: 0
        property var record: ({
                workspaceName: "3",
                minimized: false
            })
        function recordFor(address) {
            return record;
        }
        function toplevelFor(address) {
            return {
                wayland: nativeHandle
            };
        }
    }
    WindowActions {
        id: actions
        windowModel: model
    }
    Timer {
        interval: 250
        running: true
        onTriggered: {
            function check(condition, message) {
                if (!condition)
                    throw new Error(message);
            }
            try {
                check(actions.originsLoaded, "journal not loaded");
                actions.rememberOrigin("0xabc", "3");
                model.revision++;
                check(actions.fallbackOrigins["0xabc"] === "3", "Pending minimize lost its workspace on a normal update");
                check(actions.observedOrigins["0xabc"] !== true, "Minimize marked confirmed before workspace move");
                model.record = {
                    workspaceName: "special:tilelane-minimized",
                    minimized: true
                };
                model.revision++;
                check(actions.observedOrigins["0xabc"] === true, "Minimize never confirmed");
                check(actions.fallbackOrigins["0xabc"] === "3", "Confirmed minimize lost origin");
                model.record = {
                    workspaceName: "3",
                    minimized: false
                };
                model.revision++;
                check(actions.fallbackOrigins["0xabc"] === undefined, "Completed restore did not clear origin");
                model.record = {
                    workspaceName: "special:tilelane-minimized",
                    minimized: true
                };
                check(actions.invoke("0xabc", "restore") === false, "Missing origin incorrectly opens hidden workspace");
                check(nativeHandle.activations === 0, "Hidden workspace activated through Wayland");
                console.log("LIFECYCLE PASS");
            } catch (error) {
                console.error("LIFECYCLE FAIL: " + error.message);
            } finally {
                actions.fallbackOrigins = ({});
                Qt.quit();
            }
        }
    }
}
