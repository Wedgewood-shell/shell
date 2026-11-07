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
                color: SystemService.profile === "performance" ? Theme.warning : SystemService.profile === "power-saver" ? "#a6da95" : Theme.success
            }
            IconLabel {
                text: SystemService.cpuUsage + "%"
            }
        }
        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: (SystemService.tempC >= 90 ? Theme.cp(0xF0E01) : Theme.cp(0xF050F)) + " " + SystemService.tempC + "°"
            color: SystemService.tempC >= 90 ? Theme.danger : Theme.success
        }
        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: NetworkService.netIcon
            color: NetworkService.netKind === "none" ? Theme.danger : Theme.foreground
        }
        IconLabel {
            anchors.verticalCenter: parent.verticalCenter
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
        BatteryIndicator {
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
