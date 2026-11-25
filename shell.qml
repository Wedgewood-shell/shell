//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    // Referencing the singleton installs system-event / presentation wiring.
    readonly property var integration: Integration
    readonly property var switcher: SwitcherController
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
    // Frozen picture of the screen while a region screenshot is selected.
    Variants {
        model: Quickshell.screens
        FreezeOverlay {}
    }
    // Window switcher list (Mod+Tab / Alt+Tab), drawn over the left module.
    Variants {
        model: Quickshell.screens
        SwitcherList {}
    }
}
