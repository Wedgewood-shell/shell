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
        spacing: 21

        IconLabel {
            visible: SystemService.showCpu
            anchors.verticalCenter: parent.verticalCenter
            text: SystemService.cpuUsage + "%"
            color: Theme.warning
        }
        IconLabel {
            visible: SystemService.showMem
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.cp(0xF035B) + " " + SystemService.memUsage + "%"
            color: Theme.warning
        }
        IconLabel {
            visible: SystemService.showTemp
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
        VolumeIcon {
            anchors.verticalCenter: parent.verticalCenter
            kind: AudioService.outputKind
            volume: AudioService.volume
            muted: AudioService.muted
            base: Theme.foreground
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
