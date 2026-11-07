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
    WindowTitlePill { id: windowTitle; visible: false }
    WorkspaceMap {
        id: atlas
        width: 396
        height: 258
        outputName: "fixture"
        visible: false
        animateChanges: false
    }
    function batteryChecks() {
        const previous = { known: BatteryService.acKnown, onBat: BatteryService.onBat, status: BatteryService.batteryStatus }
        try {
            BatteryService.acKnown = true
            BatteryService.onBat = false
            BatteryService.batteryStatus = "Charging"
            check(BatteryService.plugged && BatteryService.charging, "AC charging uses bolt state")
            BatteryService.batteryStatus = "Not charging"
            check(BatteryService.plugged && !BatteryService.charging, "AC charge limit uses plug state")
            BatteryService.batteryStatus = "Full"
            check(BatteryService.plugged && !BatteryService.charging, "full battery on AC uses plug state")
            BatteryService.onBat = true
            BatteryService.batteryStatus = "Charging"
            check(!BatteryService.plugged && !BatteryService.charging, "unplug overrides stale charging status")
            BatteryService.acKnown = false
            BatteryService.batteryStatus = ""
            check(!BatteryService.plugged, "unknown battery status is not treated as plugged in")
        } finally {
            BatteryService.acKnown = previous.known
            BatteryService.onBat = previous.onBat
            BatteryService.batteryStatus = previous.status
        }
    }
    function mapChecks() {
        atlas.workspaceData = {
            1: {
                id: 1,
                idx: 1,
                output: "fixture",
                active_window_id: 100
            },
            2: {
                id: 2,
                idx: 2,
                output: "fixture",
                active_window_id: 107
            },
            3: {
                id: 3,
                idx: 3,
                output: "other"
            }
        }
        const windows = {}
        for (let i = 0; i < 8; i++)
            windows[100 + i] = {
                id: 100 + i,
                app_id: "kitty",
                workspace_id: i < 7 ? 1 : 2,
                is_focused: i === 0,
                layout: {
                    pos_in_scrolling_layout: [i < 7 ? i : 0, 0],
                    tile_size: [800, 900]
                }
            }
        atlas.wins = windows
        check(atlas.workspaceCount === 2, "all workspaces on output retained")
        check(atlas.tileCount === 8, "all windows instantiated together")
        const a = atlas.scene.tiles[100], b = atlas.scene.tiles[101], below = atlas.scene.tiles[107]
        const horizontalGap = b.x - a.x - a.w, verticalGap = below.y - a.y - a.h
        check(Math.abs(horizontalGap - verticalGap) < 0.000001, "workspace vertical gutter matches window horizontal gutter")
        check(NiriService.computeLayout(1, windows).tiles.length === 7, "offscreen columns retained")
        const first = atlas.tileItem(100), moving = atlas.tileItem(106)
        check(first !== null && moving !== null, "tiles exist before navigation")
        const start = atlas.focusPoint(1, 100), far = atlas.focusPoint(1, 106)
        atlas.panTo(1, 100, false)
        check(atlas.cameraX === start.x, "camera starts at focused column")
        atlas.panTo(1, 106, false)
        check(atlas.cameraX === far.x && far.x > start.x, "camera pans across full horizontal map")
        check(atlas.tileItem(100) === first, "panning preserves window delegates")
        atlas.panTo(2, 107, false)
        check(atlas.cameraY === atlas.focusPoint(2, 107).y, "camera pans vertically between workspaces")
        const moved = Object.assign({}, windows, {
            106: Object.assign({}, windows[106], {
                workspace_id: 2
            })
        })
        atlas.wins = moved
        check(atlas.tileItem(106) === moving, "cross-workspace move preserves same tile")
        check(atlas.scene.tiles[106].ws === 2, "moved tile has destination coordinates")
        const closed = Object.assign({}, moved)
        delete closed[107]
        atlas.wins = closed
        check(atlas.tileCount === 7 && atlas.tileItem(107) === null, "closed window removed")
        check(atlas.tileItem(100) === first && atlas.tileItem(106) === moving, "other delegates survive window close")
        atlas.wins = Object.assign({}, closed, {
            108: {
                id: 108,
                app_id: "kitty",
                workspace_id: null
            }
        })
        check(atlas.tileItem(108) !== null && !atlas.tileItem(108).tile, "unassigned window retained without drawing a tile")
        WorkspaceController.pending = ({})
        const before = {
            1: {
                id: 1,
                idx: 1,
                output: "test",
                is_active: true
            }
        }
        WorkspaceController.handle({
            WorkspaceActivated: {
                id: 2
            }
        }, {}, before)
        check(WorkspaceController.pending.switch.from === 1, "workspace pan includes previous workspace")
        WorkspaceController.pending = ({})
        NiriService.windows = {
            11: {
                id: 11,
                workspace_id: 1,
                is_focused: true
            }
        }
        WorkspaceController.handle({
            WindowFocusChanged: {
                id: 11
            }
        }, {
            10: {
                id: 10,
                workspace_id: 1,
                is_focused: true
            }
        }, {})
        check(WorkspaceController.pending.focus.id === 11 && WorkspaceController.pending.focus.fromId === 10, "window focus requests horizontal pan")
        WorkspaceController.pending = ({})
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
                    test.check(WorkspaceController.hudWs === -1 && WorkspaceController.hudFrom === -1, "null workspace IDs normalized")
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
                    IslandController.islandMode = "clock"
                } else if (test.step === 2) {
                    test.check(windowTitle.implicitWidth <= Theme.windowTitleMaxWidth, "left window title is capped")
                    test.check(island.implicitWidth === Theme.islandBaseWidth, "clock has stable base width")
                    NiriService.handle({WindowFocusChanged: {id: null}})
                    test.check(island.implicitWidth === Theme.islandBaseWidth, "focus loss does not shrink the clock island")
                    NiriService.handle({WindowFocusChanged: {id: 10}})
                    test.select("apps")
                    test.check(menu.page.filter("a-nonexistent-application-9988").length === 0, "application filtering")
                    test.select("windows")
                    test.check(menu.page.filter("kitty").length === 1, "window app search")
                    test.select("capture")
                    menu.page.activate(menu.page.results.find(i => i.cap === "screenshot"))
                    test.check(CaptureService.captureStage === "scope", "capture submenu")
                    test.check(menu.page.handleKey(Qt.Key_Escape) && CaptureService.captureStage === "kind", "capture back")
                    test.select("session")
                    menu.page.activate(menu.page.results.find(i => i.act === "reboot"))
                    test.check(SessionService.sessionStage === "reboot", "reboot submenu")
                    test.check(menu.page.handleKey(Qt.Key_Backspace) && SessionService.sessionStage === "main", "session back")
                    DisplayService.externalCount = 1
                    test.select("display")
                    menu.page.activate(menu.page.results.find(i => i.act === "extend"))
                    test.check(DisplayService.displayStage === "extend", "display submenu")
                    test.check(menu.page.handleKey(Qt.Key_Escape) && DisplayService.displayStage === "main", "display back")
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
                    test.check(!IslandController.btUp && IslandController.islandMode === "bluetooth", "Bluetooth alert route")
                    test.mapChecks()
                    test.batteryChecks()
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
