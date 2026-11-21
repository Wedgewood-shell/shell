import QtQuick
import Quickshell
import ".."

Rectangle {
    id: btn
    property string glyph: ""
    property string label: ""
    property bool focused: false
    property bool spinning: false
    property color tint: Theme.text
    signal clicked
    implicitWidth: 74
    implicitHeight: 74
    radius: 8
    color: hover.containsMouse || focused ? Theme.raisedHover : Theme.raised
    border.width: focused ? 2 : 0
    border.color: Theme.highlight
    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 3
        Text {
            id: btnGlyph
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.glyph
            color: btn.tint
            font.family: Theme.fontFamily
            font.pixelSize: 24
            RotationAnimator on rotation {
                running: btn.spinning
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
            onRotationChanged: if (!btn.spinning && rotation !== 0)
                                   rotation = 0
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.label
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
