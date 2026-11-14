import QtQuick
import Quickshell
import ".."
import Quickshell.Io

Pill {
    accent: "transparent"
    color: "transparent"
    border.width: 0
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
        Row {
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter
            NetIcon {
                anchors.verticalCenter: parent.verticalCenter
                kind: NetworkService.iconKind
                level: NetworkService.signalLevel
                color: NetworkService.netKind === "none" ? Theme.danger : NetworkService.noInternet ? Theme.warning : Theme.foreground
            }
            IconLabel {
                visible: NetworkService.noInternet
                anchors.verticalCenter: parent.verticalCenter
                text: "!"
                color: Theme.warning
            }
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
