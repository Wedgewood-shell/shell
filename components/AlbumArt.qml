import QtQuick
import Quickshell.Widgets
import ".."

// Rounded album art, or a music note while there is none (or it hasn't loaded).
ClippingRectangle {
    id: art
    property string source: ""
    radius: 6
    color: Theme.raised

    Image {
        id: image
        anchors.fill: parent
        source: art.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        // Decode at the displayed size (sharp, and no full-size cover in memory).
        sourceSize.width: Math.ceil(art.width * 2)
        sourceSize.height: Math.ceil(art.height * 2)
        visible: status === Image.Ready
    }
    IconLabel {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: Theme.cp(0xF075A)    // music note
        color: Theme.muted
        font.pixelSize: Math.round(art.height * 0.55)
        font.weight: Font.Normal
    }
}
