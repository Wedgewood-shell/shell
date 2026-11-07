pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    Connections {
        target: AudioService
        function onChanged() {
            IslandController.showVolume()
        }
    }
    Connections {
        target: BatteryService
        function onChanged() {
            IslandController.showBattery()
        }
    }
    Connections {
        target: BrightnessService
        function onChanged() {
            IslandController.showBrightness()
        }
    }
    Connections {
        target: NetworkService
        function onChanged() {
            IslandController.showNetwork()
        }
    }
    Connections {
        target: BluetoothService
        function onConnectionChanged(device, connected) {
            IslandController.showBluetooth(device, connected)
        }
    }
    Connections {
        target: DisplayService
        function onDisplayConnected() {
            OverlayController.openLauncher("display")
        }
    }
    Connections {
        target: WifiService
        function onCloseRequested() {
            OverlayController.launcherOpen = false
        }
    }

    Connections {
        target: OverlayController
        function onLauncherModeChanged() {
            if (OverlayController.launcherMode !== "bluetooth")
                BluetoothService.stopDiscovery()
        }
        function onLauncherOpenChanged() {
            if (!OverlayController.launcherOpen)
                BluetoothService.stopDiscovery()
        }
    }
}
