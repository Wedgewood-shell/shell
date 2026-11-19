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
            wifi: wifiPage,
            bluetooth: bluetoothPage,
            camera: cameraPage,
            capture: capturePage,
            display: displayPage,
            power: powerPage,
            session: sessionPage,
            address: addressPage
        })
    readonly property var page: menuLoader.item
    readonly property real closedWidth: OverlayController.islandWidths[screen ? screen.name : OverlayController.launcherScreen] ?? 300
    screen: Quickshell.screens.find(s => s.name === OverlayController.launcherScreen) ?? Quickshell.screens[0]
    visible: open || handoff.retained
    onVisibleChanged: OverlayController.launcherMapped = visible
    color: "transparent"
    anchors.top: true
    margins.top: Theme.topMargin
    implicitWidth: 720
    implicitHeight: Math.max(640, layoutHeight + 64 + detailSpace)
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
        collapsedWidth: win.closedWidth
        expandedWidth: win.layoutWidth
        expandedHeight: win.layoutHeight
        duration: win.open ? Theme.morphDuration : win.closeDuration
    }
    IslandHandoff {
        id: handoff
        surface: win
        expanded: win.open
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
    }
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        radius: geometry.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        width: geometry.width
        height: geometry.height
        opacity: 1
        Island {
            showProgress: false
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: parent.width
            height: Theme.barHeight
            color: "transparent"
            border.width: 0
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
                sourceComponent: win.pages[OverlayController.launcherMode] || appsPage
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
                color: "#2b3350"
                visible: (win.page && win.page.showHeader && win.page.showDivider)
            }
            Row {
                x: 18
                height: 42
                spacing: 12
                opacity: (win.page && win.page.showHeader) ? 1 : 0
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
                        color: "#6d7694"
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
        id: appsPage
        AppsMenu {}
    }
    Component {
        id: windowsPage
        WindowsMenu {}
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
