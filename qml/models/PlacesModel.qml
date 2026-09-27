pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../PlacesLogic.js" as PlacesLogic

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    property string gtkBookmarksText: ""
    property string legacyBookmarksText: ""
    property string userDirsText: ""
    property bool gtkBookmarksAvailable: false
    readonly property var primaryPlaces: [
        {
            "name": "Home",
            "uri": home,
            "iconName": "user-home-symbolic"
        },
        {
            "name": "Recent",
            "uri": "recent:///",
            "iconName": "document-open-recent-symbolic"
        },
        {
            "name": "Starred",
            "uri": "starred:///",
            "iconName": "starred-symbolic"
        },
        {
            "name": "Network",
            "uri": "network:///",
            "iconName": "network-computer-symbolic"
        },
        {
            "name": "Trash",
            "uri": "trash:///",
            "iconName": "user-trash-symbolic"
        }
    ]
    readonly property var pinnedPlaces: PlacesLogic.parseBookmarks(gtkBookmarksAvailable ? gtkBookmarksText : legacyBookmarksText, userDirsText, home)
    readonly property var places: PlacesLogic.combined(primaryPlaces, pinnedPlaces)

    property FileView gtkBookmarks: FileView {
        path: root.configHome + "/gtk-3.0/bookmarks"
        watchChanges: true
        printErrors: false

        onLoaded: {
            root.gtkBookmarksAvailable = true;
            root.gtkBookmarksText = text();
        }
        onFileChanged: reload()
        onLoadFailed: {
            root.gtkBookmarksAvailable = false;
            root.gtkBookmarksText = "";
        }
    }

    property FileView legacyBookmarks: FileView {
        path: root.home + "/.gtk-bookmarks"
        watchChanges: true
        printErrors: false

        onLoaded: root.legacyBookmarksText = text()
        onFileChanged: reload()
        onLoadFailed: root.legacyBookmarksText = ""
    }

    property FileView userDirectories: FileView {
        path: root.configHome + "/user-dirs.dirs"
        watchChanges: true
        printErrors: false

        onLoaded: root.userDirsText = text()
        onFileChanged: reload()
        onLoadFailed: root.userDirsText = ""
    }
}
