import QtQuick
import ".."

MenuPage {
    id: page
    property var data: AudioMenuService.data
    property string section: ""
    property string streamKey: ""
    readonly property bool recording: section === "input" || section === "recording"
    readonly property bool streamList: section === "playback" || section === "recording"
    readonly property var streams: streamList ? streamRows(recording) : []
    readonly property var stream: streams.find(item => item.key === streamKey)
    readonly property string speakerGlyph: Theme.cp(0xF057E)
    readonly property string micGlyph: Theme.cp(0xF036C)
    glyph: recording ? micGlyph : speakerGlyph
    title: stream ? stream.name + " — search devices…"
                  : section === "input" ? "Default input — search microphones…"
                  : section === "output" ? "Default output — search devices…"
                  : section === "recording" ? "Recording — search apps…"
                  : section === "playback" ? "Playback — search apps…" : "Audio"
    inputReadOnly: section === ""
    contentHeight: listY + Math.min(results.length, maxRows) * 46 + 38

    function devices(input) {
        return data ? (input ? data.sources : data.sinks) || [] : []
    }
    function defaultDevice(input) {
        const name = data?.info?.[input ? "default_source_name" : "default_sink_name"]
        return devices(input).find(d => d.name === name)
    }
    function label(device) {
        return device ? device.description || device.name : "No device"
    }
    function streamRows(input) {
        const entries = data ? (input ? data.source_outputs : data.sink_inputs) || [] : []
        const endpoints = devices(input)
        return entries.filter(s => s.properties?.["node.passive"] !== "true").map(s => {
            const props = s.properties || ({})
            const name = props["application.name"] || props["node.nick"] || props["media.name"] || props["node.name"] || "Audio stream"
            const device = endpoints.find(d => d.index === (input ? s.source : s.sink))
            const media = props["media.name"] || ""
            return {
                key: "stream:" + (props["object.serial"] || s.index), kind: "stream", entry: s, name, media,
                glyph: input ? micGlyph : speakerGlyph,
                sub: (s.mute ? "Muted · " : "") + label(device), subElideRight: true, subMax: 240
            }
        })
    }
    function filter(q) {
        if (!section) {
            return [
                { key: "output", kind: "section", name: "Default output", glyph: speakerGlyph, sub: label(defaultDevice(false)) },
                { key: "input", kind: "section", name: "Default input", glyph: micGlyph, sub: label(defaultDevice(true)) },
                { key: "playback", kind: "section", name: "Playback streams", glyph: Theme.cp(0xF040A), sub: data ? String(streamRows(false).length) : "" },
                { key: "recording", kind: "section", name: "Recording streams", glyph: Theme.cp(0xF044A), sub: data ? String(streamRows(true).length) : "" }
            ]
        }
        const rows = [{ key: "back", kind: "back", name: "Back", glyph: Theme.cp(0xF004D), sub: "Esc" }]
        const needle = q.trim().toLowerCase()
        const entries = streamList ? streamRows(recording) : []
        if (streamList && !streamKey)
            return rows.concat(entries.filter(item => (item.name + " " + item.media).toLowerCase().includes(needle)))
        const stream = entries.find(item => item.key === streamKey)
        if (streamKey && !stream)
            return rows
        if (stream) {
            rows.push({ key: "mute", kind: "mute", name: stream.entry.mute ? "Unmute stream" : "Mute stream",
                          glyph: Theme.cp(0xF075F), sub: stream.media === stream.name ? "" : stream.media })
        }
        const current = defaultDevice(recording)
        const target = stream?.entry?.[recording ? "source" : "sink"]
        for (const device of devices(recording)) {
            // Monitor sources are useful for recording an app's audio, but aren't microphones.
            if (recording && !stream && device.monitor_source && device.name !== current?.name)
                continue
            const name = label(device)
            if (needle && !name.toLowerCase().includes(needle))
                continue
            const selected = stream ? device.index === target : device.name === current?.name
            rows.push({ key: "device:" + device.name, kind: "device", device, name, glyph: page.glyph,
                          badge: selected ? (stream ? "Current" : "Default") : "",
                          sub: stream ? (selected ? "" : "Route here") : (selected ? "" : "Set default") })
        }
        return rows
    }
    function initialIndex() {
        const selected = results.findIndex(item => !!item.badge)
        return selected >= 0 ? selected : (section && results.length > 1 ? 1 : 0)
    }
    function updateRows() {
        const key = results[currentIndex]?.key
        const updated = filter(query)
        if (JSON.stringify(updated) === JSON.stringify(results))
            return
        results = updated
        const index = results.findIndex(item => item.key === key)
        currentIndex = index >= 0 ? index : initialIndex()
    }
    onDataChanged: updateRows()

    function changeView(next, key) {
        section = next
        streamKey = key || ""
        clearQuery()
        refresh()
    }
    function back() {
        if (streamKey)
            changeView(section)
        else if (section)
            changeView("")
        else
            return false
        return true
    }
    function handleKey(key) {
        return key === Qt.Key_Escape && back()
    }
    function activate(item) {
        if (!item)
            return
        if (item.kind === "section")
            changeView(item.key)
        else if (item.kind === "back")
            back()
        else if (item.kind === "stream")
            changeView(section, item.key)
        else if (item.kind === "mute" && stream)
            AudioMenuService.run([recording ? "set-source-output-mute" : "set-sink-input-mute", String(stream.entry.index), stream.entry.mute ? "0" : "1"])
        else if (item.kind === "device" && stream)
            AudioMenuService.run([recording ? "move-source-output" : "move-sink-input", String(stream.entry.index), item.device.name])
        else if (item.kind === "device" && !streamKey)
            AudioMenuService.run([recording ? "set-default-source" : "set-default-sink", item.device.name])
    }
    Connections {
        target: OverlayController
        function onLauncherOpenChanged() {
            if (OverlayController.launcherOpen && OverlayController.launcherMode === "audio")
                page.changeView("")
        }
    }
    Text {
        x: 18
        y: page.contentHeight - 32
        width: page.width - 36
        height: 24
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: AudioMenuService.readError || AudioMenuService.actionError
              || (!page.data ? "Loading audio devices…"
                  : page.stream ? "Select a device to change this app’s route. WirePlumber remembers it."
                  : page.streamKey ? "This stream has closed."
                  : page.streamList && !page.streams.length ? "No active " + page.section + " streams."
                  : page.section && page.results.length === 1 ? (page.query ? "No matches." : "No devices available.")
                  : "↑ ↓ Navigate    ·    Enter Select    ·    Esc " + (page.section ? "Back" : "Close"))
        color: AudioMenuService.readError || AudioMenuService.actionError ? Theme.danger : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
