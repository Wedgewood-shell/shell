pragma Singleton
import QtQuick
import Quickshell

// State for the frozen-screen overlay used by region screenshots.
Singleton {
    property string path: ""
    property real originX: 0
    property real originY: 0
    property real scale: 1
    property var loadedScreens: ({})

    function report(name, ok) {
        loadedScreens[name] = ok
    }
    // True once every screen has its part of the picture decoded.
    function ready(): bool {
        if (path === "")
            return false
        for (const s of Quickshell.screens)
            if (!loadedScreens[s.name])
                return false
        return true
    }
    function show(file: string, x: real, y: real, s: real): void {
        loadedScreens = {}
        originX = x
        originY = y
        scale = s
        path = file
    }
    function hide(): void {
        path = ""
    }
}
