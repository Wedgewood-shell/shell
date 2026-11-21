# Agent notes

## Reloading

Quickshell's auto-reload does not pick up edits to this config (it is reached
through the `~/.config/quickshell` symlink). After changing any file, kill the
running instance and start a new one detached through niri:

```sh
quickshell kill
niri msg action spawn -- quickshell --no-duplicate
```

Confirm the new instance loaded with `quickshell log | grep -i error` (or
`quickshell ipc show` for new IPC functions).
