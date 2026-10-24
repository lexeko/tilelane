import QtQuick
import QtTest
import "../../qml/components"
import "../../qml/TrayIconSource.js" as TrayIconSource

TestCase {
    id: testCase

    name: "TrayIconSourceBoundary"
    when: windowShown
    visible: true
    width: 64
    height: 64

    TrayIcon {
        id: icon

        source: ""
        iconSize: 32
        foreground: "white"
    }

    function test_roamUnreadBadge() {
        const badge = findChild(icon, "roamUnreadBadge");
        const probe = findChild(icon, "roamBadgeProbe");
        verify(badge);
        verify(probe);

        icon.trayItemId = "Roam_status_icon_1";
        icon.source = "image://qspixmap/current-roam-pixmap";
        compare(icon.badgeReady, true);
        compare(icon.roamPixmap, true);
        tryCompare(probe, "running", true);
        compare(badge.visible, false);

        probe.stdout.text = "1\n";
        probe.stdout.streamFinished();
        compare(badge.visible, true);

        probe.running = false;
        icon.source = "image://qspixmap/next-roam-pixmap";
        tryCompare(probe, "running", true);
        probe.stdout.text = "0\n";
        probe.stdout.streamFinished();
        compare(badge.visible, false);

        icon.source = "image://qsimage/older-roam-pixmap";
        compare(icon.roamPixmap, true);

        icon.source = "image://icon/roam";
        tryCompare(badge, "visible", false);
        tryCompare(icon, "roamUnread", false);
    }

    function test_sources_data() {
        const generic = "image://icon/application-x-executable";
        const roam = "image://icon/roam?fallback=application-x-executable";
        const badge = "image://icon/badge?fallback=application-x-executable";
        const symbolic = "image://icon/badge-symbolic?fallback=application-x-executable";
        return [
            {
                tag: "theme name",
                input: "image://icon/badge",
                expected: badge
            },
            {
                tag: "symbolic",
                input: "image://icon/badge-symbolic",
                expected: symbolic
            },
            {
                tag: "theme path removed",
                input: "image://icon/badge?path=/tmp/benign",
                expected: badge
            },
            {
                tag: "symbolic path removed",
                input: "image://icon/badge-symbolic?path=/tmp/benign",
                expected: symbolic
            },
            {
                tag: "fallback replaced",
                input: "image://icon/badge?fallback=/tmp/benign.svg",
                expected: badge
            },
            {
                tag: "query combination removed",
                input: "image://icon/badge?fallback=other?path=/tmp/benign",
                expected: badge
            },
            {
                tag: "query escaped separators",
                input: "image://icon/badge?path=%2Ftmp%2Fbenign",
                expected: badge
            },
            {
                tag: "namespaced name",
                input: "image://icon/org.example.App_1",
                expected: "image://icon/org.example.App_1?fallback=application-x-executable"
            },
            {
                tag: "empty",
                input: "",
                expected: generic
            },
            {
                tag: "empty name",
                input: "image://icon/?path=/tmp/benign",
                expected: generic
            },
            {
                tag: "absolute name",
                input: "image://icon//tmp/benign.svg",
                expected: generic
            },
            {
                tag: "relative path",
                input: "image://icon/../benign.svg",
                expected: generic
            },
            {
                tag: "nested path",
                input: "image://icon/subdir/benign.svg",
                expected: generic
            },
            {
                tag: "escaped slash",
                input: "image://icon/%2Ftmp%2Fbenign.svg",
                expected: generic
            },
            {
                tag: "double escaping",
                input: "image://icon/%252Ftmp%252Fbenign.svg",
                expected: generic
            },
            {
                tag: "escaped dot",
                input: "image://icon/%2E%2E/benign.svg",
                expected: generic
            },
            {
                tag: "backslash",
                input: "image://icon/subdir\\benign.svg",
                expected: generic
            },
            {
                tag: "fragment",
                input: "image://icon/badge#other",
                expected: generic
            },
            {
                tag: "colon",
                input: "image://icon/file:benign.svg",
                expected: generic
            },
            {
                tag: "space",
                input: "image://icon/badge other",
                expected: generic
            },
            {
                tag: "newline",
                input: "image://icon/badge\n",
                expected: generic
            },
            {
                tag: "nul",
                input: "image://icon/badge\u0000",
                expected: generic
            },
            {
                tag: "opaque provider",
                input: "image://qsimage/1/2",
                expected: generic
            },
            {
                tag: "current opaque pixmap provider",
                input: "image://qspixmap/1/2",
                expected: generic
            },
            {
                tag: "Roam pixmap uses installed icon",
                input: "image://qsimage/1/2",
                itemId: "Roam_status_icon_1",
                expected: roam
            },
            {
                tag: "Roam named icon remains named",
                input: "image://icon/badge",
                itemId: "Roam_status_icon_2",
                expected: badge
            },
            {
                tag: "Roam identity cannot forward a path",
                input: "image://icon/../benign.svg",
                itemId: "Roam_status_icon_1",
                expected: roam
            },
            {
                tag: "similar identity remains generic",
                input: "image://qsimage/1/2",
                itemId: "Roam_status_icon_1_extra",
                expected: generic
            },
            {
                tag: "other pixmap remains generic",
                input: "image://qsimage/1/2",
                itemId: "Other_status_icon_1",
                expected: generic
            },
            {
                tag: "unknown provider",
                input: "image://other/badge",
                expected: generic
            },
            {
                tag: "file URL",
                input: String(Qt.resolvedUrl("../render/fixtures/badge.svg")),
                expected: generic
            },
            {
                tag: "relative file",
                input: "../render/fixtures/badge.svg",
                expected: generic
            },
            {
                tag: "HTTPS URL",
                input: "https://example.invalid/benign.svg",
                expected: generic
            },
            {
                tag: "data URL",
                input: "data:image/svg+xml,<svg/>",
                expected: generic
            },
            {
                tag: "long name",
                input: "image://icon/" + "a".repeat(129),
                expected: generic
            },
            {
                tag: "long query",
                input: "image://icon/badge?path=" + "a".repeat(4096),
                expected: generic
            }
        ];
    }

    function test_sources(data) {
        // Reset first so every case exercises a new request, including safe ->
        // rejected transitions. Both providers record requests at the decoder.
        const image = findChild(icon, "trayImage");
        image.cache = false;
        icon.trayItemId = data.itemId || "";
        icon.source = "image://icon/reset";
        tryCompare(image, "status", Image.Ready);
        const previousCount = iconRequests.count;
        icon.source = data.input;
        tryVerify(function () {
            return iconRequests.count > previousCount;
        });
        tryCompare(image, "status", Image.Ready);
        compare(String(image.source), data.expected);
        compare(iconRequests.last, data.expected.slice("image://".length));
        compare(icon.symbolic, data.expected.indexOf("badge-symbolic?") !== -1);
        compare(icon.width, 32);
        compare(icon.height, 32);
    }

    function test_nonStringsFailClosed() {
        for (const source of [null, undefined, 42,
            {},
            []])
            compare(TrayIconSource.themeSource(source), "image://icon/application-x-executable");
    }
}
