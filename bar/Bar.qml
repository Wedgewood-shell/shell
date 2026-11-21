import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // Compact while a window spans this output's width: the floating pills become
    // a flush, full-width strip with a background, and modules shrink.
    readonly property bool compact: NiriService.spansOutput(modelData.name, modelData.width)
    property real c: compact ? 1 : 0
    Behavior on c {
        NumberAnimation {
            duration: Theme.compactDuration
            easing.type: Easing.InOutCubic
        }
    }
    // Smart fullscreen (Settings.smartFullscreenApps): a compact bar that reserves no
    // space, so the window extends underneath it, and blurs it instead of tinting.
    readonly property bool smart: compact && NiriService.smartFullscreenOn(modelData.name, modelData.width)
    property real s: smart ? 1 : 0
    Behavior on s {
        NumberAnimation {
            duration: Theme.compactDuration
            easing.type: Easing.InOutCubic
        }
    }
    readonly property real moduleScale: 1 - (1 - Theme.compactScale) * c
    readonly property real stripY: Theme.topMargin * (1 - c)
    readonly property real stripH: Theme.barHeight + (Theme.compactBarHeight - Theme.barHeight) * c
    readonly property real sidePad: 16 + (Theme.compactPadding - 16) * c

    // The surface is flush with the screen edges; the resting margins are drawn inside it.
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.surfaceSize(Theme.topMargin + Theme.px(Theme.barHeight, devicePixelRatio), devicePixelRatio)
    // Switches at once (windows resize once, not every frame).
    exclusiveZone: smart ? 0 : compact ? Theme.compactBarHeight : Theme.topMargin + 50
    color: "transparent"
    WlrLayershell.namespace: "island-bar"
    // niri blurs the window below (needs the island-bar layer rule with `xray false`
    // in niri's config.kdl, or it blurs the wallpaper instead).
    BackgroundEffect.blurRegion: Region {
        item: bar.smart ? background : null
    }
    mask: Region {
        item: hitArea
    }
    Item {
        id: hitArea
        y: bar.stripY
        width: parent.width
        height: bar.stripH
    }

    Rectangle {
        id: background
        width: parent.width
        height: bar.stripY + bar.stripH
        color: Theme.compactBackground
        // Smart fullscreen: no tint, only the blur behind it.
        opacity: bar.c * (1 - bar.s)
        visible: bar.c > 0
    }

    Item {
        id: content
        x: bar.sidePad
        y: bar.stripY
        width: parent.width - 2 * bar.sidePad
        height: bar.stripH

        // Left: focused window / switcher lives in WindowSwitcher (its own surface).

        // ---- center: dynamic island ----
        Island {
            anchors.horizontalCenter: parent.horizontalCenter
            // Centring rounds to whole logical pixels by default, which at a fractional
            // scale lands the edges on half device pixels; the width is snapped instead.
            anchors.alignWhenCentered: false
            id: island
            dpr: bar.devicePixelRatio
            // Top-aligned (not centred) so every edge stays on a whole device pixel,
            // also when compact (see Theme.compactLength).
            y: Theme.compactTopFor(height, dpr) * bar.c
            transform: Scale {
                origin.x: island.width / 2
                xScale: 1 + (Theme.compactLengthEven(island.width, island.dpr) / Math.max(1, island.width) - 1) * bar.c
                yScale: 1 + (Theme.compactLength(island.height, island.dpr) / Math.max(1, island.height) - 1) * bar.c
            }
            opacity: (OverlayController.launcherBusy && OverlayController.launcherScreen === bar.modelData.name) ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.islandFadeDuration
                }
            }
            onImplicitWidthChanged: OverlayController.setIslandWidth(bar.modelData.name, implicitWidth)
            Component.onCompleted: OverlayController.setIslandWidth(bar.modelData.name, implicitWidth)
        }

        // ---- right: tray + status ----
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            scale: bar.moduleScale
            transformOrigin: Item.Right
            spacing: 0

            Item {
                visible: trayWrap.visible
                width: trayWrap.width + 8
                height: Theme.barHeight
                Pill {
                    id: trayWrap
                    color: "transparent"
                    border.width: 0
                    visible: trayRow.implicitWidth > 0
                    implicitWidth: trayRow.implicitWidth + 26
                    Tray {
                        id: trayRow
                        anchors.centerIn: parent
                        window: bar
                    }
                }
            }

            StatusPill {}

            // Date/time, shown here while a non-clock base state owns the island.
            Item {
                id: clockSlot
                readonly property bool shown: IslandController.clockInBar
                property real p: shown ? 1 : 0
                Behavior on p {
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.OutCubic
                    }
                }
                visible: p > 0
                height: Theme.barHeight
                width: (barClock.implicitWidth + 26 + 8) * p
                clip: true
                Pill {
                    anchors.right: parent.right
                    width: barClock.implicitWidth + 26
                    height: parent.height
                    color: "transparent"
                    border.width: 0
                    opacity: clockSlot.p
                    Text {
                        id: barClock
                        anchors.centerIn: parent
                        text: SystemService.clockText
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.features: Theme.tabularFigures
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
