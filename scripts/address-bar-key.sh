#!/bin/sh
# Ctrl+L: open the island's Helium address editor when a Helium window has
# focus; otherwise hand the key back to whichever app has it.
[ "$(quickshell ipc call launcher address 2>/dev/null)" = "true" ] && exit 0
exec wtype -M ctrl -k l -m ctrl
