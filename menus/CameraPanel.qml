import QtQuick
import Quickshell
import ".."
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell

// Camera preview shown inside the launcher pill (mode "camera").
Item {
    id: cam

    readonly property bool wanted: OverlayController.launcherOpen && OverlayController.launcherMode === "camera"
    property bool mirror: true
    property int camIndex: 0          // index into devices.videoInputs (0 = the default colour camera)
    property string status: ""

    // the whole pill is the video: 16:9, no header or footer
    readonly property int previewW: 480
    readonly property int previewH: 270
    readonly property real contentW: previewW
    readonly property real contentH: previewH
    implicitWidth: contentW
    implicitHeight: contentH

    MediaDevices {
        id: devices
    }

    // The camera only exists while the menu is open, so the device is released (and the privacy
    // light goes off) the moment it closes. Qt keeps the device open if you only set active=false.
    Loader {
        id: session
        active: cam.wanted && devices.videoInputs.length > 0
        sourceComponent: Item {
            property alias capture: cap
            property alias camera: camera
            CaptureSession {
                camera: Camera {
                    id: camera
                    active: true
                    cameraDevice: devices.videoInputs[Math.min(cam.camIndex, devices.videoInputs.length - 1)]
                    onErrorOccurred: (err, msg) => {
                        cam.status = "Camera error: " + msg
                    }
                }
                imageCapture: ImageCapture {
                    id: cap
                    onImageSaved: (id, path) => {
                        cam.status = "Saved to " + path.replace(Quickshell.env("HOME"), "~")
                    }
                    onErrorOccurred: (id, err, msg) => {
                        cam.status = "Couldn't save: " + msg
                    }
                }
                videoOutput: preview
            }
        }
    }
    readonly property bool live: session.item !== null && session.item.camera.cameraStatus === Camera.ActiveStatus

    function snap() {
        if (!live)
            return
        const dir = Quickshell.env("HOME") + "/Pictures/Camera";
        Quickshell.execDetached(["mkdir", "-p", dir])
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
        flash.restart()
        session.item.capture.captureToFile(dir + "/Photo-" + stamp + ".jpg")
    }

    function handleKey(key) {
        if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
            snap()
            return true
        }
        if (key === Qt.Key_M) {
            mirror = !mirror
            return true
        }
        if ((key === Qt.Key_Left || key === Qt.Key_Right) && devices.videoInputs.length > 1) {
            const n = devices.videoInputs.length
            camIndex = (camIndex + (key === Qt.Key_Right ? 1 : n - 1)) % n
            return true
        }
        return false
    }

    onWantedChanged: if (wanted) {
                         status = ""
                         camIndex = 0
                     }

    // rounded video frame
    Item {
        id: frame
        x: 1
        y: 1
        width: parent.width - 2
        height: parent.height - 2

        Rectangle {
            anchors.fill: parent
            radius: 17
            color: "#0e1119"
        }

        Item {
            id: maskItem
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                radius: 17
            }
        }

        VideoOutput {
            id: preview
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            transform: Scale {
                origin.x: preview.width / 2
                xScale: cam.mirror ? -1 : 1
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskItem
            }
        }

        // shutter flash
        Rectangle {
            id: flashRect
            anchors.fill: parent
            radius: 17
            color: "white"
            opacity: 0
            NumberAnimation on opacity {
                id: flash
                running: false
                from: 0.85
                to: 0
                duration: 320
                easing.type: Easing.OutQuad
            }
        }

        // placeholder while the camera starts / is missing
        Text {
            anchors.centerIn: parent
            visible: devices.videoInputs.length === 0
            text: "No camera found"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }
}
