import QtQuick
import QtTest
import "../../qml/PlacesLogic.js" as PlacesLogic

TestCase {
    name: "PlacesLogic"

    function test_bookmarksPreserveFilesOrderLabelsAndDeduplicate() {
        const bookmarks = "file:///home/example/Documents Documents\nfile:///tmp/Notes%20Here\nfile:///tmp/Notes%20Here Duplicate\nsmb://server/share Team files\n";
        const userDirs = "XDG_DOCUMENTS_DIR=\"$HOME/Documents\"\n";
        const places = PlacesLogic.parseBookmarks(bookmarks, userDirs, "/home/example");
        compare(places.length, 3);
        compare(places[0].name, "Documents");
        compare(places[0].iconName, "folder-documents-symbolic");
        compare(places[1].name, "Notes Here");
        compare(places[2].name, "Team files");
    }

    function test_twoGroupsAreSeparatedOnlyWhenFilesHasPins() {
        const primary = [
            {
                "name": "Home"
            }
        ];
        compare(PlacesLogic.combined(primary, []).length, 1);
        const combined = PlacesLogic.combined(primary, [
            {
                "name": "Documents"
            }
        ]);
        compare(combined.length, 3);
        verify(combined[1].divider);
        compare(combined[2].name, "Documents");
    }

    function test_malformedBookmarksAreIgnored() {
        const places = PlacesLogic.parseBookmarks("not-a-uri\n# comment\n\n", "", "/home/example");
        compare(places.length, 0);
    }
}
