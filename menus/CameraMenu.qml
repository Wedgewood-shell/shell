import QtQuick
import Quickshell
import ".."

MenuPage {
    showHeader: false
    inputReadOnly: true
    showResults: false
    contentWidth: panel.contentW
    contentHeight: panel.contentH
    function handleKey(key) {
        return panel.handleKey(key)
    }
    CameraPanel {
        id: panel
        anchors.fill: parent
    }
}
