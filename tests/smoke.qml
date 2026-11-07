//@ pragma UseQApplication
import QtQuick
import Quickshell
import ".."

ShellRoot {
    id: test
    MenuWindow {
        id: menu
    }
    Island {
        id: island
        visible: false
    }
    property int step: 0
    property int assertions: 0
    function check(condition, message) {
        if (!condition)
            throw new Error("FAIL: " + message)
        assertions++
    }
    function select(mode) {
        OverlayController.launcherMode = mode
        check(menu.page !== null, mode + " loads")
        menu.page.query = ""
        menu.page.refresh()
        check(menu.page.contentWidth > 0 && menu.page.contentHeight > 0, mode + " geometry")
    }
    Timer {
        interval: 600
        running: true
        repeat: true
        onTriggered: {
            try {
                if (test.step === 0) {
                    NiriService.live = false
                } else if (test.step === 1) {
                    NiriService.handle({
                                           WorkspacesChanged: {
                                               workspaces: [
                                                   {
                                                       id: 1,
                                                       idx: 1,
                                                       output: "test",
                                                       is_active: true,
                                                       is_focused: true
                                                   },
                                                   {
                                                       id: 2,
                                                       idx: 2,
                                                       output: "test"
                                                   }
                                               ]
                                           }
                                       })
                    NiriService.handle({
                                           WindowsChanged: {
                                               windows: [
                                                   {
                                                       id: 10,
                                                       title: "Test title",
                                                       app_id: "kitty",
                                                       workspace_id: 1,
                                                       is_focused: true,
                                                       layout: {
                                                           pos_in_scrolling_layout: [0, 0],
                                                           tile_size: [800, 600]
                                                       }
                                                   }
                                               ]
                                           }
                                       })
                    test.check(NiriService.windowTitle === "Test title", "shared focused title")
                    test.check(NiriService.windowData[0].ws === 1, "window workspace label")
                    test.check(NiriService.computeLayout(1, NiriService.windows).W === 800, "workspace layout")
                    NiriService.handle({
                                           WindowFocusChanged: {
                                               id: null
                                           }
                                       })
                    test.check(NiriService.windowTitle === "", "null focus clears title")
                    WorkspaceController.fire("move", {
                                                 ws: null,
                                                 from: null
                                             })
                    test.check(WorkspaceController.hudWs === -1 && WorkspaceController.hudFrom === -1,
                               "null workspace IDs normalized")
                    NiriService.handle({
                                           WindowOpenedOrChanged: {
                                               window: {
                                                   id: 10,
                                                   title: "x".repeat(300),
                                                   app_id: "kitty",
                                                   workspace_id: 1,
                                                   is_focused: true
                                               }
                                           }
                                       })
                    IslandController.islandMode = "window"
                } else if (test.step === 2) {
                    test.check(island.implicitWidth <= 596, "long titles capped")
                    test.select("apps")
                    test.check(menu.page.filter("a-nonexistent-application-9988").length === 0, "application filtering")
                    test.select("windows")
                    test.check(menu.page.filter("kitty").length === 1, "window app search")
                    test.select("capture")
                    menu.page.activate(menu.page.results.find(i => i.cap === "screenshot"))
                    test.check(CaptureService.captureStage === "scope", "capture submenu")
                    test.check(menu.page.handleKey(Qt.Key_Escape) && CaptureService.captureStage === "kind",
                               "capture back")
                    test.select("session")
                    menu.page.activate(menu.page.results.find(i => i.act === "reboot"))
                    test.check(SessionService.sessionStage === "reboot", "reboot submenu")
                    test.check(menu.page.handleKey(Qt.Key_Backspace) && SessionService.sessionStage === "main",
                               "session back")
                    DisplayService.externalCount = 1
                    test.select("display")
                    menu.page.activate(menu.page.results.find(i => i.act === "extend"))
                    test.check(DisplayService.displayStage === "extend", "display submenu")
                    test.check(menu.page.handleKey(Qt.Key_Escape) && DisplayService.displayStage === "main",
                               "display back")
                    test.select("power")
                    test.check(menu.page.results.length === 3, "power profiles")
                    test.select("wifi")
                    WifiService.wifiData = {
                        current: {
                            kind: "none"
                        },
                        wifi: {
                            radio: "enabled",
                            connected: false
                        },
                        networks: [
                            {
                                ssid: "Test network",
                                secure: true,
                                saved: false,
                                signal: 80
                            }
                        ]
                    }
                    menu.page.refresh()
                    menu.page.activate(menu.page.results[0])
                    test.check(WifiService.wifiStage === "password", "Wi-Fi password stage")
                    test.check(menu.page.password && menu.page.handleKey(Qt.Key_Escape), "Wi-Fi back")
                    test.select("bluetooth")
                    test.check(menu.page.handleKey(Qt.Key_Right), "Bluetooth keyboard navigation")
                    test.select("camera")
                    test.check(!menu.page.showHeader && menu.page.contentWidth === 480, "camera page geometry")
                    test.check(!OverlayController.launcherOpen, "smoke checks keep menus closed")
                    IslandController.showVolume()
                    test.check(IslandController.islandMode === "volume", "volume alert route")
                    IslandController.showBluetooth({
                                                       name: "Test"
                                                   }, false)
                    test.check(!IslandController.btUp && IslandController.islandMode === "bluetooth",
                               "Bluetooth alert route")
                    console.log("SMOKE PASS: " + test.assertions + " assertions")
                    Qt.quit()
                }
                test.step++
            } catch (error) {
                console.error(error)
                Qt.quit()
            }
        }
    }
}
