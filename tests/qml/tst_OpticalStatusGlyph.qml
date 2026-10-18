import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase
    name: "OpticalStatusGlyph"
    when: windowShown
    visible: true
    width: 80
    height: 80

    Rectangle {
        id: canvas
        anchors.fill: parent
        color: "black"

        OpticalStatusGlyph {
            id: glyph
            anchors.centerIn: parent
            anchors.alignWhenCentered: false
            fontFamily: "JetBrainsMono Nerd Font"
            color: "white"
        }
    }

    function test_renderedSizeAndCenter_data() {
        const symbols = {
            update: "\uf021",
            cloud: "\ue33d",
            sun: "\uf185",
            moon: "\uf186",
            bluetooth: "󰂯",
            bluetoothOff: "󰂲",
            network: "󰤨",
            networkOff: "󰤮",
            wired: "󰈀",
            audioQuiet: "",
            audioLoud: "",
            audioMuted: "",
            headphones: "󰋋",
            monitor: "󰍹",
            monitors: "󰍺",
            battery: "󰁹",
            batteryLow: "󰁺",
            charging: "󰂅",
            agents: "󱚣",
            unfamiliar: "\uf0f3"
        };
        const rows = [];
        [1, 1.25, 1.5, 2].forEach(scale => {
            Object.keys(symbols).forEach(name => rows.push({
                    tag: name + "@" + scale,
                    text: symbols[name],
                    scale: scale
                }));
        });
        return rows;
    }

    function test_renderedSizeAndCenter(data) {
        glyph.text = data.text;
        glyph.uiScale = data.scale;
        waitForRendering(canvas);
        const picture = grabImage(canvas);
        let left = picture.width;
        let top = picture.height;
        let right = -1;
        let bottom = -1;
        for (let y = 0; y < picture.height; y++) {
            for (let x = 0; x < picture.width; x++) {
                if (picture.red(x, y) > 64) {
                    left = Math.min(left, x);
                    right = Math.max(right, x);
                    top = Math.min(top, y);
                    bottom = Math.max(bottom, y);
                }
            }
        }
        verify(right >= left && bottom >= top, "Glyph must paint visible pixels");
        const dpr = picture.width / canvas.width;
        const extent = Math.max(right - left + 1, bottom - top + 1) / dpr;
        verify(Math.abs(extent - 12 * data.scale) <= 2, "Rendered extent " + extent + " must fit the shared icon size");
        verify(Math.abs((left + right + 1) / 2 - picture.width / 2) <= 1.5 * dpr, "Horizontal painted center");
        verify(Math.abs((top + bottom + 1) / 2 - picture.height / 2) <= 1.5 * dpr, "Vertical painted center");
    }
}
