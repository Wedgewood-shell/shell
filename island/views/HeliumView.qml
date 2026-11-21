import QtQuick
import Quickshell
import "../.."

// Base state while a Helium window is focused: the address bar's URL.
Item {
    id: view
    property bool active: IslandController.islandMode === "helium"
    implicitWidth: Theme.islandHeliumWidth - 36
    implicitHeight: 42
    readonly property string url: HeliumService.url
    readonly property bool secure: url.startsWith("https://")
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.92
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.fadeDuration
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }
    // Click the address to edit it (same as Ctrl+L).
    MouseArea {
        anchors.fill: parent
        enabled: view.active && !OverlayController.launcherOpen
        cursorShape: Qt.PointingHandCursor
        onClicked: OverlayController.openLauncher("address")
    }
    IconLabel {
        id: lead
        anchors.verticalCenter: parent.verticalCenter
        x: 18
        text: view.secure ? Theme.cp(0xF033E) : Theme.cp(0xF059F)
        color: view.secure ? Theme.highlight : Theme.muted
        font.pixelSize: 18
    }
    Rectangle {
        id: recDot
        visible: CaptureService.recording
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 18
        width: 9
        height: 9
        radius: 5
        color: Theme.danger
    }
    // Main domain in full colour; scheme, subdomains and path are dimmed.
    readonly property string dim: Theme.muted.toString()
    function esc(t) {
        return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }
    function styled(u) {
        const m = u.match(/^([a-z][a-z0-9+.-]*:\/\/)?([^\/?#:]*)(.*)$/i)
        if (!m)
            return esc(u)
        const scheme = m[1] || "", host = m[2], rest = m[3]
        const labels = host.split(".")
        let keep = 1
        if (labels.length > 1 && !/^[0-9.]+$/.test(host)) {
            keep = 2
            const sld = labels[labels.length - 2]
            if (labels.length > 2 && labels[labels.length - 1].length === 2 && ["co", "com", "org", "net", "gov", "edu", "ac"].includes(sld))
                keep = 3
        }
        const sub = labels.slice(0, Math.max(0, labels.length - keep)).join(".")
        const main = labels.slice(Math.max(0, labels.length - keep)).join(".")
        const d = t => t ? "<font color='" + view.dim + "'>" + esc(t) + "</font>" : ""
        return d(scheme) + d(sub ? sub + "." : "") + esc(main) + d(rest)
    }
    Item {
        id: urlBox
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: lead.right
        anchors.leftMargin: 10
        anchors.right: recDot.visible ? recDot.left : parent.right
        anchors.rightMargin: 18
        height: parent.height
        clip: true
        Text {
            id: urlText
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.RichText
            wrapMode: Text.NoWrap
            text: view.styled(view.url)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
        // Long addresses fade out instead of eliding. (The island's border is a Frame
        // above this, so the fade can't cover it.)
        Rectangle {
            visible: urlText.implicitWidth > urlBox.width
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 48
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Theme.background
                }
            }
        }
    }
}
