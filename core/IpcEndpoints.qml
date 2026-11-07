import QtQuick
import Quickshell
import ".."
import Quickshell.Io
import Quickshell.Bluetooth

Scope {
    IpcHandler {
        target: "island"
        function network(kind: string): void {
            NetworkService.netEvHotspot = kind === "hotspot"
            NetworkService.netEvKind = kind === "off" ? "none" : kind === "hotspot" ? "wifi" : kind
            NetworkService.netEvName = kind === "eth" ? "Ethernet" : kind === "hotspot" ? "Aditya's iPhone" :
                                                                                          "Aditya wifi"
            NetworkService.netEvSignal = 72
            NetworkService.netEvPrev = kind === "off" ? "Aditya wifi" : ""
            IslandController.showNetwork()
        }
        function brightness(): void {
            IslandController.showBrightness()
        }
        function battery(): void {
            IslandController.showBattery()
        }
        function volume(): void {
            IslandController.showVolume()
        }
        function bluetooth(): void {
            for (const d of Bluetooth.devices.values)
                if (d.connected) {
                    IslandController.showBluetooth(d)
                    return
                }
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            OverlayController.openLauncher("apps")
        }
        function windows(): void {
            OverlayController.openLauncher("windows")
        }
        function capture(): void {
            OverlayController.openLauncher("capture")
        }
        function power(): void {
            OverlayController.openLauncher("power")
        }
        function wifi(): void {
            OverlayController.openLauncher("wifi")
        }
        function bluetooth(): void {
            OverlayController.openLauncher("bluetooth")
        }
        function session(): void {
            OverlayController.openLauncher("session")
        }
        function camera(): void {
            OverlayController.openLauncher("camera")
        }
        function btfake(): void {
            BluetoothService.btFake = !BluetoothService.btFake
        }
        function display(): void {
            OverlayController.openLauncher("display")
        }
        function newdisplay(): void {
            DisplayService.newDisplayName = "Acer EK241Y E (HDMI-A-1)"
            OverlayController.openLauncher("display")
        }
    }
}
