import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "qml/components"

ShellRoot {
    id: root

    ListModel {
        id: tasks
    }

    QtObject {
        id: pins
        property var pins: []
        property int revision: 0
    }

    QtObject {
        id: catalog
        property int indexRevision: 0
        function iconSource(name) {
            return "";
        }
        function presentationForId(id) {
            return {
                name: id
            };
        }
    }

    Window {
        visible: true
        width: 800
        height: 100
        TaskLane {
            id: lane
            width: 700
            height: 44
            sectionGap: 12
            model: tasks
            actions: null
            applicationCatalog: catalog
            pinnedApplications: pins
            bar: null
        }
    }

    IpcHandler {
        target: "test.tasks"
        function configure(width: real, titles: string, scale: real, pinned: int): void {
            lane.width = width;
            lane.uiScale = scale;
            pins.pins = Array.from({
                length: pinned
            }, (_, i) => "pin" + i);
            const values = JSON.parse(decodeURIComponent(titles));
            while (tasks.count > values.length)
                tasks.remove(tasks.count - 1);
            for (let i = 0; i < values.length; i++) {
                if (i < tasks.count) {
                    tasks.setProperty(i, "title", values[i]);
                } else {
                    tasks.append({
                        address: "0x" + (i + 1),
                        title: values[i],
                        appId: "test",
                        desktopId: "test",
                        iconName: "",
                        active: false,
                        urgent: false,
                        minimized: false,
                        fullscreen: false,
                        maximized: false,
                        floating: false
                    });
                }
            }
        }
        function state(): string {
            return JSON.stringify(lane.sizingState());
        }
        function scrollToStart(): void {
            function findViewport(item) {
                if (item.objectName === "taskViewport")
                    return item;
                for (const child of item.children) {
                    const found = findViewport(child);
                    if (found)
                        return found;
                }
                return null;
            }
            findViewport(lane).contentX = 0;
        }
        function insert(index: int, address: string): void {
            const record = Object.assign({}, tasks.get(0));
            record.address = address;
            tasks.insert(index, record);
        }
        function remove(index: int): void {
            tasks.remove(index);
        }
        function transientTask(): void {
            const record = Object.assign({}, tasks.get(0));
            record.address = "0xclosed";
            tasks.append(record);
            tasks.remove(tasks.count - 1);
        }
        function move(from: int, to: int): void {
            tasks.move(from, to, 1);
        }
        function focus(index: int): void {
            for (let i = 0; i < tasks.count; i++)
                tasks.setProperty(i, "active", i === index);
        }
    }
}
