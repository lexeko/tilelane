import "../../qml/SettingsLogic.js" as SettingsLogic
import QtQuick
import QtTest

TestCase {
    function test_invalidFieldsDoNotDiscardOtherPreferences() {
        const values = SettingsLogic.read({
            "tilelanePins": ["bad\nID"],
            "tilelaneStartPins": ["files", "files", "browser"],
            "tilelaneIdentityOverrides": {
                "terminal": "editor"
            },
            "reducedMotion": true
        });
        compare(values.tilelanePins, []);
        compare(values.tilelaneStartPins, ["files", "browser"]);
        compare(values.tilelaneIdentityOverrides.terminal, "editor");
        verify(values.reducedMotion);
        compare(values.errors.length, 1);
    }

    function test_legacyPinsDoNotPreventPreferenceImport() {
        const legacy = SettingsLogic.legacyPreferences(JSON.stringify({
            "version": 1,
            "pins": "invalid old pins",
            "overrides": {
                "terminal": "editor"
            },
            "reducedMotion": true
        }));
        const bar = {
            "id": "example",
            "layout": {
                "left": [
                    {
                        "id": "clock"
                    }
                ]
            },
            "position": "top"
        };
        verify(SettingsLogic.initialize(bar, legacy));
        compare(bar.tilelanePins, []);
        compare(bar.tilelaneStartPins, []);
        compare(bar.tilelaneIdentityOverrides.terminal, "editor");
        verify(bar.reducedMotion);
        verify(bar.tilelaneTranslucent);
        verify(!bar.tilelaneSuperStart);
        compare(bar.layout.left[0].id, "clock");
        compare(bar.position, "top");
        verify(!SettingsLogic.initialize(bar, {
            "overrides": {},
            "reducedMotion": false
        }));
        verify(bar.reducedMotion);
    }

    function test_existingInlineValuesWinIncludingFalse() {
        const bar = {
            "reducedMotion": false,
            "tilelaneTranslucent": false,
            "tilelaneSuperStart": true,
            "tilelanePins": ["browser"],
            "tilelaneIdentityOverrides": {}
        };
        verify(SettingsLogic.initialize(bar, {
            "overrides": {
                "terminal": "editor"
            },
            "reducedMotion": true
        }));
        verify(!bar.reducedMotion);
        verify(!bar.tilelaneTranslucent);
        verify(bar.tilelaneSuperStart);
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
            "tilelaneSettingsVersion": 2,
            "tilelanePins": ["future"]
        };
        verify(!SettingsLogic.initialize(bar, {
            "overrides": {},
            "reducedMotion": false
        }));
        compare(bar.tilelaneSettingsVersion, 2);
        compare(bar.tilelanePins, ["future"]);
    }

    function test_tipDismissalIsStoredPerId() {
        const values = SettingsLogic.read({
            "tilelaneDismissedTips": ["dock-overlap", "dock-overlap", "future-change"]
        });
        compare(values.tilelaneDismissedTips, ["dock-overlap", "future-change"]);
        compare(SettingsLogic.field("tilelaneDismissedTips", ["dock-overlap"]), ["dock-overlap"]);
        const invalid = SettingsLogic.read({
            "tilelaneDismissedTips": ["../../../bad"]
        });
        compare(invalid.tilelaneDismissedTips, []);
        compare(invalid.errors.length, 1);
    }

    function test_translucentBarPreference() {
        compare(SettingsLogic.read({}).tilelaneTranslucent, true);
        compare(SettingsLogic.field("tilelaneTranslucent", true), true);
        compare(SettingsLogic.read({
            tilelaneTranslucent: true
        }).tilelaneTranslucent, true);
        compare(SettingsLogic.read({
            tilelaneTranslucent: false
        }).tilelaneTranslucent, false);
        const invalid = SettingsLogic.read({
            tilelaneTranslucent: "yes",
            reducedMotion: true
        });
        compare(invalid.tilelaneTranslucent, true);
        compare(invalid.reducedMotion, true);
        compare(invalid.errors.length, 1);
    }

    function test_superStartPreference() {
        compare(SettingsLogic.read({}).tilelaneSuperStart, false);
        compare(SettingsLogic.field("tilelaneSuperStart", true), true);
        compare(SettingsLogic.field("tilelaneSuperStart", false), false);
        compare(SettingsLogic.read({
            tilelaneSuperStart: true
        }).tilelaneSuperStart, true);
        compare(SettingsLogic.read({
            tilelaneSuperStart: false
        }).tilelaneSuperStart, false);
        const invalid = SettingsLogic.read({
            tilelaneSuperStart: "yes",
            tilelaneTranslucent: false
        });
        compare(invalid.tilelaneSuperStart, false);
        compare(invalid.tilelaneTranslucent, false);
        compare(invalid.errors.length, 1);
    }

    name: "SettingsLogic"
}
