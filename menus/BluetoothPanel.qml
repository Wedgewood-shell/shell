import QtQuick
import Quickshell
import ".."
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth menu body, shown inside the launcher pill (mode "bluetooth").
Item {
    id: panel

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter ? adapter.enabled : false
    readonly property bool scanning: on && adapter && adapter.discovering
    readonly property bool discoverable: on && adapter && adapter.discoverable

    // ---- sizing (read by the launcher) ----
    readonly property int cell: 96
    readonly property int cols: 5
    readonly property int btnSize: 74
    readonly property int rowH: 44
    readonly property real gridH: !on ? 52 : Math.max(52, grid.implicitHeight + 6)
    readonly property real listH: scanning ? Math.min(Math.max(listModel.length, 1), 5) * rowH + 8 : 0
    readonly property real contentW: 600
    readonly property real contentH: gridH + 10 + btnSize + (scanning ? 10 + listH : 0) + 18
    implicitWidth: contentW
    implicitHeight: contentH

    // ---- focus ----
    property string zone: "buttons"          // "buttons" | "list"
    property int btnIndex: 0
    property int listIndex: 0

    readonly property var btns: on ? ["disable", "scan", "discoverable"] : ["disable"]

    function act(id) {
        if (!adapter)
            return
        if (id === "disable")
            adapter.enabled = !adapter.enabled
        else if (id === "scan")
            adapter.discovering = !adapter.discovering
        else if (id === "discoverable")
            adapter.discoverable = !adapter.discoverable
    }

    function connectDevice(d) {
        BluetoothService.connectDevice(d)
    }

    // returns true when the key was handled
    function handleKey(key) {
        if (zone === "buttons") {
            if (key === Qt.Key_Left) {
                btnIndex = Math.max(0, btnIndex - 1)
                return true
            }
            if (key === Qt.Key_Right) {
                btnIndex = Math.min(btns.length - 1, btnIndex + 1)
                return true
            }
            if (key === Qt.Key_Down) {
                if (scanning && listModel.length > 0) {
                    zone = "list"
                    listIndex = 0
                }
                return true
            }
            if (key === Qt.Key_Up)
                return true
            if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                act(btns[Math.min(btnIndex, btns.length - 1)])
                return true
            }
        } else {
            if (key === Qt.Key_Up) {
                if (listIndex > 0)
                    listIndex -= 1
                else
                    zone = "buttons"
                return true
            }
            if (key === Qt.Key_Down) {
                listIndex = Math.min(listIndex + 1, listModel.length - 1)
                return true
            }
            if (key === Qt.Key_Left) {
                zone = "buttons"
                return true
            }
            if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                connectDevice(listModel[listIndex])
                return true
            }
        }
        return false
    }

    function reset() {
        zone = "buttons"
        btnIndex = 0
        listIndex = 0
    }

    // stop scanning when the menu closes
    Connections {
        target: OverlayController
        function sync() {
            if (!OverlayController.launcherOpen || OverlayController.launcherMode !== "bluetooth") {
                if (panel.adapter && panel.adapter.discovering)
                    panel.adapter.discovering = false
            } else
                panel.reset()
        }
        function onLauncherOpenChanged() {
            sync()
        }
        function onLauncherModeChanged() {
            sync()
        }
    }
    onScanningChanged: if (!scanning && zone === "list")
                           zone = "buttons"

    // ---- devices found while scanning ----
    property var listModel: []
    function rebuild() {
        const out = []
        for (const d of Bluetooth.devices.values) {
            if (d.connected)
                continue
            const n = d.name || d.deviceName
            if (!n)
                continue
            if (/^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$/.test(n))
                // unnamed devices only advertise their address
                continue
            out.push(d)
        }
        out.sort((a, b) => (b.paired - a.paired) || (a.name || a.deviceName).localeCompare(b.name || b.deviceName))
        listModel = out
        listIndex = Math.min(listIndex, Math.max(0, out.length - 1))
    }
    Timer {
        interval: 1000
        running: panel.scanning
        repeat: true
        triggeredOnStart: true
        onTriggered: panel.rebuild()
    }

    // ---- square button ----
    component BtButton: Rectangle {
        id: b
        property string glyph: ""
        property string label: ""
        property color tint: "#c7d2ff"
        property bool focused: false
        property bool active: false
        property bool spinning: false
        signal clicked
        implicitWidth: panel.btnSize
        implicitHeight: panel.btnSize
        radius: 8
        color: hov.containsMouse || focused ? "#2d3856" : (active ? "#27405a" : "#222a42")
        border.width: focused ? 2 : 0
        border.color: Theme.highlight
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 3
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: b.glyph
                color: b.tint
                font.family: Theme.fontFamily
                font.pixelSize: 24
                RotationAnimator on rotation {
                    running: b.spinning
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1100
                }
                onRotationChanged: if (!b.spinning && rotation !== 0)
                                       rotation = 0
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: b.label
                color: "#cdd5ee"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
        }
    }

    // ---- connected devices grid ----
    Item {
        id: gridArea
        x: 0
        y: 0
        width: parent.width
        height: panel.gridH

        Text {
            anchors.centerIn: parent
            visible: !panel.on || grid.implicitHeight === 0
            text: !panel.on ? "Bluetooth is off" : "No devices connected"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        Grid {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            columns: panel.cols
            visible: panel.on

            Repeater {
                model: BluetoothService.btFake ? BluetoothService.btFakeDevices : Bluetooth.devices
                delegate: Item {
                    id: dev
                    required property var modelData
                    visible: panel.on && modelData.connected
                    width: visible ? panel.cell : 0
                    height: visible ? 108 : 0

                    readonly property bool hasBat: modelData.batteryAvailable
                    readonly property real bat: Math.max(0, Math.min(1, modelData.battery))
                    readonly property color batColor: bat < 0.15 ? Theme.danger : bat < 0.3 ? Theme.warning : "#7be0a8"

                    Item {
                        id: ringBox
                        width: 66
                        height: 66
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: width / 2
                            color: "#222a42"
                        }
                        Canvas {
                            id: ring
                            anchors.fill: parent
                            visible: dev.hasBat
                            property real frac: dev.bat
                            onFracChanged: requestPaint()
                            Connections {
                                target: dev
                                function onBatColorChanged() {
                                    ring.requestPaint()
                                }
                            }
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                const c = width / 2, r = c - 3
                                ctx.lineWidth = 4
                                ctx.lineCap = "round"
                                ctx.strokeStyle = "#2f3855"
                                ctx.beginPath()
                                ctx.arc(c, c, r, 0, Math.PI * 2)
                                ctx.stroke()
                                if (frac > 0) {
                                    ctx.strokeStyle = dev.batColor
                                    ctx.beginPath()
                                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac)
                                    ctx.stroke()
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: BluetoothService.btGlyph(dev.modelData.icon)
                            color: "#c7d2ff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 74
                        width: panel.cell - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: dev.modelData.name || dev.modelData.deviceName
                        color: "#e4e9f7"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 90
                        visible: dev.hasBat
                        text: Math.round(dev.bat * 100) + "%"
                        color: "#8a95b8"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    // ---- button row ----
    Row {
        id: buttonRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.gridH + 10
        spacing: 4
        Repeater {
            model: panel.btns
            delegate: BtButton {
                required property string modelData
                required property int index
                glyph: modelData === "disable" ? "" : modelData === "scan" ? "" : ""
                label: modelData === "disable" ? (panel.on ? "Disable" : "Enable") : modelData === "scan" ? (
                                                                                                                panel.scanning
                                                                                                                ? "Stop" :
                                                                                                                  "Scan") : "Discoverable"
                tint: modelData === "disable" ? (panel.on ? Theme.danger : Theme.success) : modelData === "scan"
                                                ? Theme.highlight : (panel.discoverable ? "#7be0a8" : "#c7d2ff")
                active: (modelData === "scan" && panel.scanning) || (modelData === "discoverable" && panel.discoverable)
                spinning: modelData === "scan" && panel.scanning
                focused: panel.zone === "buttons" && panel.btnIndex === index
                onClicked: {
                    panel.zone = "buttons"
                    panel.btnIndex = index
                    panel.act(modelData)
                }
            }
        }
    }

    // ---- scan results ----
    Item {
        id: results
        visible: panel.scanning
        x: 8
        y: panel.gridH + 10 + panel.btnSize + 10
        width: parent.width - 16
        height: panel.listH

        Text {
            anchors.centerIn: parent
            visible: panel.listModel.length === 0
            text: "Searching for devices…"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
        ListView {
            id: rlist
            anchors.fill: parent
            clip: true
            model: panel.listModel
            currentIndex: panel.listIndex
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 100
            highlight: Rectangle {
                radius: 8
                color: panel.zone === "list" ? "#2a3454" : "transparent"
            }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: rlist.width
                height: panel.rowH
                Text {
                    x: 14
                    width: 28
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: BluetoothService.btGlyph(row.modelData.icon)
                    color: Theme.highlight
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                }
                Text {
                    x: 56
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56 - 110
                    elide: Text.ElideRight
                    text: row.modelData.name || row.modelData.deviceName
                    color: "#e4e9f7"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.pairing ? "Pairing…" : row.modelData.paired ? "Paired" : "New"
                    color: row.modelData.pairing ? Theme.warning : row.modelData.paired ? Theme.success : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: {
                        panel.zone = "list"
                        panel.listIndex = row.index
                    }
                    onClicked: panel.connectDevice(row.modelData)
                }
            }
        }
    }
}
