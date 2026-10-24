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

    TextMetrics {
        id: standardMetrics
        font.family: glyph.fontFamily
        font.pixelSize: Math.max(1, Math.round(13 * glyph.uiScale))
        text: glyph.text
    }

    function init() {
        glyph.opticalSizing = false;
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
            audioMedium: "",
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
        const paintedWidth = (right - left + 1) / dpr;
        const paintedHeight = (bottom - top + 1) / dpr;
        verify(Math.abs(paintedWidth - standardMetrics.tightBoundingRect.width) <= 2, "Glyph width must retain the shared font scale");
        verify(Math.abs(paintedHeight - standardMetrics.tightBoundingRect.height) <= 2, "Glyph height must retain the shared font scale");
        verify(Math.abs((left + right + 1) / 2 - picture.width / 2) <= 1.5 * dpr, "Horizontal painted center");
        const expectedCenterY = (glyph.y + glyph.paintedCenterY) * dpr;
        verify(Math.abs((top + bottom + 1) / 2 - expectedCenterY) <= 1.5 * dpr, "Painted position follows the common font baseline");
    }

    function test_stateChangesKeepScaleAndBaseline_data() {
        return [1, 1.25, 1.5, 2].map(scale => ({
                    tag: String(scale),
                    scale: scale
                }));
    }

    function test_stateChangesKeepScaleAndBaseline(data) {
        glyph.uiScale = data.scale;
        glyph.text = "";
        waitForRendering(canvas);
        const baseline = glyph.baselineY;
        const fontSize = glyph.renderedFontSize;
        const frameWidth = glyph.width;
        // Exercise shrinking as well as growing glyphs, with no remembered state.
        ["", "", "", "", "󰤨", "󰤮", "\uf021", "\uf0f3", ""].forEach(text => {
            glyph.text = text;
            waitForRendering(canvas);
            compare(glyph.renderedFontSize, fontSize);
            fuzzyCompare(glyph.baselineY, baseline, 0.01);
            compare(glyph.width, frameWidth);
            fuzzyCompare(glyph.paintedCenterX, frameWidth / 2, 0.01);
        });
    }

    function test_actualWeatherGlyphsKeepOpticalSize_data() {
        // Omarchy panels/weather/Model.js iconForCode: day and night outputs.
        const symbols = {
            sunny: "\ue30d",
            clearNight: "\ue32b",
            cloudy: "\ue33d",
            partlyCloudy: "\ue302",
            partlyCloudyNight: "\ue32e",
            fog: "\ue313",
            fogNight: "\ue346",
            showers: "\ue308",
            showersNight: "\ue333",
            snowShowers: "\ue30a",
            snowShowersNight: "\ue327",
            sleet: "\ue3ad",
            thunder: "\ue31d",
            rain: "\ue318",
            snow: "\ue31a"
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

    function test_actualWeatherGlyphsKeepOpticalSize(data) {
        glyph.opticalSizing = true;
        glyph.uiScale = data.scale;
        glyph.text = data.text;
        fuzzyCompare(Math.max(glyph.paintedWidth, glyph.paintedHeight), 13 * data.scale, 0.01);
        waitForRendering(canvas);
        const picture = grabImage(canvas);
        let left = picture.width, top = picture.height, right = -1, bottom = -1;
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
        verify(right >= left && bottom >= top);
        const pixelsPerUnit = picture.width / canvas.width * data.scale;
        const width = (right - left + 1) / pixelsPerUnit;
        const height = (bottom - top + 1) / pixelsPerUnit;
        verify(Math.max(width, height) >= 11, "Weather must fill most of its optical canvas: " + Math.max(width, height));
        verify(Math.max(width, height) <= 14, "Weather must fit within its optical canvas");
        verify(Math.abs((left + right + 1) / 2 - picture.width / 2) <= 1.5 * pixelsPerUnit);
        verify(Math.abs((top + bottom + 1) / 2 - picture.height / 2) <= 1.5 * pixelsPerUnit);

        // Compare weather with a neighboring fixed-font icon, not only with
        // its own sizing formula, which could consistently produce oversizing.
        glyph.opticalSizing = false;
        glyph.text = "\uf021";
        waitForRendering(canvas);
        const reference = grabImage(canvas);
        left = reference.width;
        top = reference.height;
        right = -1;
        bottom = -1;
        for (let y = 0; y < reference.height; y++) {
            for (let x = 0; x < reference.width; x++) {
                if (reference.red(x, y) > 64) {
                    left = Math.min(left, x);
                    right = Math.max(right, x);
                    top = Math.min(top, y);
                    bottom = Math.max(bottom, y);
                }
            }
        }
        const referenceExtent = Math.max(right - left + 1, bottom - top + 1) / pixelsPerUnit;
        verify(Math.abs(Math.max(width, height) - referenceExtent) <= 3.5, "Weather extent " + Math.max(width, height) + " versus neighboring icon " + referenceExtent);
    }
}
