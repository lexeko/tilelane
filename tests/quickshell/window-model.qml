import QtQuick
import Quickshell
import "qml/models"
import "fixtures/WindowFixtures.js" as Fixtures

ShellRoot {
    WindowModel {
        id: windows
    }

    QtObject {
        id: firstSource
    }

    QtObject {
        id: replacementSource
    }

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function reset() {
        windows.model.clear();
        windows.sourcesByAddress = ({});
        windows.nextOrder = 1;
        windows.revision = 0;
    }

    function orderedAddresses() {
        const records = [];
        for (let index = 0; index < windows.model.count; index++)
            records.push(windows.recordFor(windows.model.get(index).address));
        return records.sort((a, b) => a.orderKey - b.orderKey).map(record => record.address).join(",");
    }

    function openingOrder() {
        const snapshot = [
            {
                address: "0xc",
                stableId: "18000030",
                pid: 42,
                active: true
            },
            {
                address: "0xa",
                stableId: "18000010",
                pid: 42
            },
            {
                address: "0xb",
                stableId: "18000020",
                pid: 42
            }
        ];
        for (const sequence of [snapshot, snapshot.slice().reverse()]) {
            reset();
            for (const record of sequence)
                windows.upsert(Object.assign({}, record), firstSource);
            check(orderedAddresses() === "0xa,0xb,0xc", "Enumeration order replaced opening order");
        }
        windows.upsert({
            address: "0xd"
        }, firstSource);
        check(orderedAddresses() === "0xa,0xb,0xc,0xd", "Window without details has wrong order");
        windows.upsert({
            address: "0xd",
            stableId: "18000040"
        }, firstSource);
        for (const change of [
            {
                minimized: true
            },
            {
                minimized: false,
                active: true
            },
            {
                maximized: true
            },
            {
                maximized: false
            }
        ]) {
            windows.upsert(Object.assign({
                address: "0xb",
                stableId: "18000020"
            }, change), firstSource);
            check(orderedAddresses() === "0xa,0xb,0xc,0xd", "Window state change reordered tasks");
        }
        check(windows.recordFor("0xd").orderKey === 0x18000040, "Late compositor ID was ignored");
    }

    function retitle() {
        reset();
        windows.upsert(Fixtures.clone(Fixtures.nativeWindow), firstSource);
        windows.upsert(Fixtures.clone(Fixtures.xwaylandWindow), replacementSource);
        const changed = Fixtures.clone(Fixtures.nativeWindow);
        changed.title = "A title that sorts first";
        windows.upsert(changed, firstSource);
        check(windows.model.get(0).address === "0xaaa" && windows.model.get(1).address === "0xbbb", "Retitle moved model rows");
        check(windows.recordFor("0xaaa").orderKey === 1 && windows.recordFor("0xbbb").orderKey === 2, "Retitle changed fallback order");
    }

    function updates() {
        reset();
        windows.upsert(Fixtures.clone(Fixtures.nativeWindow), firstSource);
        const changed = Fixtures.clone(Fixtures.nativeWindow);
        Object.assign(changed, {
            title: "Renamed while running",
            active: false,
            urgent: true,
            workspaceId: 7,
            workspaceName: "7",
            monitorId: 2,
            monitorName: "DP-3"
        });
        windows.upsert(changed, firstSource);
        const record = windows.recordFor("0xaaa");
        check(windows.model.count === 1 && windows.revision === 2, "Update added a row or missed revision");
        check(record.title === changed.title && !record.active && record.urgent, "Window roles did not update");
        check(record.workspaceName === "7" && record.monitorName === "DP-3" && record.orderKey === 1, "Move lost placement or order");
        windows.upsert(Fixtures.clone(changed), firstSource);
        check(windows.revision === 2, "Identical update changed revision");
        record.title = "Detached copy";
        check(windows.recordFor("0xaaa").title === changed.title, "recordFor exposed mutable model data");
    }

    function staleClose() {
        reset();
        windows.upsert(Fixtures.clone(Fixtures.nativeWindow), firstSource);
        const replacement = Fixtures.clone(Fixtures.nativeWindow);
        replacement.generation = 9;
        replacement.title = "Replacement";
        windows.upsert(replacement, replacementSource);
        const revision = windows.revision;
        windows.remove("0xaaa", 1, firstSource);
        check(windows.model.count === 1 && windows.revision === revision, "Stale close removed replacement");
        check(windows.recordFor("0xaaa").generation === 9 && windows.toplevelFor("0xaaa") === replacementSource, "Stale close lost replacement source");
        windows.remove("0xaaa", 9, replacementSource);
        check(windows.model.count === 0 && windows.revision === revision + 1, "Matching close did not remove window");
        check(windows.recordFor("0xaaa") === null && windows.toplevelFor("0xaaa") === null, "Close retained record or source");
    }

    function lookupsAndInvalidEvents() {
        reset();
        windows.upsert({
            address: ""
        }, firstSource);
        windows.remove("0xmissing", 1, firstSource);
        check(windows.model.count === 0 && windows.revision === 0, "Invalid events changed model");
        const record = Fixtures.clone(Fixtures.nativeWindow);
        record.address = "AAA";
        record.pid = 123;
        windows.upsert(record, firstSource);
        check(windows.addressForPid(123) === "0xaaa" && windows.addressForPid(0) === "", "PID lookup failed");
        check(windows.addressForAppId(record.waylandAppId.toUpperCase()) === "0xaaa", "App ID lookup failed");
        check(windows.toplevelFor("AAA") === firstSource, "Source lookup did not normalize address");
        windows.forgetSource("0xaaa", replacementSource);
        check(windows.toplevelFor("0xaaa") === firstSource, "Stale source removal cleared current source");
    }

    Timer {
        interval: 50
        running: true
        onTriggered: {
            try {
                check(windows.initialized && windows.model.count === 0, "Fixture must start without compositor windows");
                openingOrder();
                retitle();
                updates();
                staleClose();
                lookupsAndInvalidEvents();
                console.log("WINDOW MODEL PASS");
            } catch (error) {
                console.error("WINDOW MODEL FAIL: " + error.message);
            } finally {
                Qt.quit();
            }
        }
    }
}
