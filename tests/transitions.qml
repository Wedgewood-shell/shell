//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Native-surface regression checks. No compositor navigation or menu actions.
ShellRoot {
    id: test
    property int step: 0
    property int assertions: 0
    property real closingWidth: 0
    property real closingHeight: 0
    property string outputName: Quickshell.screens[0].name
    MenuWindow {
        id: menu
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }
    WorkspaceHud {
        id: hud
    }

    function check(condition, message) {
        if (!condition)
            throw new Error("FAIL: " + message)
        assertions++
    }
    function menuPill() {
        for (const child of menu.contentItem.children)
            if (child.clip && typeof child.radius === "number")
                return child
        return null
    }
    Timer {
        id: collapseProbe
        interval: 120
        onTriggered: {
            try {
                const pill = test.menuPill()
                const horizontal = (test.closingWidth - pill.width) / (test.closingWidth - menu.closedWidth)
                const vertical = (test.closingHeight - pill.height) / (test.closingHeight - Theme.barHeight)
                test.check(horizontal > 0 && horizontal < 1 && vertical > 0 && vertical < 1, "width and height are both shrinking before collapse ends")
                test.check(Math.abs(horizontal - vertical) < 0.0001, "width and height share the same collapse progress")
            } catch (error) {
                console.error(error)
                Qt.quit()
            }
        }
    }
    Timer {
        id: advance
        interval: 250
        running: true
        function later(ms) {
            interval = ms
            restart()
        }
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    NiriService.live = false
                    NiriService.workspaces = {
                        1: {
                            id: 1,
                            idx: 1,
                            output: test.outputName,
                            active_window_id: 10
                        },
                        2: {
                            id: 2,
                            idx: 2,
                            output: test.outputName,
                            active_window_id: 20
                        }
                    }
                    NiriService.windows = {
                        10: {
                            id: 10,
                            workspace_id: 1,
                            app_id: "kitty",
                            layout: {
                                pos_in_scrolling_layout: [0, 0],
                                tile_size: [800, 900]
                            }
                        },
                        20: {
                            id: 20,
                            workspace_id: 2,
                            app_id: "kitty",
                            layout: {
                                pos_in_scrolling_layout: [0, 0],
                                tile_size: [800, 900]
                            }
                        }
                    }
                    OverlayController.launcherScreen = test.outputName
                    OverlayController.setIslandWidth(test.outputName, 400)
                    OverlayController.launcherMode = "apps"
                    OverlayController.launcherOpen = true
                    const serial = WorkspaceController.hudSerial
                    WorkspaceController.fire("switch", {
                        ws: 2,
                        from: 1
                    })
                    test.check(WorkspaceController.hudSerial === serial, "menu intent suppresses HUD before first frame")
                    later(500)
                    break
                case 1:
                    test.check(menu.visible && OverlayController.launcherBusy, "menu covers base after presenting")
                    test.closingWidth = test.menuPill().width
                    test.closingHeight = test.menuPill().height
                    OverlayController.launcherOpen = false
                    collapseProbe.restart()
                    const closingHeight = menu.layoutHeight
                    menu.page.results = []
                    test.check(menu.layoutHeight === closingHeight, "closing layout stays frozen if results change")
                    later(430)
                    break
                case 2:
                    test.check(menu.visible, "collapsed menu stays mapped while base returns")
                    test.check(menu.closedWidth === 400, "menu returns to the measured bar width")
                    test.check(!OverlayController.launcherBusy, "base is released after menu morph")
                    OverlayController.launcherOpen = true
                    later(120)
                    break
                case 3:
                    test.check(menu.visible && OverlayController.launcherBusy, "reopen cancels pending menu unmap")
                    OverlayController.launcherOpen = false
                    later(700)
                    break
                case 4:
                    test.check(!menu.visible && !OverlayController.launcherBusy, "menu unmaps after complete handoff")
                    WorkspaceController.fire("switch", {
                        ws: 2,
                        from: 1
                    })
                    later(120)
                    break
                case 5:
                    test.check(hud.visible && WorkspaceController.hudBusy, "HUD covers base after presenting")
                    hud.open = false
                    later(430)
                    break
                case 6:
                    test.check(hud.visible, "collapsed HUD stays mapped while base returns")
                    test.check(hud.closedWidth === 400, "HUD returns to the measured bar width")
                    test.check(!WorkspaceController.hudBusy, "base is released after HUD morph")
                    later(700)
                    break
                case 7:
                    test.check(!hud.visible && !WorkspaceController.hudBusy, "HUD unmaps after complete handoff")
                    console.log("TRANSITIONS PASS: " + test.assertions + " assertions")
                    Qt.quit()
                }
            } catch (error) {
                console.error(error)
                Qt.quit()
            }
        }
    }
}
