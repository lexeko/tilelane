import QtQuick
import Quickshell
import Quickshell.Io
import "qml/models"

ShellRoot {
    id: root

    readonly property string snapshot: JSON.stringify({
        native: strings.usingNative,
        later: strings.t("tips.later"),
        title: strings.t("tips.dock.title"),
        missing: strings.t("unknown.key"),
        fallback: strings.t("unknown.key", "Fallback"),
        emptyFallback: strings.t("unknown.key", ""),
        choice: strings.t("tips.dock.choiceAccessibility").arg("Left")
    })

    onSnapshotChanged: Qt.callLater(function () {
        output.setText(root.snapshot);
    })
    Component.onCompleted: output.setText(snapshot)

    PluginTranslations {
        id: strings
        directory: Qt.resolvedUrl("i18n")
    }

    FileView {
        id: output
        path: Quickshell.shellPath("state.json")
        printErrors: false
    }
}
