import "../../qml/AppIdentity.js" as AppIdentity
import QtQuick
import QtTest

TestCase {
    readonly property var entries: [
        {
            "id": "org.example.Editor",
            "name": "Editor",
            "icon": "editor",
            "startupClass": "ExampleEditor"
        },
        {
            "id": "browser.desktop",
            "name": "Browser",
            "icon": "browser",
            "startupClass": "BrowserClass"
        }
    ]

    function test_precedenceUsesExplicitOverrideThenIdsThenStartupClass() {
        let record = {
            "appId": "alias",
            "className": "ExampleEditor",
            "initialClass": ""
        };
        compare(AppIdentity.findEntry(entries, record, {
            "alias": "browser.desktop"
        }).id, "browser.desktop");
        compare(AppIdentity.findEntry(entries, record, ({})).id, "org.example.Editor");
        record = {
            "desktopEntryId": "org.example.Editor",
            "appId": "browser",
            "className": ""
        };
        compare(AppIdentity.findEntry(entries, record, ({})).id, "org.example.Editor");
        record.desktopEntryId = "";
        compare(AppIdentity.findEntry(entries, record, ({})).id, "browser.desktop");
    }

    function test_applicationIdentityIsStable() {
        const record = {
            "address": "0x1",
            "appId": "Browser",
            "className": "",
            "initialClass": ""
        };
        const resolved = AppIdentity.identity(entries[1], record);
        compare(resolved.desktopId, "browser.desktop");
        compare(resolved.name, "Browser");
        compare(resolved.icon, "browser");
        compare(AppIdentity.identity(null, record).name, "Browser");
    }

    function test_terminalChildResolvesMenuDesktopEntry() {
        const library = entries.concat([
            {
                "id": "foot",
                "name": "Foot",
                "icon": "foot",
                "command": ["foot"]
            },
            {
                "id": "cliamp",
                "name": "cliamp",
                "icon": "cliamp",
                "runInTerminal": true,
                "command": ["cliamp"]
            }
        ]);
        const resolved = AppIdentity.findEntry(library, {
            "appId": "foot",
            "terminalPrograms": "[\"cliamp\"]"
        }, ({}));
        compare(resolved.id, "cliamp");
        compare(AppIdentity.identity(resolved, {}).icon, "cliamp");
        compare(AppIdentity.findEntry(library, {
            "appId": "foot",
            "terminalPrograms": "[\"bash\"]"
        }, ({})).id, "foot");
    }

    function test_omarchyWebAppClassResolvesMenuDesktopEntry() {
        const library = entries.concat([
            {
                "id": "YouTube",
                "name": "YouTube",
                "icon": "youtube",
                "command": ["omarchy-launch-webapp", "https://youtube.com/"]
            }
        ]);
        const resolved = AppIdentity.findEntry(library, {
            "appId": "brave-youtube.com__-Default"
        }, ({}));
        compare(resolved.id, "YouTube");
        compare(AppIdentity.identity(resolved, {}).icon, "youtube");
        compare(AppIdentity.findEntry(library, {
            "appId": "browser"
        }, ({})).id, "browser.desktop");
    }

    function test_floatingLaunchMetadataAndControlModifier() {
        verify(AppIdentity.controlPressed(Qt.ControlModifier));
        verify(AppIdentity.controlPressed(Qt.ControlModifier | Qt.ShiftModifier));
        verify(!AppIdentity.controlPressed(Qt.ShiftModifier));
        compare(AppIdentity.expectedWindowId(entries[0]), "ExampleEditor");
        compare(AppIdentity.expectedWindowId({
            "id": "fallback.desktop"
        }), "fallback.desktop");
        compare(AppIdentity.expectedWindowId(null), "");
    }

    function test_reverseDnsWindowIdResolvesShortMenuEntry() {
        const library = entries.concat([
            {
                "id": "t3code",
                "name": "T3 Code",
                "icon": "t3code",
                "startupClass": "t3code"
            }
        ]);
        const resolved = AppIdentity.findEntry(library, {
            "appId": "com.t3tools.T3Code",
            "className": "com.t3tools.T3Code"
        }, ({}));
        compare(resolved.id, "t3code");
        compare(AppIdentity.identity(resolved, {}).icon, "t3code");
    }

    function test_ambiguousSpecializedIdentitiesFallBackToHost() {
        const terminalLibrary = entries.concat([
            {
                "id": "foot",
                "command": ["foot"]
            },
            {
                "id": "PlayerOne",
                "runInTerminal": true,
                "command": ["player"]
            },
            {
                "id": "PlayerTwo",
                "runInTerminal": true,
                "command": ["player", "--alternate"]
            }
        ]);
        compare(AppIdentity.findEntry(terminalLibrary, {
            "appId": "foot",
            "terminalPrograms": ["player"]
        }, ({})).id, "foot");
        const webLibrary = entries.concat([
            {
                "id": "Mail",
                "command": ["omarchy-launch-webapp", "https://example.com/mail"]
            },
            {
                "id": "Calendar",
                "command": ["omarchy-launch-webapp", "https://example.com/calendar"]
            }
        ]);
        compare(AppIdentity.findEntry(webLibrary, {
            "appId": "brave-example.com__-Default"
        }, ({})), null);
    }

    function test_eachWindowProducesOneOrderedTask() {
        const records = [
            {
                "address": "0x1",
                "title": "First",
                "appId": "Editor",
                "active": false,
                "urgent": true,
                "minimized": true,
                "fullscreen": false,
                "orderKey": 4
            },
            {
                "address": "0x2",
                "title": "Second",
                "appId": "Editor",
                "active": true,
                "urgent": false,
                "minimized": false,
                "fullscreen": true,
                "orderKey": 5
            },
            {
                "address": "0x3",
                "title": "Browser",
                "appId": "Browser",
                "active": false,
                "urgent": false,
                "minimized": false,
                "fullscreen": false,
                "orderKey": 2
            }
        ];
        const tasks = AppIdentity.taskRecords(records, function (record) {
            return AppIdentity.identity(record.appId === "Editor" ? entries[0] : entries[1], record);
        });
        compare(tasks.length, 3);
        compare(tasks[0].address, "0x3");
        compare(tasks[1].address, "0x1");
        compare(tasks[2].address, "0x2");
        compare(tasks[1].desktopId, "org.example.Editor");
        compare(tasks[2].desktopId, "org.example.Editor");
        verify(tasks[1].urgent);
        verify(tasks[1].minimized);
        verify(tasks[2].active);
        verify(tasks[2].fullscreen);
    }

    name: "AppIdentity"
}
