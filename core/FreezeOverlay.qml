import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Frozen picture of the desktop drawn over everything while a region screenshot is
// being selected (see scripts/capture-run). Never takes keyboard focus or input.
PanelWindow {
    id: fw
    required property var modelData
    screen: modelData

    readonly property bool active: FreezeController.path !== ""
    readonly property bool loaded: !active || img.status === Image.Ready
    onLoadedChanged: FreezeController.report(modelData.name, loaded)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: active
    WlrLayershell.namespace: "screenshot-freeze"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Image {
        id: img
        anchors.fill: parent
        source: fw.active ? "file://" + FreezeController.path : ""
        cache: false
        asynchronous: true
        smooth: true
        // The picture covers the whole layout; show this output's part of it.
        sourceClipRect: Qt.rect((modelData.x - FreezeController.originX) * FreezeController.scale, (modelData.y - FreezeController.originY) * FreezeController.scale, modelData.width * FreezeController.scale, modelData.height * FreezeController.scale)
    }
}
