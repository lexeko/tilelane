import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase

    name: "TrayIconRendering"
    when: windowShown
    visible: true
    width: 64
    height: 64

    Rectangle {
        id: background

        anchors.fill: parent
        color: "black"
    }

    TrayIcon {
        id: icon

        source: Qt.resolvedUrl("fixtures/badge-symbolic")
        iconSize: 64
        foreground: "#c0c0c0"
    }

    function sample(picture, x, y) {
        return picture.pixel(Math.floor(picture.width * x), Math.floor(picture.height * y));
    }

    function test_symbolicColors_data() {
        return [
            {
                "tag": "dark theme",
                "foreground": "#c0c0c0",
                "background": "black"
            },
            {
                "tag": "light theme",
                "foreground": "#202020",
                "background": "white"
            }
        ];
    }

    function test_symbolicColors(data) {
        icon.source = Qt.resolvedUrl("fixtures/badge-symbolic");
        icon.foreground = data.foreground;
        background.color = data.background;
        tryVerify(function () {
            const picture = grabImage(testCase);
            return sample(picture, 0.25, 0.25) == icon.foreground;
        });
        const picture = grabImage(testCase);
        compare(sample(picture, 0.75, 0.25), Qt.rgba(242 / 255, 60 / 255, 52 / 255, 1));
        compare(sample(picture, 0.25, 0.75), Qt.rgba(32 / 255, 128 / 255, 224 / 255, 1));
        // A translucent badge keeps its hue and blends with the background.
        const translucent = sample(picture, 0.75, 0.75);
        verify(translucent.g > translucent.b && translucent.b > translucent.r);
        const expectedGreen = 0.5 * (192 / 255 + background.color.g);
        verify(Math.abs(translucent.g - expectedGreen) < 0.02);
    }

    function test_fullColorIconIsUntouched() {
        icon.source = Qt.resolvedUrl("fixtures/badge.svg");
        tryVerify(function () {
            return sample(grabImage(testCase), 0.25, 0.25) == Qt.rgba(1, 1, 1, 1);
        });
        compare(sample(grabImage(testCase), 0.75, 0.25), Qt.rgba(242 / 255, 60 / 255, 52 / 255, 1));
    }
}
