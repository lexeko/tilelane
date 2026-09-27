import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    id: root

    readonly property string testDir: Quickshell.env("TILELANE_PLACES_TEST_DIR")
    readonly property string snapshot: JSON.stringify({
        "available": places.gtkBookmarksAvailable,
        "places": places.pinnedPlaces
    })

    onSnapshotChanged: Qt.callLater(function () {
        output.setText(root.snapshot);
    })
    Component.onCompleted: output.setText(snapshot)

    PlacesModel {
        id: places

        gtkBookmarks.path: root.testDir + "/bookmarks"
        legacyBookmarks.path: root.testDir + "/legacy-bookmarks"
        userDirectories.path: root.testDir + "/user-dirs.dirs"
    }

    FileView {
        id: output

        path: root.testDir + "/state.json"
        printErrors: false
    }
}
