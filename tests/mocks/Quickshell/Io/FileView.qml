import QtQml

QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool printErrors: true
    property bool atomicWrites: false
    property string contents: ""

    function setText(value) {
        contents = value;
    }

    signal loaded
    signal fileChanged
    signal loadFailed(var error)

    function reload() {
    }
    function text() {
        return "";
    }
}
