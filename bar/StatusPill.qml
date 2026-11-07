import QtQuick
import Quickshell
import ".."
import Quickshell.Io

Pill {
    accent: "#4072cdb8"
    implicitWidth: status.implicitWidth + 26
    Row {
        id: status
        anchors.centerIn: parent
        spacing: 14

        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            IconLabel {
                text: SystemService.profileIcon
                color: SystemService.profile === "performance" ? Theme.warning : SystemService.profile === "power-saver"
                                                                 ? "#a6da95" : Theme.success
            }
            IconLabel {
                text: SystemService.cpuUsage + "%"
            }
        }
        IconLabel {
            text: (SystemService.tempC >= 90 ? Theme.cp(0xF0E01) : Theme.cp(0xF050F)) + " " + SystemService.tempC + "°"
            color: SystemService.tempC >= 90 ? Theme.danger : Theme.success
        }
        IconLabel {
            text: NetworkService.netIcon
            color: NetworkService.netKind === "none" ? Theme.danger : Theme.foreground
        }
        IconLabel {
            text: AudioService.volumeIcon()
            color: AudioService.muted ? "#929aab" : Theme.foreground
            MouseArea {
                anchors.fill: parent
                onClicked: pavu.running = true
                Process {
                    id: pavu
                    command: ["pavucontrol"]
                }
            }
        }
        IconLabel {
            text: BatteryService.plugged ? "" + "" : BatteryService.batteryIcon() + " " + BatteryService.battery + "%"
            color: BatteryService.plugged ? Theme.foreground : BatteryService.battery <= 15 ? Theme.danger :
                                                                                              BatteryService.battery
                                                                                              <= 30 ? Theme.warning :
                                                                                                      Theme.foreground
        }
        IconLabel {
            text: SystemService.clockText
            color: Theme.text
        }
    }
}
