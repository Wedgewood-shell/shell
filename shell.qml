//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    // Referencing the singleton installs system-event / presentation wiring.
    readonly property var integration: Integration
    IpcEndpoints {}
    MenuWindow {}
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    // Left module: focused window + window/workspace switcher.
    Variants {
        model: Quickshell.screens
        WindowSwitcher {}
    }
}
