pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    readonly property string fontFamily: "FiraCode Nerd Font"
    readonly property color foreground: "#d7deee"
    readonly property color text: "#f4f6ff"
    readonly property color surface: "#f71a1f2d"
    readonly property color border: "#4daabef0"
    readonly property color highlight: "#8fa8ff"
    readonly property color muted: "#7d88aa"
    readonly property color success: "#91e0cb"
    readonly property color warning: "#ffd27d"
    readonly property color danger: "#ff8585"
    readonly property int islandBaseWidth: 300
    readonly property int islandHeliumWidth: islandBaseWidth * 2
    readonly property int windowTitleMaxWidth: 400
    readonly property real workspacePreviewScale: 0.4
    readonly property real workspaceIconScale: 1.5
    readonly property int islandFadeDuration: 120
    readonly property int barHeight: 42
    readonly property int topMargin: 8
    // Compact bar, while a window spans the output width (maximized/fullscreen):
    // a flush full-width strip with modules scaled down.
    readonly property real compactScale: 0.9
    readonly property int compactBarHeight: 40
    readonly property int compactPadding: 10
    readonly property color compactBackground: Qt.rgba(0x1a / 255, 0x1f / 255, 0x2d / 255, 0.85)
    readonly property int compactDuration: 260
    // Top of a scaled module when centred in the compact strip.
    readonly property real compactTop: (compactBarHeight - barHeight * compactScale) / 2
    readonly property int closedRadius: 12
    readonly property int openRadius: 18
    readonly property int fadeDuration: 180
    readonly property int morphDuration: 400
    function cp(n) {
        return String.fromCodePoint(n)
    }
}
