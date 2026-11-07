#!/bin/sh
# Prints: active connections, "---", wifi rows, "---", wifi device metered flag + gateway.
nmcli -t -f TYPE,NAME,DEVICE connection show --active
echo ---
nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan no
echo ---
dev=$(nmcli -t -f TYPE,DEVICE connection show --active | awk -F: '$1=="802-11-wireless"{print $2; exit}')
if [ -n "$dev" ]; then
    nmcli -g GENERAL.METERED device show "$dev" 2>/dev/null
    ip -4 route show default dev "$dev" 2>/dev/null | awk '{print $3; exit}'
fi
