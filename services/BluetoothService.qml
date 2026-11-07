pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import Quickshell.Bluetooth

Singleton {
    id: root
    // ---- bluetooth ----
    // test hook: pretend a few devices are connected (quickshell ipc call launcher btfake)
    property bool btFake: false
    readonly property var btFakeDevices: [
        {
            name: "Toad One",
            icon: "audio-headphones",
            connected: true,
            batteryAvailable: true,
            battery: 0.82
        },
        {
            name: "RK N80",
            icon: "input-keyboard",
            connected: true,
            batteryAvailable: true,
            battery: 0.52
        },
        {
            name: "MX Master 3",
            icon: "input-mouse",
            connected: true,
            batteryAvailable: true,
            battery: 0.12
        },
        {
            name: "Pixel 8",
            icon: "phone",
            connected: true,
            batteryAvailable: false,
            battery: 0
        },
        {
            name: "JBL Flip",
            icon: "audio-speakers",
            connected: true,
            batteryAvailable: true,
            battery: 0.27
        },
        {
            name: "DualSense",
            icon: "input-gaming",
            connected: true,
            batteryAvailable: true,
            battery: 0.95
        }
    ]
    property bool btArmed: false
    Timer {
        interval: 3000
        running: true
        onTriggered: root.btArmed = true
    }
    function btGlyph(icon) {
        const i = (icon || "").toLowerCase()
        if (i.indexOf("head") >= 0)
            return Theme.cp(0xF02CB)
        if (i.indexOf("mouse") >= 0)
            return Theme.cp(0xF037D)
        if (i.indexOf("keyboard") >= 0)
            return Theme.cp(0xF030C)
        if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0)
            return Theme.cp(0xF02B4)
        if (i.indexOf("speaker") >= 0)
            return Theme.cp(0xF04C3)
        if (i.indexOf("phone") >= 0)
            return Theme.cp(0xF03F2)
        return Theme.cp(0xF00AF)
    }
    Instantiator {
        model: Bluetooth.devices
        delegate: QtObject {
            required property var modelData
            property bool conn: modelData.connected
            onConnChanged: if (root.btArmed)
                               root.connectionChanged(modelData, conn)
        }
    }

    // device waiting to be connected once pairing finishes
    property var pending: null
    Connections {
        target: root.pending
        ignoreUnknownSignals: true
        function onPairedChanged() {
            if (root.pending && root.pending.paired) {
                root.pending.trusted = true
                root.pending.connect()
                root.pending = null
            }
        }
    }
    function connectDevice(d) {
        if (!d)
            return
        if (d.paired)
            d.connect()
        else {
            pending = d
            d.pair()
        }
    }

    function stopDiscovery() {
        const adapter = Bluetooth.defaultAdapter
        if (adapter && adapter.discovering)
            adapter.discovering = false
    }
    signal connectionChanged(var device, bool connected)
}
