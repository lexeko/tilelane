import "../../qml/StartLogic.js" as StartLogic
import QtQuick
import QtTest

TestCase {
    readonly property var entries: [
        {
            "id": "org.example.Code.desktop",
            "name": "Code Editor",
            "genericName": "Text Editor",
            "icon": "code",
            "keywords": ["source", "programming"]
        },
        {
            "id": "org.example.Browser.desktop",
            "name": "Browser",
            "genericName": "Web Browser",
            "icon": "browser"
        },
        {
            "id": "hidden.desktop",
            "name": "Hidden",
            "noDisplay": true
        }
    ]

    function test_indexIsStableAndExcludesHiddenEntries() {
        const index = StartLogic.indexEntries(entries);
        compare(index.length, 2);
        compare(index[0].name, "Browser");
        compare(index[1].name, "Code Editor");
    }

    function test_configuredHidesNormalizeDesktopSuffixesAndComments() {
        const hidden = StartLogic.idSet("# packaged launcher hides\norg.example.Browser.desktop\n\n");
        const index = StartLogic.indexEntries(entries, hidden);
        compare(index.length, 1);
        compare(index[0].name, "Code Editor");
    }

    function test_desktopFileIdRestoresQuickshellSuffix() {
        compare(StartLogic.desktopFileId("foot"), "foot.desktop");
        compare(StartLogic.desktopFileId("org.example.App"), "org.example.App.desktop");
        compare(StartLogic.desktopFileId("org.telegram.desktop"), "org.telegram.desktop.desktop");
        compare(StartLogic.desktopFileId("  "), "");
    }

    function test_searchFiltering() {
        const index = StartLogic.indexEntries(entries);
        compare(StartLogic.filter(index, "programming")[0].id, "org.example.Code.desktop");
        compare(StartLogic.filter(index, "web")[0].name, "Browser");
        compare(StartLogic.filter(index, "missing").length, 0);
    }

    function test_pinsLeadNextOpeningInStoredOrder() {
        const index = StartLogic.indexEntries(entries);
        const ordered = StartLogic.pinnedFirst(index, ["org.example.Code.desktop", "missing.desktop"]);
        compare(ordered.length, 2);
        compare(ordered[0].id, "org.example.Code.desktop");
        compare(ordered[1].id, "org.example.Browser.desktop");
        compare(index[0].id, "org.example.Browser.desktop");
    }

    function test_keyboardSelectionIsClamped() {
        compare(StartLogic.movedIndex(-1, 1, 4), 1);
        compare(StartLogic.movedIndex(3, 1, 4), 3);
        compare(StartLogic.movedIndex(0, -1, 4), 0);
        compare(StartLogic.movedIndex(0, 1, 0), -1);
    }

    function test_malformedAndMissingEntryFieldsUseSafeFallbacks() {
        const index = StartLogic.indexEntries([null,
            {
                "name": "Missing ID"
            },
            {
                "id": "fallback.desktop",
                "name": "",
                "icon": ""
            }
        ]);
        compare(index.length, 1);
        compare(index[0].name, "fallback.desktop");
        compare(index[0].icon, "application-x-executable");
        compare(StartLogic.filter(index, "fallback").length, 1);
    }

    name: "StartLogic"
}
