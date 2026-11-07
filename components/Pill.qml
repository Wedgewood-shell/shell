import QtQuick
import Quickshell
import ".."

Rectangle {
    property color accent: "#33a0b4dc"
    color: "#f0121620"
    radius: Theme.closedRadius
    border.width: 1
    border.color: accent
    implicitHeight: Theme.barHeight
}
