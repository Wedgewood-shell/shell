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
                                      session: sessionPage
                                  })
    readonly property var page: menuLoader.item
    screen: Quickshell.screens.find(s => s.name === OverlayController.launcherScreen) ?? Quickshell.screens[0]
    visible: open || hideTimer.running
    color: "transparent"
    anchors.top: true
    margins.top: Theme.topMargin
    implicitWidth: Math.max(720, pill.width + 24)
    implicitHeight: Math.max(640, pill.height + 24)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "island-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        item: pill
    }
    Timer {
        id: hideTimer
        interval: 520
    }
    Timer {
        id: settleTimer
        interval: 340
        onTriggered: OverlayController.launcherBusy = false
    }
    function prepare() {
        if (!page)
            return
        field.text = ""
        page.refresh()
        field.forceActiveFocus()
    }
    onPageChanged: if (open)
                       prepare()
    onOpenChanged: {
        OverlayController.launcherBusy = true
        if (open) {
            settleTimer.stop()
            prepare()
        } else {
            hideTimer.restart()
            settleTimer.restart()
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
        radius: win.open ? Theme.openRadius : Theme.closedRadius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        width: win.open ? (win.page ? win.page.contentWidth : 620) : OverlayController.islandWidth
        height: win.open ? (win.page ? win.page.contentHeight : 42) : Theme.barHeight
        opacity: OverlayController.launcherBusy ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: win.open ? Theme.morphDuration : 320
                easing.type: win.open ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: 0.9
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: win.open ? Theme.morphDuration : 320
                easing.type: win.open ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: 0.9
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: 300
            }
        }
        Item {
            anchors.fill: parent
            opacity: win.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: win.open ? 260 : 90
                }
            }
            Loader {
                id: menuLoader
                anchors.fill: parent
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
                visible: (win.page && win.page.showHeader)
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
                    width: pill.width - 80
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
                            if (win.page.handleKey(event.key)) {
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Escape)
                                OverlayController.launcherOpen = false
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                win.page.submit()
                            else if (event.key === Qt.Key_Down || (win.page.tiles && event.key === Qt.Key_Right)
                                     || ((event.modifiers & Qt.ControlModifier)
                                         && [Qt.Key_N, Qt.Key_J].includes(event.key)))
                                win.page.navigate(1)
                            else if (event.key === Qt.Key_Up || (win.page.tiles && event.key === Qt.Key_Left)
                                     || ((event.modifiers & Qt.ControlModifier)
                                         && [Qt.Key_P, Qt.Key_K].includes(event.key)))
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
