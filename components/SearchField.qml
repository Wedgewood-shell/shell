import QtQuick
import Quickshell
import ".."

TextInput {
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.text
    passwordCharacter: "•"
    selectionColor: Theme.highlight
    font.family: Theme.fontFamily
    font.pixelSize: 15
    clip: true
}
