# Dynamic Island shell

A Quickshell configuration for Niri. `shell.qml` composes the bar, menu window,
workspace HUD, IPC endpoints, and event wiring. It contains no feature logic.

## Layout

| Directory | Responsibility |
| --- | --- |
| `core/` | Theme, machine settings, island/overlay/workspace policy, IPC, event wiring |
| `services/` | System state, polling, Niri event stream, and command execution |
| `components/` | Shared pill, text, search field, action button, result list, menu-page contract |
| `bar/` | Per-screen bar, capped window title, status indicators, system tray |
| `island/` | Compact island and individual animated alert views |
| `menus/` | Feature-specific models, actions, navigation, and custom content |
| `workspace/` | Workspace map and HUD presentation/animations |
| `scripts/` | Network event helper, window screenshot flattening, native build and smoke-check runner |
| `native/` | Live window-preview QML plugin (PipeWire) |
| `tests/` | Isolated QML smoke-check harness |

All exported QML types are registered explicitly in the root `qmldir`.
Files one directory deep import `".."`; files in `island/views/` import `"../.."`.
This is one local QML module; each feature directory does not need its own module.

## Resting bar layout

The left pill shows the focused window title, elided at a maximum width of
400 logical pixels (`Theme.windowTitleMaxWidth`). It retains the last title while
a menu owns keyboard focus.

Window switcher: Mod+Tab lists every window, Alt+Tab the focused app's windows (most
recently used first; Tab / Shift+Tab cycle, Escape cancels, releasing the modifier
switches). niri owns the keys and the selection (niri fork, `recent-windows { external }`,
see its FORK.md; Tab pressed just before Mod/Alt counts as Mod+Tab) and sends
`RecentWindowsChanged` events. `core/SwitcherController.qml` follows them and
`workspace/SwitcherList.qml` draws the list in place of the left module (which fades
out), after `SwitcherController.showDelay` (250 ms): a quick tap switches with no UI,
and a second Tab shows the list at once. `quickshell ipc call switcher demo <n>` /
`end` preview the list without the keys.

The island's resting state is date and time, in a fixed 300-pixel pill
(`Theme.islandBaseWidth`). The right status pill no longer duplicates the clock.
Transient alerts return to the current base state. Recording status remains in
the island.

Base states, by priority (`IslandController.baseMode`): Helium's address bar
(a Helium window focused) > media > clock. Any base other than the clock moves the
date/time into the bar's right module. Media (`MediaService`, MPRIS): the playing
player, else the last one that played; active while playing and for 30 s after
it pauses. Its view (`island/views/MediaView.qml`, 420 px) shows album art and
"title — artist" (a marquee when long); the track's progress is the pill's border,
filling clockwise from the top (`components/PerimeterProgress.qml`, shared with the
page-load ring), dimmed while paused. In the bar the media is drawn by
`bar/MediaChip.qml`, a pill lying exactly over the island (whose own media view is
off there). When the address bar takes the island, that pill detaches and
collapses to the right into a square chip beside it (one `collapse` value morphs
position, size, art and text together) while the island grows underneath; the
album art then fills the chip edge to edge. The reverse expands it back.
The status pill uses a larger battery indicator with the percentage inside while
on battery, a lightning bolt while charging, and a plug when externally powered
without charging. AC state is used to distinguish plugged-in from discharging.

The bar always reserves `Theme.barZone` (58 px), so ordinary windows never resize
when it changes mode. Full-width columns (niri fork `full-width-to-edges`, Mod+F)
reach under it instead, through the fork's `full-width-to-edges-top`: 40 in niri's
`layout {}` (= `Theme.compactBarHeight`), and 0 for smart-fullscreen apps via a
window rule (currently kitty, in `niri/window-rules.kdl`; the only list of them).

The bar reads the result from the window's geometry (`BarMode.spanKind`): as wide
as the output and taller than the space below the reservation means compact (a
flush, full-width strip of `Theme.compactBarHeight`, `Theme.compactBackground`,
modules scaled by `Theme.compactScale`); reaching the very top means smart
fullscreen, where the solid strip becomes a gradient (full tint at the top edge,
fading out a little past the strip). Maximize-to-edges (Mod+M) stops at the
reservation, so it keeps the normal bar.

The bar, window switcher and menu pill follow the same continuous value
(`core/BarMode.qml` via `components/BarModeFollower.qml`). It mirrors the niri
fork's full-width-to-edges blend: each full-width column's progress is
`smoothstep(1 - |column x - camera x - gap| / (25% of the output width))`, from the
live `view_pos` in niri's view stream. Adjacent full-width columns form a run that
blends as one (distance is to the run, not the column), so swiping between two
maximized windows stays compact; the solid/gradient tint crossfades between them.
Workspace switches crossfade by the vertical camera position. So the bar grows
and shrinks with swipes and niri's view animations, frame by frame; changes
without camera movement (maximizing in place) ease over `Theme.compactDuration`.

Both menu and workspace-HUD geometry use `components/IslandMorph.qml`: one
animation progress value interpolates width, height and radius together, with
coalesced target updates and support for reversal and live menu resizing.

## State and event flow

- Services expose system state and emit events. They do not open UI windows.
- `Integration.qml` connects service events to presentation controllers.
- `IslandController` owns the current alert, timeout, and Bluetooth alert payload.
  Alerts preserve the original policy: the latest event replaces the previous one
  and restarts the 2.2-second timeout.
- `OverlayController` owns menu mode, output selection, open/closing state,
  per-output island widths, and requests that an existing workspace HUD dismiss.
- `WorkspaceController` combines bursts of Niri changes into one HUD request,
  prioritizing a window move over a column shift over a workspace switch over a
  focus change within a workspace.
- `NiriService` owns the single Niri event stream and immutable window/workspace
  snapshots. The title, window search, and HUD share this state. It reconnects if
  its event-stream process exits.
- `MenuWindow` owns the layer-shell window, focus, shared search field and morph
  animation. Its Loader instantiates the selected menu page. Pages own their
  results, actions, navigation and content dimensions.
- `BluetoothService` owns pending pairing so switching pages does not lose it.

## Workspace HUD navigation

The HUD reveals a viewport over one persistent map of every workspace on the
current output. Workspace rows sit vertically; window columns extend horizontally
at a consistent scale. Switching workspaces pans vertically, while focusing
another window pans horizontally. Neighboring rows/columns fade through an alpha
mask at all four viewport edges. Workspace rows have no background or border;
windows in neighboring workspaces use the same gutter as neighboring columns.

Window delegates are keyed by window ID across the entire scene. Moving a window
to another workspace animates the same tile between rows. Incremental ID models
preserve the other tiles when a window opens or closes. There is no six-column
limit and no per-tile entrance animation. Floating windows are still omitted from
the scrolling-layout drawing, matching the previous HUD.

The map contents use 40% of their original size. Adjust `workspacePreviewScale`
in `core/Theme.qml` to resize window tiles and spacing. `workspaceIconScale`
independently enlarges icons (currently 1.5×), without changing tile geometry. The map
viewport shows 1.5 workspace heights. The full-size title and workspace indicators
sit to the left of the map, with no separator; the HUD height follows this content
size. Workspace labels inside the minimap are omitted.
`NiriService.layoutGap` supplies the shared gutter for rows and columns. Tune
`rowHeight` and `panDuration` in `workspace/WorkspaceMap.qml` for further changes.
The map stays instantiated while the HUD is hidden. Rapid navigation retargets the
current camera animation instead of rebuilding the scene. The native HUD surface
has a fixed width of 720 and a height derived from the resting content size. Its
content layout also stays fixed during the visible pill's morph, avoiding per-frame
Wayland surface resizes and header relayout.
The map reveal, camera pan, tile movement and pill expansion start together;
panning and the pill morph share a 400 ms duration. There is no delayed reveal
or pan timer. Before opening a closed HUD, a saved snapshot primes the starting
geometry for a move, shift or focus change and is released in the same event turn.

`components/IslandHandoff.qml` coordinates the menu/HUD surface with the bar.
The bar is hidden only after the front surface presents a frame. On collapse,
actual morph completion releases the bar, then the front surface stays mapped
through the bar's fade and two additional rendered frames. A copy of the normal
island content fades in during collapse, so there is no empty-pill interval.
Menu content keeps its expanded layout during clipping. Its fade and the returning
island title's fade follow collapse geometry, rather than cutting out after a
fixed 90 ms or overlapping two titles for most of the transition. The system tray hides both
`nm-applet` and `blueman`, whose functions are provided by the custom menus.


## Customize

Edit `core/Theme.qml` for shared colors, font, radii and animation timings.

Colors come from the Kitty palette, using the same role mapping as the GTK theme
(`background` surfaces, `color0` raised tiles, `color8` borders, `color15` text,
`foreground` muted text, `color4` accent, `color1`/`2`/`3` danger/success/warning).
The palette is a snapshot between the `kitty palette` markers in `Theme.qml`;
after changing Kitty's colors, run `python3 scripts/sync-kitty-theme.py` and
restart Quickshell. Components use only `Theme` roles, never literal colors.
Edit `core/Settings.qml` for backlight, AC, battery and temperature paths. Defaults
match this laptop; hardware discovery and polling optimizations are separate work.

Feature-specific labels, aliases and menu entries live in their respective files
under `menus/`. `components/ResultList.qml` renders both vertical results and
horizontal action tiles.

### Add a menu

1. Create `menus/ExampleMenu.qml` extending `MenuPage`.
2. Set `title`, `glyph`, and optionally `tiles`, `contentWidth`, `contentHeight`,
   `inputReadOnly`, `password`, or `showHeader`. Set `detail` (a Component) and
   `detailHeight` for a separate surface shown below the pill, like the capture
   menu's live preview.
3. Override `filter(query)` and `activate(item)`. Override `handleKey(key)` for
   submenu navigation; return `true` when handled. `clearQuery()` asks the frame
   to clear and focus the search field. Use a service for external commands.
4. Call `refresh()` when an external model or submenu stage changes. The base
   page already refreshes when the search query changes.
5. Register the type in `qmldir`, add its Component and mode to `MenuWindow.pages`,
   then expose its launcher command in `core/IpcEndpoints.qml` if needed.
6. Add a smoke assertion for its navigation or model behavior.

### Add an alert

1. Create a view in `island/views/`, importing `"../.."`.
2. Expose its content through `implicitWidth` and animate its `active` state.
   Draw freely inside the island, overlays included (edge fades, masks): its border
   is a `Frame` (`components/Frame.qml`) stacked above the views (`z: 100`), so
   nothing a view draws can cover it. Fill fades with `Theme.surface`; anything
   meant to sit on the border itself goes above it (the page-load ring uses `z: 101`).
3. Register the type in `qmldir`, instantiate it in `island/Island.qml`, and include
   its width in the mode selection there.
4. Emit a signal from its service and route it in `Integration.qml` using
   `IslandController.show("example")`. Keep transient payloads in the controller.

## Existing IPC commands

Niri keybindings remain compatible:

```sh
quickshell ipc call launcher toggle
quickshell ipc call launcher windows
quickshell ipc call launcher capture
quickshell ipc call launcher power
quickshell ipc call launcher display
quickshell ipc call launcher audio       # Copilot+A (Alt+Shift+A)
quickshell ipc call launcher wifi
quickshell ipc call launcher bluetooth
quickshell ipc call launcher session
quickshell ipc call launcher camera
```

The **Audio** menu sets the default output and microphone and lets you mute or
reroute individual playback and recording streams. Start playing or recording in
an app first so its stream is listed. Routes are remembered for returning streams
by WirePlumber (`node.stream.restore-target`, enabled by default). The menu uses
`pactl` with `pipewire-pulse`. Set `hideDisconnectedHdmi` in
`core/Settings.qml` to `false` to show unplugged HDMI/DisplayPort outputs in the
Audio menu's device pickers. It is enabled by default and does not change
system-wide audio settings.

hyprbeam launcher (Mod+Space; menu mode `hyprbeam`), a frontend for the
hyprbeam daemon (`~/Projects/hyprbeam`) (apps, calculator, niri windows, plugins):

```sh
quickshell ipc call launcher hyprbeam
```

`services/HyprbeamService.qml` keeps one `~/.local/bin/hyprbeam pipe` process (a
JSON-lines bridge over a single daemon connection, since QML can't speak the
MessagePack frames) running once the launcher has been opened. Each keystroke is
a query; result frames for older queries are dropped, and later frames (plugins)
keep the selected item. Matched characters are tinted with `Theme.highlight`.
Tab or Ctrl+K opens the selected item's actions ("Open" plus its secondary
actions), which the field then filters; Tab, Ctrl+K, Escape or Backspace on an
empty field return to the results with the query restored. If the daemon is
unreachable the menu shows the error and the bridge retries at most once a second.

Browser results (tabs, bookmarks, history from hyprbeam's `helide` plugin) are only
*found* by hyprbeam: their `data.kind` is `browser-tab` or `browser-url`, and the menu
opens them itself. A tab is switched to through `island-tabs-ctl`, as in the Windows
menu. A URL opens in a new tab with `helium-browser`, or with the "Open in Current Tab"
action through `HeliumService.navigate`, and the most recent Helium window is then
focused. "Copy URL" uses `wl-copy`.

Voice conversation (ephemeral island state `voice`, driven by the `ttsd` / `sttd` user services):

```sh
quickshell ipc call voice say "text"            # assistant speaking; long text scrolls
quickshell ipc call voice sayEnd
quickshell ipc call voice startListening        # user's reply: live transcript follows
quickshell ipc call voice partial "text so far"
quickshell ipc call voice finish "text" ok      # status: ok | nopi; empty text = nothing heard
quickshell ipc call voice idle
```

Existing preview hooks also remain: `launcher btfake`, `launcher newdisplay`,
`island network <kind>`, `island brightness`, `island battery`, `island volume`,
and `island bluetooth`.

## Dependencies

Quickshell with Qt Quick, Wayland layer-shell support, Qt Multimedia, and its
Bluetooth, Networking, PipeWire and system-tray modules; Niri; NetworkManager
(`nmcli`); `ip`; `powerprofilesctl`; Python 3; SF Pro Display for text
(AUR `nerd-fonts-apple-hinted`, built without Nerd patching so the family keeps
its name); and FiraCode Nerd Font, which fontconfig falls back to for the icon
glyphs. Changing numbers use tabular figures (`Theme.tabularFigures`).
The hyprbeam menu needs `hyprbeamd` (socket-activated user unit) and the
`hyprbeam` CLI with its `pipe` command in `~/.local/bin/`.
Actions additionally use Kitty, pavucontrol, swaylock, systemctl, and these existing
helpers in `~/.local/bin/`:

- `wifi-scan`, `wifi-connect`
- `capture-run`
- `display-layout`
- `island-tabs-ctl`, plus the browser-tab exporter producing
  `$XDG_RUNTIME_DIR/island-tabs.json`

The capture menu's live window preview is a small native QML plugin in `native/`
(Qt 6 Quick/DBus, GStreamer app/video/allocators, PipeWire's GStreamer plugin).
Build it once, and again after Qt upgrades:

```sh
~/.config/quickshell/scripts/build-native.sh
```

It asks Niri's `org.gnome.Mutter.ScreenCast` D-Bus API for one PipeWire stream of
the highlighted window only; the stream is retargeted as the selection changes and
stopped when the picker closes. No screenshots, files, or clipboard writes are
involved. Without the build, the menu still works and shows an icon placeholder.
`tests/live-preview.qml` is an opt-in check that opens one real stream:
`CAPTURE_TEST_WINDOW=<niri window id> quickshell --path tests/live-preview.qml`.

Window screenshots use `niri msg action screenshot-window` followed by
`scripts/window-shot.py`, which composites the window geometry over black while
leaving client-side shadows and rounded-corner cutouts untouched.

Region screenshots freeze the screen first: `scripts/capture-run` grabs the desktop
with `grim`, shows it through `core/FreezeOverlay.qml` (IPC target `freeze`) under
`slurp`, and crops the result from that same picture with `scripts/freeze.py`. After
any screenshot, focus goes back to the window that had it before.

Those external helpers are preserved. In particular, the existing Wi-Fi helper's
saved-profile deletion behavior has not been changed by this structural refactor.

## Validate and run

From a running Wayland session:

```sh
python3 ~/.config/quickshell/scripts/check.py
python3 ~/.config/quickshell/scripts/check.py --transitions
quickshell --no-duplicate
```

The `--transitions` checks briefly show test surfaces without taking keyboard focus
and exercise the actual render/close/reopen handoff. The default smoke checker
copies the module into a temporary directory, runs a separate instance,
and checks menu creation, search, submenu navigation, title/layout state, null
workspace IDs, width limits, alert routing, full-map coverage, camera coordinates,
and window-delegate identity across panning, moving and closing windows. It keeps menus closed and does not
launch apps, connect devices, take photos, change display layouts, or execute
session/power actions. Camera capture, real network connections and multi-monitor
transitions still need hardware validation.

The smoke harness is launched through `scripts/check.py`, rather than directly:
Quickshell resolves the local module relative to its configuration entry point.

A pre-refactor backup is stored under `~/.local/state/quickshell-backups/`.
To roll back, stop the shell, restore that directory as `~/.config/quickshell/`,
and start `quickshell` again.
