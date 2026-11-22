import QtQuick
import Quickshell
import ".."

// Frontend for the hyprbeam daemon (services/HyprbeamService.qml): apps, calculator,
// niri windows and plugins, ranked daemon-side. Tab or Ctrl+K opens the selected
// item's actions (Raycast-style); the field then filters them, and Tab, Ctrl+K,
// Escape or Backspace on an empty field go back to the results.
MenuPage {
    id: page
    title: actionsFor ? "Actions for " + actionsFor.title : "Search apps, windows, tabs, math…"
    glyph: actionsFor ? Theme.cp(0xF140B) : Theme.cp(0xF0349)
    // The item whose actions are listed, or null for the results.
    property var actionsFor: null
    // The results query and selection, restored when the actions list closes.
    property string savedQuery: ""
    property string savedId: ""
    property string lastQuery: "\u0000"
    readonly property var providerGlyphs: ({
            "calc": Theme.cp(0xF00EC),
            "niri": "\uf2d0"
        })

    Connections {
        target: OverlayController
        // The next open starts over: a fresh query (frecency may have changed), no actions list.
        function onLauncherOpenChanged() {
            if (!OverlayController.launcherOpen)
                page.lastQuery = "\u0000"
        }
    }
    Connections {
        target: HyprbeamService
        function onItemsChanged() {
            if (!page.actionsFor)
                page.refresh()
        }
        function onErrorChanged() {
            if (!page.actionsFor)
                page.refresh()
        }
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }
    // `highlights` are code-point indices into the title.
    function markup(title, hl) {
        if (!hl || !hl.length)
            return ""
        const set = new Set(hl)
        const color = Theme.highlight.toString()
        let out = ""
        let i = 0
        for (const ch of Array.from(title)) {
            out += set.has(i) ? "<font color=\"" + color + "\">" + escapeHtml(ch) + "</font>" : escapeHtml(ch)
            i++
        }
        return out
    }
    function wrap(it) {
        const icon = it.icon || ""
        return {
            name: it.title,
            markup: markup(it.title, it.highlights),
            sub: it.subtitle || "",
            subMax: 260,
            subElideRight: true,
            icon: icon.startsWith("/") ? "" : icon,
            iconFile: icon.startsWith("/") ? icon : "",
            glyph: icon ? "" : (providerGlyphs[it.provider] || ""),
            item: it
        }
    }
    function filter(q) {
        if (actionsFor) {
            const it = actionsFor
            const all = [{
                    name: "Open",
                    glyph: Theme.cp(0xF03CC),
                    sub: it.title,
                    item: it,
                    action: null
                }].concat((it.actions || []).map(a => ({
                                                        name: a.title,
                                                        glyph: Theme.cp(0xF0142),
                                                        item: it,
                                                        action: a.id
                                                    })))
            const s = q.trim().toLowerCase()
            return s ? all.filter(a => a.name.toLowerCase().includes(s)) : all
        }
        if (HyprbeamService.error && HyprbeamService.queryText === q)
            return [{
                    name: "hyprbeam is unavailable",
                    sub: HyprbeamService.error,
                    glyph: "\uf071",
                    tint: Theme.warning
                }]
        // Frames for an older query (still arriving) don't belong to this one.
        if (HyprbeamService.queryText !== q)
            return results
        return HyprbeamService.items.map(wrap)
    }
    function refresh() {
        if (lastQuery === "\u0000")
            actionsFor = null
        if (!actionsFor && query !== lastQuery) {
            lastQuery = query
            HyprbeamService.query(query)
            return
        }
        // Later frames (plugins) replace the list: keep the selected item if it's still there.
        const keepId = results[currentIndex] && results[currentIndex].item ? results[currentIndex].item.id : ""
        results = filter(query)
        const i = keepId ? results.findIndex(r => r.item && r.item.id === keepId && !r.action) : -1
        currentIndex = i >= 0 ? i : 0
    }
    function openActions() {
        const r = results[currentIndex]
        if (!r || !r.item)
            return false
        savedQuery = query
        savedId = r.item.id
        actionsFor = r.item
        results = []
        clearQuery()
        refresh()
        return true
    }
    function closeActions() {
        actionsFor = null
        results = []
        lastQuery = savedQuery     // the results for it are still in the service
        setQuery(savedQuery)
        refresh()
        const i = results.findIndex(r => r.item && r.item.id === savedId)
        currentIndex = Math.max(0, i)
    }
    function handleEvent(event) {
        const ctrlK = event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)
        if (event.key === Qt.Key_Tab || ctrlK) {
            if (actionsFor)
                closeActions()
            else
                openActions()
            return true
        }
        return false
    }
    function handleKey(key) {
        if (actionsFor && (key === Qt.Key_Escape || (key === Qt.Key_Backspace && query === ""))) {
            closeActions()
            return true
        }
        return false
    }
    function activate(r) {
        if (!r || !r.item)
            return
        OverlayController.launcherOpen = false
        const d = r.item.data || {}
        if (d.kind === "browser-tab" || d.kind === "browser-url")
            openBrowserItem(d, r.action || null)
        else if (d.kind === "file")
            openFileItem(d, r.action || null)
        else
            HyprbeamService.activate(r.item.id, r.action || null)
    }
    // File results (hyprbeam's files plugin) are only found daemon-side; the shell opens them.
    function openFileItem(d, action) {
        if (action === "copy") {
            Quickshell.execDetached(["wl-copy", "--", d.path])
            return
        }
        if (action === "reveal") {
            // Select the item in the file manager; fall back to opening its folder.
            const uri = "file://" + d.path.split("/").map(encodeURIComponent).join("/")
            Quickshell.execDetached(["sh", "-c",
                                     "busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1 ShowItems ass 1 \"$1\" \"\" || exec xdg-open \"$(dirname \"$2\")\"", "sh", uri, d.path])
            return
        }
        Quickshell.execDetached(["xdg-open", d.path])
    }
    // Browser results (hyprbeam's helide plugin) are only found daemon-side; the shell opens them.
    function openBrowserItem(d, action) {
        if (action === "copy") {
            Quickshell.execDetached(["wl-copy", "--", d.url])
            return
        }
        if (d.kind === "browser-tab" && !action) {
            // Same path as the Windows menu: switch tab, then focus its niri window.
            Quickshell.execDetached(["sh", "-c",
                                     "exec \"$HOME/.local/bin/island-tabs-ctl\" activate \"$1\" \"$2\" \"$3\"", "sh",
                                     d.tab_id, d.window_id, d.title || ""])
            return
        }
        if (action === "here" && HeliumService.connected)
            HeliumService.navigate(d.url)
        else
            Quickshell.execDetached(["sh", "-c", "exec \"$HOME/.local/bin/helium-browser\" \"$1\"", "sh", d.url])
        focusBrowser()
    }
    // The most recently focused Helium window, which is where a new tab opens.
    function focusBrowser() {
        const wins = NiriService.windowData.filter(w => w.app_id.toLowerCase().startsWith("helium"))
        if (!wins.length)
            return
        wins.sort((a, b) => b.ts - a.ts)
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(wins[0].id)])
    }
    Component.onCompleted: HyprbeamService.warm()
}
