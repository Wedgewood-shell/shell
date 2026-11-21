import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // Compact while an expanded full-width window reaches under the bar: the floating
    // pills become a flush, full-width strip with a background, and modules shrink.
    // Smart fullscreen (a window up to the very top) uses a fading tint instead.
    // Follows niri's camera; see BarMode.
    BarModeFollower {
        id: mode
        output: bar.modelData.name
        outputWidth: bar.modelData.width
        outputHeight: bar.modelData.height
    }
    readonly property real c: mode.c
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
    // Constant, so ordinary windows never resize; expanded windows reach under the bar
    // through niri's full-width-to-edges-top instead (see Theme.barZone).
    exclusiveZone: Theme.barZone
    color: "transparent"
    WlrLayershell.namespace: "island-bar"
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
        opacity: mode.plain
        visible: opacity > 0
    }
    // Smart fullscreen: the tint fades from the top edge to nothing, running a little
    // past the strip (to the surface bottom) so there is no hard edge over the window.
    Rectangle {
        width: parent.width
        height: parent.height
        opacity: mode.smart
        visible: opacity > 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.compactBackground
            }
            GradientStop {
                position: bar.stripH / Math.max(1, bar.height) * 0.5
                color: Theme.alpha(Theme.background, Theme.kittyOpacity * 0.7)
            }
            GradientStop {
                position: 1
                color: Theme.alpha(Theme.background, 0)
            }
        }
    }

    Item {
        id: content
        x: bar.sidePad
        y: bar.stripY
        width: parent.width - 2 * bar.sidePad
        height: bar.stripH

        // Left: focused window / switcher lives in WindowSwitcher (its own surface).

        // ---- center: dynamic island (+ the media chip beside it) ----
        // The island and the chip scale together for the compact bar, about the
        // island's centre (the island stays centred; the chip hangs off its right).
        Item {
            id: islandGroup
            anchors.horizontalCenter: parent.horizontalCenter
            // Centring rounds to whole logical pixels by default, which at a fractional
            // scale lands the edges on half device pixels; the width is snapped instead.
            anchors.alignWhenCentered: false
            width: island.width
            height: island.height
            // Top-aligned (not centred) so every edge stays on a whole device pixel,
            // also when compact (see Theme.compactLength).
            y: Theme.compactTopFor(height, island.dpr) * bar.c
            transform: Scale {
                origin.x: islandGroup.width / 2
                xScale: 1 + (Theme.compactLengthEven(island.width, island.dpr) / Math.max(1, island.width) - 1) * bar.c
                yScale: 1 + (Theme.compactLength(island.height, island.dpr) / Math.max(1, island.height) - 1) * bar.c
            }
            opacity: (OverlayController.launcherBusy && OverlayController.launcherScreen === bar.modelData.name) ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.islandFadeDuration
                }
            }

            Island {
                id: island
                dpr: bar.devicePixelRatio
                showMedia: false    // the media pill below draws it
                onImplicitWidthChanged: OverlayController.setIslandWidth(bar.modelData.name, implicitWidth)
                Component.onCompleted: OverlayController.setIslandWidth(bar.modelData.name, implicitWidth)
            }
            // Media: over the island as its media view, or detached and collapsed
            // into a chip beside it while the address bar has the island.
            MediaChip {
                dpr: island.dpr
                islandWidth: island.width
            }
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
                // 13 (status pill's right padding) + 8 = the 21px icon spacing; 13 keeps the right margin
                width: (barClock.implicitWidth + 13 + 8) * p
                clip: true
                Pill {
                    anchors.right: parent.right
                    width: barClock.implicitWidth + 13
                    height: parent.height
                    color: "transparent"
                    border.width: 0
                    opacity: clockSlot.p
                    Text {
                        id: barClock
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
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
