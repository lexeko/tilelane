import QtQuick
import QtTest
import "../../qml/SettingsLogic.js" as SettingsLogic

TestCase {
    name: "SettingsLogic"

    function test_invalidFieldsDoNotDiscardOtherPreferences() {
        const values = SettingsLogic.read({
            tilelanePins: ["bad\nID"],
            tilelaneStartPins: ["files", "files", "browser"],
            tilelaneIdentityOverrides: {
                terminal: "editor"
            },
            reducedMotion: true
        });
        compare(values.tilelanePins, []);
        compare(values.tilelaneStartPins, ["files", "browser"]);
        compare(values.tilelaneIdentityOverrides.terminal, "editor");
        verify(values.reducedMotion);
        compare(values.errors.length, 1);
    }

    function test_legacyPinsDoNotPreventPreferenceImport() {
        const legacy = SettingsLogic.legacyPreferences(JSON.stringify({
            version: 1,
            pins: "invalid old pins",
            overrides: {
                terminal: "editor"
            },
            reducedMotion: true
        }));
        const bar = {
            id: "example",
            layout: {
                left: [
                    {
                        id: "clock"
                    }
                ]
            },
            position: "top"
        };
        verify(SettingsLogic.initialize(bar, legacy));
        compare(bar.tilelanePins, []);
        compare(bar.tilelaneStartPins, []);
        compare(bar.tilelaneIdentityOverrides.terminal, "editor");
        verify(bar.reducedMotion);
        compare(bar.layout.left[0].id, "clock");
        compare(bar.position, "top");
        verify(!SettingsLogic.initialize(bar, {
            overrides: {},
            reducedMotion: false
        }));
        verify(bar.reducedMotion);
    }

    function test_existingInlineValuesWinIncludingFalse() {
        const bar = {
            reducedMotion: false,
            tilelanePins: ["browser"],
            tilelaneIdentityOverrides: {}
        };
        verify(SettingsLogic.initialize(bar, {
            overrides: {
                terminal: "editor"
            },
            reducedMotion: true
        }));
        verify(!bar.reducedMotion);
        compare(bar.tilelanePins, ["browser"]);
        compare(Object.keys(bar.tilelaneIdentityOverrides).length, 0);
    }

    function test_invalidLegacyCannotBeSilentlyDiscarded() {
        const cases = ['{', '{"version":2}', '{"version":1,"overrides":[]}', '{"version":1,"reducedMotion":"true"}'];
        for (let index = 0; index < cases.length; index++) {
            let rejected = false;
            try {
                SettingsLogic.legacyPreferences(cases[index]);
            } catch (error) {
                rejected = true;
            }
            verify(rejected);
        }
    }

    function test_futureVersionIsUntouched() {
        const bar = {
            tilelaneSettingsVersion: 2,
            tilelanePins: ["future"]
        };
        verify(!SettingsLogic.initialize(bar, {
            overrides: {},
            reducedMotion: false
        }));
        compare(bar.tilelaneSettingsVersion, 2);
        compare(bar.tilelanePins, ["future"]);
    }
}
