import QtQml

QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool printErrors: true

    signal loaded
    signal fileChanged
    signal loadFailed(var error)

    function reload() {
    }
    function text() {
        return "";
    }
}
