import QtQuick
import Quickshell
import ".."

Rectangle {
    property color accent: Theme.borderSubtle
    color: Theme.pill
    radius: Theme.closedRadius
    border.width: 1
    border.color: accent
    implicitHeight: Theme.barHeight
}
