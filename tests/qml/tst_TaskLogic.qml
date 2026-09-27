import "../../qml/TaskLogic.js" as TaskLogic
import QtQuick
import QtTest

TestCase {
    function test_primaryActionUsesConfirmedState() {
        compare(TaskLogic.primaryAction(false, false), "activate");
        compare(TaskLogic.primaryAction(true, false), "minimize");
        compare(TaskLogic.primaryAction(false, true), "restore");
        compare(TaskLogic.primaryAction(true, true), "restore");
    }

    function test_titleFallbackIsAlwaysAccessible() {
        compare(TaskLogic.displayTitle("Document", "editor"), "Document");
        compare(TaskLogic.displayTitle("", "editor"), "editor");
        compare(TaskLogic.displayTitle("", ""), "Application");
    }

    function test_visualPriorityIsDeterministic() {
        compare(TaskLogic.visualState(false, false, false, false, false, false, false), "idle");
        compare(TaskLogic.visualState(false, false, false, false, false, true, true), "active");
        compare(TaskLogic.visualState(false, false, false, false, true, true, false), "urgent");
        compare(TaskLogic.visualState(false, false, true, true, true, true, false), "hovered");
        compare(TaskLogic.visualState(false, true, true, true, true, true, false), "focused");
        compare(TaskLogic.visualState(true, true, true, true, true, true, false), "pressed");
    }

    function test_fallbackCommandsValidateAndEscapeInputs() {
        compare(TaskLogic.fallbackCode("activate", "not-an-address", ""), "");
        compare(TaskLogic.fallbackCode("activate", "0x123456789abcdef01", ""), "");
        compare(TaskLogic.fallbackCode("close", "0xabc", ""), "return hl.dispatch(hl.dsp.window.close({ window = \"address:0xabc\" }))");
        const minimized = TaskLogic.fallbackCode("minimize", "0xABC", "");
        verify(minimized.indexOf("special:tilelane-minimized") !== -1);
        verify(minimized.indexOf("address:0xABC") !== -1);
        const restored = TaskLogic.fallbackCode("restore", "0xabc", "name:work\\\"room");
        verify(restored.indexOf("name:work\\\\\\\"room") !== -1);
        compare(TaskLogic.fallbackCode("restore", "0xabc", ""), "");
        compare(TaskLogic.fallbackCode("maximize", "0xabc", ""), "return hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", window = \"address:0xabc\" }))");
        compare(TaskLogic.fallbackCode("float", "0xabc", ""), "return hl.dispatch(hl.dsp.window.float({ action = \"toggle\", window = \"address:0xabc\" }))");
    }

    function test_activationTargetsWorkspaceThenExactWindow() {
        const commands = TaskLogic.activationDispatches("0xABC", "name:work\"room");
        compare(commands.length, 2);
        compare(commands[0], "hl.dsp.focus({ workspace = \"name:work\\\"room\" })");
        compare(commands[1], "hl.dsp.focus({ window = \"address:0xABC\" })");
        const minimized = TaskLogic.activationDispatches("0xabc", TaskLogic.minimizedWorkspace);
        compare(minimized.length, 1);
        verify(minimized[0].indexOf("address:0xabc") !== -1);
        compare(TaskLogic.activationDispatches("not-an-address", "2").length, 0);
    }

    function test_restoreTargetsWindowWithoutChangingLayout() {
        const commands = TaskLogic.restoreDispatches("0xABC", "name:work\"room");
        compare(commands.length, 3);
        verify(commands[0].indexOf("follow = false") !== -1);
        verify(commands[0].indexOf("name:work\\\"room") !== -1);
        compare(commands[1], "hl.dsp.focus({ workspace = \"name:work\\\"room\" })");
        compare(commands[2], "hl.dsp.focus({ window = \"address:0xABC\" })");
        verify(commands.join(" ").indexOf("hl.dsp.layout") === -1);
        compare(TaskLogic.restoreDispatches("bad", "2").length, 0);
        compare(TaskLogic.restoreDispatches("0xabc", TaskLogic.minimizedWorkspace).length, 0);
    }

    function test_originJournalIsVersionedAndSanitized() {
        const parsed = TaskLogic.parseOrigins(JSON.stringify({
            "version": 1,
            "origins": {
                "0xABC": "2",
                "0xdef": "name:work",
                "bad": "3",
                "0x123": "special:tilelane-minimized",
                "0x456": 7
            }
        }));
        compare(Object.keys(parsed).length, 2);
        compare(parsed["0xabc"], "2");
        compare(parsed["0xdef"], "name:work");
        compare(Object.keys(TaskLogic.parseOrigins("not json")).length, 0);
        compare(Object.keys(TaskLogic.parseOrigins('{"version":2,"origins":{"0x1":"2"}}')).length, 0);
        const serialized = TaskLogic.serializeOrigins({
            "0xABC": "2",
            "invalid": "3"
        });
        const roundTrip = JSON.parse(serialized);
        compare(roundTrip.version, 1);
        compare(Object.keys(roundTrip.origins).length, 1);
        compare(roundTrip.origins["0xabc"], "2");
    }

    name: "TaskLogic"
}
