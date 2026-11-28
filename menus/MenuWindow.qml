import QtQuick
import Quickshell
import ".."
import Quickshell.Wayland

PanelWindow {
    id: win
    readonly property bool open: OverlayController.launcherOpen
    readonly property var pages: ({
            apps: appsPage,
            windows: windowsPage,
            audio: audioPage,
            wifi: wifiPage,
            bluetooth: bluetoothPage,
            camera: cameraPage,
            capture: capturePage,
            display: displayPage,
            power: powerPage,
            session: sessionPage,
            address: addressPage,
            hyprbeam: hyprbeamPage
        })
    readonly property var page: menuLoader.item
    // The page actually shown. Switching menus while open fades the old page out, swaps it,
    // and fades the new one in inside the same pill, instead of replacing it abruptly.
    property string shownMode: OverlayController.launcherMode
    property real switchFade: 1
    Connections {
        target: OverlayController
        function onLauncherModeChanged() {
            if (win.open && win.visible && win.shownMode !== OverlayController.launcherMode)
                switchAnimation.restart()
            else {
                switchAnimation.stop()
                win.shownMode = OverlayController.launcherMode
                win.switchFade = 1
            }
        }
    }
    SequentialAnimation {
        id: switchAnimation
        NumberAnimation {
            target: win
            property: "switchFade"
            to: 0
            duration: 90
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: win.shownMode = OverlayController.launcherMode
        }
        NumberAnimation {
            target: win
            property: "switchFade"
            to: 1
            duration: 180
            easing.type: Easing.OutQuad
        }
    }
    readonly property real closedWidth: OverlayController.islandWidths[screen ? screen.name : OverlayController.launcherScreen] ?? 300
    screen: Quickshell.screens.find(s => s.name === OverlayController.launcherScreen) ?? Quickshell.screens[0]
    visible: open || handoff.retained
    onVisibleChanged: OverlayController.launcherMapped = visible
    color: "transparent"
    anchors.top: true
    // Whole device pixels too, or niri rescales (and blurs) the buffer.
    implicitWidth: Theme.surfaceSize(720, devicePixelRatio)
    implicitHeight: Theme.surfaceSize(Theme.topMargin + Math.max(640, layoutHeight + 64 + detailSpace), devicePixelRatio)
    // On a compact bar (see Bar.qml) the closed pill matches the shrunken island, and
    // grows to full size and position as the menu opens.
    BarModeFollower {
        id: mode
        output: win.screen ? win.screen.name : ""
        outputWidth: win.screen ? win.screen.width : 0
        outputHeight: win.screen ? win.screen.height : 0
    }
    readonly property real c: mode.c
    property real openness: open ? 1 : 0
    Behavior on openness {
        NumberAnimation {
            duration: win.open ? Theme.morphDuration : win.closeDuration
            easing.type: Easing.InOutCubic
        }
    }
    readonly property real closedC: c * (1 - openness)
    // Grows only while a page has a detail surface; then stays put while it is shown.
    readonly property real detailSpace: page && page.detail ? page.detailHeight + detailGap : 0
    readonly property int detailGap: 12
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-launcher"
    // The Helium address editor only asks for the keyboard (niri gives it when
    // the window maps), so a click on another window or a niri focus action
    // takes it away, and the editor then closes (see addressHadKeyboard).
    // The other menus keep it until they close.
    WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : OverlayController.launcherMode === "address" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
    readonly property bool keyboardActive: pill.Window.active
    property bool addressHadKeyboard: false
    onKeyboardActiveChanged: {
        if (!open || OverlayController.launcherMode !== "address")
            return
        if (keyboardActive)
            addressHadKeyboard = true
        else if (addressHadKeyboard)
            OverlayController.launcherOpen = false
    }
    mask: Region {
        item: win.open ? pill : null
        Region {
            item: win.open && detailLoader.item && detailLoader.item.opacity > 0 ? detailLoader.item : null
        }
    }
    property real layoutWidth: 620
    property real layoutHeight: Theme.barHeight
    readonly property int closeDuration: 400
    function syncLayout() {
        if (open && page) {
            layoutWidth = page.contentWidth
            layoutHeight = page.contentHeight
        }
    }
    Connections {
        target: win.page
        function onContentWidthChanged() {
            win.syncLayout()
        }
        function onContentHeightChanged() {
            win.syncLayout()
        }
    }
    IslandMorph {
        id: geometry
        expanded: win.open
        // Snapped to whole pixels (the pill is centred on one), matching the bar island.
        collapsedWidth: win.closedWidth
        collapsedHeight: Theme.px(Theme.barHeight, win.devicePixelRatio)
        expandedWidth: Theme.pxEven(win.layoutWidth, win.devicePixelRatio)
        expandedHeight: Theme.px(win.layoutHeight, win.devicePixelRatio)
        duration: win.open ? Theme.morphDuration : win.closeDuration
    }
    IslandHandoff {
        id: handoff
        surface: win
        expanded: win.open
        collapsedHeight: geometry.collapsedHeight
        currentHeight: pill.height
        expandedHeight: win.layoutHeight
        morphing: geometry.running
        onCoveredChanged: OverlayController.launcherBusy = covered
    }
    function prepare() {
        if (!page)
            return
        field.text = page.initialText
        page.refresh()
        syncLayout()
        field.forceActiveFocus()
        if (page.initialText)
            field.selectAll()
    }
    onPageChanged: if (open)
        prepare()
    onOpenChanged: {
        addressHadKeyboard = open && keyboardActive
        if (open)
            prepare()
    }
    Connections {
        target: HeliumService
        function onEditorRestart() {
            if (win.open && OverlayController.launcherMode === "address")
                win.prepare()
        }
    }
    Connections {
        target: win.page
        function onClearQuery() {
            field.text = ""
            field.forceActiveFocus()
        }
        function onSetQuery(text) {
            field.text = text
            field.forceActiveFocus()
        }
    }
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.alignWhenCentered: false   // see Bar.qml; the width is pixel-snapped
        // Closed on a compact bar it matches the bar's island exactly (see Bar.qml).
        y: Theme.topMargin + (Theme.compactTopFor(geometry.collapsedHeight, win.devicePixelRatio) - Theme.topMargin) * win.closedC
        transform: Scale {
            origin.x: pill.width / 2
            xScale: 1 + (Theme.compactLengthEven(pill.width, win.devicePixelRatio) / Math.max(1, pill.width) - 1) * win.closedC
            yScale: 1 + (Theme.compactLength(pill.height, win.devicePixelRatio) / Math.max(1, pill.height) - 1) * win.closedC
        }
        clip: true
        radius: geometry.radius
        color: Theme.surface
        // Border as a Frame above the island and the page, so neither can cover it.
        border.width: 0
        width: geometry.width
        height: geometry.height
        opacity: 1
        Frame {}
        Island {
            showProgress: false
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: parent.width
            height: geometry.collapsedHeight
            dpr: win.devicePixelRatio
            color: "transparent"
            framed: false
            opacity: handoff.islandOpacity
            Behavior on opacity {
                enabled: win.open
                NumberAnimation {
                    duration: 120
                }
            }
        }
        Item {
            id: content
            enabled: win.open
            width: win.layoutWidth
            height: win.layoutHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            opacity: handoff.contentOpacity
            Behavior on opacity {
                enabled: win.open
                NumberAnimation {
                    duration: 260
                }
            }
            Loader {
                id: menuLoader
                anchors.fill: parent
                // Above the (mostly invisible) header row so pages can use the top band for clicks.
                z: 1
                sourceComponent: win.pages[win.shownMode] || appsPage
                opacity: win.switchFade
                onLoaded: {
                    item.query = Qt.binding(() => field.text)
                    if (win.open)
                        win.prepare()
                }
            }
            Rectangle {
                x: 14
                y: 42
                width: parent.width - 28
                height: 1
                color: Theme.raised
                opacity: win.switchFade
                visible: (win.page && win.page.showHeader && win.page.showDivider)
            }
            Row {
                x: 18
                height: 42
                spacing: 12
                opacity: (win.page && win.page.showHeader) ? win.switchFade : 0
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (win.page ? win.page.glyph : "")
                    color: Theme.highlight
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: content.width - 80
                    height: 24
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideRight
                        visible: field.text.length === 0
                        text: (win.page ? win.page.title : "")
                        font.weight: (win.page && win.page.tiles) ? Font.DemiBold : Font.Normal
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }
                    SearchField {
                        id: field
                        anchors.fill: parent
                        readOnly: (win.page && win.page.inputReadOnly)
                        echoMode: (win.page && win.page.password) ? TextInput.Password : TextInput.Normal
                        Keys.onPressed: event => {
                            if (!win.page)
                                return
                            if ((win.page.handleEvent && win.page.handleEvent(event)) || win.page.handleKey(event.key)) {
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Escape)
                                OverlayController.launcherOpen = false
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                win.page.submit()
                            else if (event.key === Qt.Key_Down || (win.page.tiles && event.key === Qt.Key_Right) || ((event.modifiers & Qt.ControlModifier) && [Qt.Key_N, Qt.Key_J].includes(event.key)))
                                win.page.navigate(1)
                            else if (event.key === Qt.Key_Up || (win.page.tiles && event.key === Qt.Key_Left) || ((event.modifiers & Qt.ControlModifier) && [Qt.Key_P, Qt.Key_K].includes(event.key)))
                                win.page.navigate(-1)
                            else
                                return
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
    Loader {
        id: detailLoader
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pill.bottom
        anchors.topMargin: win.detailGap
        active: win.page !== null && win.page.detail !== null
        sourceComponent: win.page ? win.page.detail : null
    }
    Component {
        id: addressPage
        AddressMenu {}
    }
    Component {
        id: hyprbeamPage
        HyprbeamMenu {}
    }
    Component {
        id: appsPage
        AppsMenu {}
    }
    Component {
        id: windowsPage
        WindowsMenu {}
    }
    Component {
        id: audioPage
        AudioMenu {}
    }
    Component {
        id: wifiPage
        WifiMenu {}
    }
    Component {
        id: bluetoothPage
        BluetoothMenu {}
    }
    Component {
        id: cameraPage
        CameraMenu {}
    }
    Component {
        id: capturePage
        CaptureMenu {}
    }
    Component {
        id: displayPage
        DisplayMenu {}
    }
    Component {
        id: powerPage
        PowerProfileMenu {}
    }
    Component {
        id: sessionPage
        SessionMenu {}
    }
}
