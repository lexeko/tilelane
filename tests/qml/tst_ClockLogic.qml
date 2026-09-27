import QtQuick
import QtTest
import "../../qml/ClockLogic.js" as ClockLogic

TestCase {
    name: "ClockLogic"

    function test_weekFormat_data() {
        return [
            {
                "tag": "reported date",
                "date": new Date(2026, 8, 26),
                "week": "W39"
            },
            {
                "tag": "Sunday",
                "date": new Date(2026, 8, 27),
                "week": "W39"
            },
            {
                "tag": "Monday",
                "date": new Date(2026, 8, 28),
                "week": "W40"
            },
            {
                "tag": "previous ISO year",
                "date": new Date(2021, 0, 1),
                "week": "W53"
            },
            {
                "tag": "next ISO year",
                "date": new Date(2024, 11, 30),
                "week": "W01"
            },
            {
                "tag": "first Monday",
                "date": new Date(2021, 0, 4),
                "week": "W01"
            }
        ];
    }

    function test_weekFormat(data) {
        compare(ClockLogic.formatDateTime(data.date, "'W'ww"), data.week);
        compare(ClockLogic.formatDateTime(data.date, "d MMMM 'W'ww yyyy"), Qt.formatDateTime(data.date, "d MMMM ") + data.week + Qt.formatDateTime(data.date, " yyyy"));
    }

    function test_regularFormatsAreUnchanged() {
        const date = new Date(2026, 8, 26, 21, 45);
        for (const format of ["h:mm AP", "dddd HH:mm", "yyyy-MM-dd HH:mm"])
            compare(ClockLogic.formatDateTime(date, format), Qt.formatDateTime(date, format));
    }
}
