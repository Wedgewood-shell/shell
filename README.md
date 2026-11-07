# Dynamic Island shell

A Quickshell configuration for Niri. `shell.qml` composes the bar, menu window,
workspace HUD, IPC endpoints, and event wiring. It contains no feature logic.

## Layout

| Directory | Responsibility |
| --- | --- |
| `core/` | Theme, machine settings, island/overlay/workspace policy, IPC, event wiring |
| `services/` | System state, polling, Niri event stream, and command execution |
| `components/` | Shared pill, text, search field, action button, result list, menu-page contract |
| `bar/` | Per-screen bar, media, status indicators, system tray |
| `island/` | Compact island and individual animated alert views |
| `menus/` | Feature-specific models, actions, navigation, and custom content |
| `workspace/` | Workspace map and HUD presentation/animations |
| `scripts/` | Network event helper and smoke-check runner |
| `tests/` | Isolated QML smoke-check harness |

All exported QML types are registered explicitly in the root `qmldir`.
Files one directory deep import `".."`; files in `island/views/` import `"../.."`.
This is one local QML module; each feature directory does not need its own module.

## State and event flow

- Services expose system state and emit events. They do not open UI windows.
- `Integration.qml` connects service events to presentation controllers.
- `IslandController` owns the current alert, timeout, and Bluetooth alert payload.
  Alerts preserve the original policy: the latest event replaces the previous one
  and restarts the 2.2-second timeout.
- `OverlayController` owns menu mode, output selection, open/closing state,
  per-output island widths, and requests that an existing workspace HUD dismiss.
- `WorkspaceController` combines bursts of Niri changes into one HUD request,
  prioritizing a window move over a column shift over a workspace switch.
- `NiriService` owns the single Niri event stream and immutable window/workspace
  snapshots. The title, window search, and HUD share this state. It reconnects if
  its event-stream process exits.
- `MenuWindow` owns the layer-shell window, focus, shared search field and morph
  animation. Its Loader instantiates the selected menu page. Pages own their
  results, actions, navigation and content dimensions.
- `BluetoothService` owns pending pairing so switching pages does not lose it.

## Customize

Edit `core/Theme.qml` for shared colors, font, radii and animation timings.
Edit `core/Settings.qml` for backlight, AC, battery and temperature paths. Defaults
match this laptop; hardware discovery and polling optimizations are separate work.

Feature-specific labels, aliases and menu entries live in their respective files
under `menus/`. `components/ResultList.qml` renders both vertical results and
horizontal action tiles.

### Add a menu

1. Create `menus/ExampleMenu.qml` extending `MenuPage`.
2. Set `title`, `glyph`, and optionally `tiles`, `contentWidth`, `contentHeight`,
   `inputReadOnly`, `password`, or `showHeader`.
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
quickshell ipc call launcher wifi
quickshell ipc call launcher bluetooth
quickshell ipc call launcher session
quickshell ipc call launcher camera
```

Existing preview hooks also remain: `launcher btfake`, `launcher newdisplay`,
`island network <kind>`, `island brightness`, `island battery`, `island volume`,
and `island bluetooth`.

## Dependencies

Quickshell with Qt Quick, Wayland layer-shell support, Qt Multimedia, and its
Bluetooth, Networking, PipeWire, MPRIS, and system-tray modules; Niri; NetworkManager
(`nmcli`); `ip`; `powerprofilesctl`; Python 3; and FiraCode Nerd Font.
Actions additionally use Kitty, pavucontrol, swaylock, systemctl, and these existing
helpers in `~/.local/bin/`:

- `wifi-scan`, `wifi-connect`
- `capture-run`
- `display-layout`
- `island-tabs-ctl`, plus the browser-tab exporter producing
  `$XDG_RUNTIME_DIR/island-tabs.json`

Those external helpers are preserved. In particular, the existing Wi-Fi helper's
saved-profile deletion behavior has not been changed by this structural refactor.

## Validate and run

From a running Wayland session:

```sh
python3 ~/.config/quickshell/scripts/check.py
quickshell --no-duplicate
```

The checker copies the module into a temporary directory, runs a separate instance,
and checks menu creation, search, submenu navigation, title/layout state, null
workspace IDs, width limits, and alert routing. It keeps menus closed and does not
launch apps, connect devices, take photos, change display layouts, or execute
session/power actions. Camera capture, real network connections and multi-monitor
transitions still need hardware validation.

The smoke harness is launched through `scripts/check.py`, rather than directly:
Quickshell resolves the local module relative to its configuration entry point.

A pre-refactor backup is stored under `~/.local/state/quickshell-backups/`.
To roll back, stop the shell, restore that directory as `~/.config/quickshell/`,
and start `quickshell` again.
