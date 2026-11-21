import QtQuick
import Quickshell
import "../.."

// Every transient alert (volume, battery, bluetooth, brightness, network) in one
// persistent row: icon | meter | primary | caption | extra. Switching between alerts
// does not swap views; the slots resize in lockstep with the island (same duration and
// easing), the meter fill slides to its new value, the icon cross-fades in place, and
// only the text re-fades. Slots an alert doesn't use collapse to zero width.
Item {
    id: view
    readonly property var kinds: ["volume", "battery", "bluetooth", "brightness", "network"]
    readonly property bool active: kinds.includes(IslandController.islandMode)
    // The last alert shown, so the content stays put while the view fades out.
    property string kind: "volume"
    Binding {
        target: view
        property: "kind"
        value: IslandController.islandMode
        when: view.active
    }
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

    // ---- per-alert data ----
    readonly property bool hasMeter: kind === "volume" || kind === "battery" || kind === "brightness"
    readonly property real frac: kind === "volume" ? Math.min(1, AudioService.volume) : kind === "battery" ? BatteryService.battery / 100 : kind === "brightness" ? BrightnessService.briFrac : 0
    readonly property color meterColor: kind === "volume" ? (AudioService.muted ? Theme.muted : Theme.highlight) : kind === "battery" ? (BatteryService.onBat ? (BatteryService.battery <= 15 ? Theme.danger : BatteryService.battery <= 30 ? Theme.warning : Theme.highlight) : Theme.success) : Theme.warning

    readonly property var btDev: IslandController.btDevice
    readonly property bool btHasBat: !!(IslandController.btUp && btDev && btDev.batteryAvailable)
    readonly property bool netUp: NetworkService.netEvKind !== "none"

    readonly property string primary: {
        switch (kind) {
        case "volume":
            return AudioService.muted ? "muted" : Math.round(AudioService.volume * 100) + "%"
        case "battery":
            return BatteryService.battery + "%"
        case "brightness":
            return Math.round(BrightnessService.briFrac * 100) + "%"
        case "bluetooth":
            return btDev ? (btDev.name || btDev.deviceName) : ""
        default:
            return netUp ? NetworkService.netEvName : (NetworkService.netEvPrev ? NetworkService.netEvPrev : "Network")
        }
    }
    readonly property string caption: {
        switch (kind) {
        case "volume":
            return "·  " + AudioService.sinkName
        case "battery":
            return "·  " + (BatteryService.onBat ? "On battery" : "Plugged in")
        case "bluetooth":
            return IslandController.btUp ? "·  Connected" : "·  Disconnected"
        case "network":
            return netUp ? (NetworkService.netEvHotspot ? "·  Mobile hotspot" : "·  Connected") : "·  Disconnected"
        default:
            return ""
        }
    }
    readonly property color captionColor: kind === "bluetooth" ? (IslandController.btUp ? Theme.success : Theme.danger) : kind === "network" ? (netUp ? Theme.success : Theme.danger) : Theme.muted
    readonly property real captionCap: kind === "volume" ? 210 : 260
    readonly property real primaryCap: kind === "bluetooth" ? 240 : 260
    readonly property bool hasExtra: kind === "bluetooth" ? btHasBat : kind === "network" ? NetworkService.netEvKind === "wifi" : false

    // Re-fade the text when the alert changes (not on value updates).
    property real swap: 1
    onKindChanged: if (active) {
        swap = 0
        swapAnimation.restart()
    }
    NumberAnimation {
        id: swapAnimation
        target: view
        property: "swap"
        to: 1
        duration: 240
        easing.type: Easing.OutCubic
    }

    // ---- slot widths (targets); the slots animate towards them ----
    readonly property real gap: 12
    readonly property real iconTarget: kind === "volume" ? volumeIcon.implicitWidth : kind === "battery" ? batteryIcon.implicitWidth : kind === "brightness" ? brightnessIcon.implicitWidth : kind === "bluetooth" ? btIcon.implicitWidth : netIcon.implicitWidth
    readonly property real meterTarget: hasMeter ? gap + 150 : 0
    readonly property real primaryTarget: gap + (hasMeter ? Math.max(44, primaryMeasure.implicitWidth) : Math.min(primaryMeasure.implicitWidth, primaryCap))
    readonly property real captionTarget: caption === "" ? 0 : gap + Math.min(captionMeasure.implicitWidth, captionCap)
    readonly property real extraTarget: hasExtra ? gap + extraRow.implicitWidth : 0
    readonly property real targetWidth: iconTarget + meterTarget + primaryTarget + captionTarget + extraTarget
    implicitWidth: targetWidth
    implicitHeight: Theme.barHeight
    width: row.width
    height: implicitHeight

    Text {
        id: primaryMeasure
        visible: false
        text: view.primary
        font.family: Theme.fontFamily
        font.features: Theme.tabularFigures
        font.pixelSize: 19
        font.weight: Font.DemiBold
    }
    Text {
        id: captionMeasure
        visible: false
        text: view.caption
        font.family: Theme.fontFamily
        font.pixelSize: 18
    }

    component Slot: Item {
        id: slot
        property real target: 0
        property real w: target
        property bool animate: true
        height: parent ? parent.height : 0
        width: Math.max(0, w)
        clip: true
        Behavior on w {
            enabled: slot.animate
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }
    }

    Row {
        id: row
        height: parent.height
        spacing: 0

        // ---- icon ----
        Slot {
            target: view.iconTarget
            animate: view.opacity > 0.5
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                VolumeIcon {
                    id: volumeIcon
                    anchors.verticalCenter: parent.verticalCenter
                    s: 1.15
                    kind: AudioService.outputKind
                    volume: AudioService.volume
                    muted: AudioService.muted
                    base: Theme.text
                    opacity: view.kind === "volume" ? 1 : 0
                    scale: view.kind === "volume" ? 1 : 0.8
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
                }
                Row {
                    id: batteryIcon
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    opacity: view.kind === "battery" ? 1 : 0
                    scale: view.kind === "battery" ? 1 : 0.8
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
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: BatteryService.onBat ? BatteryService.batteryIcon() : "\uf240"
                        color: BatteryService.onBat ? (BatteryService.battery <= 15 ? Theme.danger : Theme.text) : Theme.success
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !BatteryService.onBat
                        text: "\uf0e7"
                        color: Theme.warning
                        font.family: Theme.fontFamily
                        font.pixelSize: 21
                    }
                }
                Text {
                    id: brightnessIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.cp(BrightnessService.briFrac < 0.34 ? 0xF00DE : BrightnessService.briFrac < 0.67 ? 0xF00DF : 0xF00E0)
                    color: Theme.warning
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    opacity: view.kind === "brightness" ? 1 : 0
                    scale: view.kind === "brightness" ? 1 : 0.8
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
                }
                Text {
                    id: btIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: BluetoothService.btGlyph(view.btDev ? view.btDev.icon : "")
                    color: IslandController.btUp ? Theme.highlight : Theme.muted
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 23
                    opacity: view.kind === "bluetooth" ? 1 : 0
                    scale: view.kind === "bluetooth" ? 1 : 0.8
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
                }
                Text {
                    id: netIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkService.netGlyph(NetworkService.netEvHotspot && NetworkService.netEvKind !== "none" ? "hotspot" : NetworkService.netEvKind, NetworkService.netEvSignal)
                    color: view.netUp ? Theme.highlight : Theme.danger
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 23
                    opacity: view.kind === "network" ? 1 : 0
                    scale: view.kind === "network" ? 1 : 0.8
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
                }
            }
        }

        // ---- meter (volume, battery, brightness) ----
        Slot {
            target: view.meterTarget
            animate: view.opacity > 0.5
            Rectangle {
                x: view.gap
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 6
                radius: 3
                color: Theme.raised
                opacity: view.hasMeter ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
                Rectangle {
                    height: parent.height
                    radius: 3
                    width: parent.width * view.frac
                    color: view.meterColor
                    Behavior on width {
                        enabled: view.opacity > 0.5
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }
            }
        }

        // ---- primary: the value (percent) or the name ----
        Slot {
            target: view.primaryTarget
            animate: view.opacity > 0.5
            Text {
                x: view.gap
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, view.primaryTarget - view.gap)
                horizontalAlignment: view.hasMeter ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
                text: view.primary
                color: Theme.text
                opacity: view.swap
                font.family: Theme.fontFamily
                font.features: Theme.tabularFigures
                font.pixelSize: 19
                font.weight: Font.DemiBold
            }
        }

        // ---- caption ----
        Slot {
            target: view.captionTarget
            animate: view.opacity > 0.5
            Text {
                x: view.gap
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, view.captionTarget - view.gap)
                elide: Text.ElideRight
                text: view.caption
                color: view.captionColor
                opacity: view.swap
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }
        }

        // ---- extra: bluetooth device battery, wifi signal ----
        Slot {
            target: view.extraTarget
            animate: view.opacity > 0.5
            Row {
                id: extraRow
                x: view.gap
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                opacity: view.swap
                Text {
                    visible: view.kind === "bluetooth"
                    text: BatteryService.batteryGlyph(view.btHasBat ? view.btDev.battery : 0)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                }
                Text {
                    text: view.kind === "bluetooth" ? (view.btHasBat ? Math.round(view.btDev.battery * 100) + "%" : "") : NetworkService.netEvSignal + "%"
                    color: view.kind === "bluetooth" ? Theme.text : Theme.muted
                    font.family: Theme.fontFamily
                    font.features: Theme.tabularFigures
                    font.pixelSize: 18
                }
            }
        }
    }
}
