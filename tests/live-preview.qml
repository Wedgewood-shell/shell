import QtQuick
import Quickshell
import Quickshell.Wayland
import "../native/build"

// Opt-in integration test: opens one real PipeWire stream, never takes a screenshot.
ShellRoot {
    PanelWindow {
        visible: true
        implicitWidth: 320
        implicitHeight: 200
        color: "#181d2e"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        LiveWindow {
            id: stream
            anchors.fill: parent
            windowId: Number(Quickshell.env("CAPTURE_TEST_WINDOW")) || -1
            output: Quickshell.env("CAPTURE_TEST_OUTPUT") || ""
            active: windowId > 0 || output !== ""
            onErrorChanged: if (error) console.error("FAIL: " + error)
        }
    }
    Timer {
        interval: 3500
        running: true
        onTriggered: {
            if (stream.ready && stream.frameCount > 0) {
                console.log("LIVE PREVIEW PASS: " + stream.frameCount + " frames")
                stream.active = false
            } else {
                console.error("FAIL: No live frames: " + stream.error)
            }
            finish.start()
        }
    }
    Timer {
        id: finish
        interval: 500
        onTriggered: Qt.quit()
    }
}
