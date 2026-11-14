import QtQuick
import Quickshell
import ".."

// Edits the focused Helium window's address bar, with its suggestions.
MenuPage {
    id: page
    title: "Search or enter address"
    glyph: Theme.cp(0xF059F)
    showDivider: results.length > 0
    // Same footprint as the closed island until there are suggestions to show.
    contentWidth: Theme.islandHeliumWidth
    contentHeight: results.length ? 56 + Math.min(results.length, maxRows) * 46 + 6 : Theme.barHeight
    initialText: HeliumService.url
    property string lastQuery: "\u0000"
    readonly property var glyphs: ({
            "search-what-you-typed": Theme.cp(0xF0349),
            "search-suggest": Theme.cp(0xF0349),
            "search-history": Theme.cp(0xF0150),
            "history-url": Theme.cp(0xF0150),
            "history-title": Theme.cp(0xF0150),
            "bookmark-title": Theme.cp(0xF04CE),
            "url-what-you-typed": Theme.cp(0xF059F)
        })
    function filter(q) {
        if (q.trim() === "" || q === initialText)
            return []
        return HeliumService.suggestions.map(s => ({
                    name: s.contents || s.url,
                    sub: s.description || "",
                    glyph: page.glyphs[s.type] || Theme.cp(0xF059F),
                    fill: s.fill || s.url || s.contents
                }))
    }
    function refresh() {
        const fresh = query !== lastQuery
        if (fresh) {
            lastQuery = query
            HeliumService.complete(query === initialText ? "" : query)
        }
        const keep = currentIndex
        results = filter(query)
        currentIndex = fresh ? 0 : Math.max(0, Math.min(keep, results.length - 1))
    }
    Connections {
        target: HeliumService
        function onSuggestionsChanged() {
            page.refresh()
        }
    }
    function activate(item) {
        OverlayController.launcherOpen = false
        HeliumService.navigate(item.fill)
    }
    function submit() {
        const item = results[currentIndex]
        if (item)
            return activate(item)
        if (query.trim() !== "") {
            OverlayController.launcherOpen = false
            HeliumService.navigate(query)
        }
    }
}
