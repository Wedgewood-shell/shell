import QtQuick
import Quickshell
import ".."

MenuPage {
    title: "Bluetooth"
    glyph: "\uf293"
    inputReadOnly: true
    showResults: false
    contentWidth: 600
    contentHeight: 50 + panel.contentH
    function handleKey(key) {
        return panel.handleKey(key)
    }
    BluetoothPanel {
        id: panel
        y: 50
        width: parent.width
    }
}
