import QtQuick
import Quickshell
import ".."

MenuPage {
    id: page
    title: "Search windows…"
    glyph: "\uf2d0"
    readonly property var windowAliases: ({
                                              "zapfast": "whatsapp"
                                          })
    function iconFor(appId) {
        const e = appId ? DesktopEntries.heuristicLookup(appId) : null
        return e && e.icon ? e.icon : (appId || "")
    }
    Connections {
        target: NiriService
        function onWindowDataChanged() {
            page.refresh()
        }
        function onTabDataChanged() {
            page.refresh()
        }
    }
    function filter(q) {
        q = q.trim().toLowerCase()

        // Search ranking: a match on the APP name (app id, desktop-entry name, alias) always beats a match
        // on the window title. Within each group: exact > starts-with > word-start > contains, then recency.
        const rank = text => {
            if (!text)
                return 0
            text = text.toLowerCase()
            if (text === q)
                return 4
            if (text.startsWith(q))
                return 3
            if (text.split(/[\s\-_.|:]+/).some(w => w.startsWith(q)))
                return 2
            return text.includes(q) ? 1 : 0
        }
        let items = NiriService.windowData.map(w => {
            const id = (w.app_id || "").toLowerCase()
            const entry = id ? DesktopEntries.heuristicLookup(w.app_id) : null
            const appRank = q ? Math.max(rank(w.app_id), rank(entry ? entry.name : ""), rank(page.windowAliases[id])) :
                                0

            const titleRank = q ? rank(w.title) : 0
            return {
                name: w.title,
                sub: w.app_id + "  ·  workspace " + w.ws + (w.focused ? "  ·  current" : ""),
                icon: page.iconFor(w.app_id),
                id: w.id,
                ts: w.ts,
                total: appRank > 0 ? 10 + appRank :
                                     titleRank        // app-name matches (11-14) outrank title matches (1-4)
            }
        })
        if (q) {
            items = items.filter(i => i.total > 0)
            items.sort((a, b) => (b.total - a.total) || (b.ts - a.ts))
        } else {
            items.sort((a, b) => b.ts - a.ts)
        }
        // Helium tabs that aren't already their window's visible tab (the active ones are the window entries above)
        const heliumIcon = page.iconFor("helide")
        let tabs = (NiriService.tabData || []).filter(t => !t.active).map(t => {
            let host = ""
            try {
                host = new URL(t.url).hostname.replace(/^www\./, "")
            } catch (e) {}
            return {
                name: t.title || t.url || "Untitled",
                sub: (host ? host + "  ·  " : "") + "tab",
                icon: heliumIcon,
                iconFile: t.icon || "",
                tab: t,
                ts: t.lastAccessed || 0,
                hay: ((t.title || "") + " " + (t.url || "")).toLowerCase()
            }
        })
        if (q)
            tabs = tabs.filter(i => i.hay.includes(q))
        tabs.sort((a, b) => b.ts - a.ts)
        return items.concat(tabs)
    }
    function initialIndex() {
        return query === "" && results.length > 1 ? 1 : 0
    }
    function activate(item) {
        if (!item)
            return
        OverlayController.launcherOpen = false
        if (item.tab) {
            Quickshell.execDetached(["sh", "-c",
                                     "exec \"$HOME/.local/bin/island-tabs-ctl\" activate \"$1\" \"$2\" \"$3\"", "sh",
                                     String(item.tab.id), String(item.tab.windowId), item.tab.title || ""])
        } else
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(item.id)])
    }
}
