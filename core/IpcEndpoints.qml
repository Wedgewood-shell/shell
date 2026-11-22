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

    // Preview of the window switcher's list without niri's switcher keys.
    IpcHandler {
        target: "switcher"
        function demo(step: int): void {
            const ids = Object.keys(NiriService.windows).map(Number)
            SwitcherController.apply({
                                         "open": true,
                                         "windows": ids,
                                         "selected": ids.length ? ids[step % ids.length] : null
                                     })
        }
        function end(): void {
            SwitcherController.apply({
                                         "open": false,
                                         "windows": [],
                                         "selected": null
                                     })
        }
    }

    IpcHandler {
        target: "voice"
        function say(text: string): void {
            IslandController.voiceSay(text)
        }
        function sayEnd(): void {
            IslandController.voiceSayEnd()
        }
        function startListening(): void {
            IslandController.voiceListen()
        }
        function partial(text: string): void {
            IslandController.voicePartial(text)
        }
        function finish(text: string, status: string): void {
            IslandController.voiceFinal(text, status)
        }
        function idle(): void {
            IslandController.voiceEnd()
        }
    }

    IpcHandler {
        target: "launcher"
        // Ctrl+L: open the Helium address editor. Returns false when no Helium
        // window is focused so the caller can pass the key through.
        function address(): bool {
            if (!HeliumService.active && !(OverlayController.launcherOpen && OverlayController.launcherMode === "address"))
                return false
            OverlayController.openLauncher("address")
            return true
        }
        function toggle(): void {
            OverlayController.openLauncher("apps")
        }
        function hyprbeam(): void {
            OverlayController.openLauncher("hyprbeam")
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
