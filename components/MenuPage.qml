import QtQuick
import Quickshell
import ".."

Item {
    id: page
    property string query: ""
    property string title: ""
    property string glyph: ""
    property bool tiles: false
    property bool inputReadOnly: tiles
    property bool password: false
    // Text the input starts with (selected) when the page opens.
    property string initialText: ""
    property bool showHeader: true
    // Rule under the input row.
    property bool showDivider: true
    property bool showResults: true
    property int maxRows: 7
    property real listY: 50
    property real tileY: 54
    property var results: []
    // Optional surface shown below the menu pill (not clipped by it), e.g. a preview.
    // `detailHeight` reserves room for it in the layer surface.
    property Component detail: null
    property real detailHeight: 0
    property alias currentIndex: list.currentIndex
    readonly property real tilesWidth: results.length * 104 + Math.max(0, results.length - 1) * 12
    property real contentWidth: tiles ? Math.max(340, tilesWidth + 44) : 620
    property real contentHeight: tiles ? 172 : 56 + Math.min(results.length, maxRows) * 46 + (results.length ? 6 : 0)
    signal clearQuery
    function filter(q) {
        return []
    }
    function initialIndex() {
        return 0
    }
    function refresh() {
        results = filter(query)
        currentIndex = initialIndex()
    }
    function activate(item) {
    }
    function handleKey(key) {
        return false
    }
    function submit() {
        activate(results[currentIndex])
    }
    function navigate(delta) {
        if (delta > 0)
            list.incrementCurrentIndex()
        else
            list.decrementCurrentIndex()
    }
    onQueryChanged: refresh()
    Component.onCompleted: refresh()
    ResultList {
        id: list
        x: page.tiles ? (parent.width - page.tilesWidth) / 2 : 8
        y: page.tiles ? page.tileY : page.listY
        width: page.tiles ? page.tilesWidth : parent.width - 16
        height: page.tiles ? 104 : Math.min(page.results.length, page.maxRows) * 46
        visible: page.showResults
        results: page.results
        tileMode: page.tiles
        onActivated: item => page.activate(item)
    }
}
