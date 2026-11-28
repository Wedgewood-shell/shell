import QtQuick
import Quickshell
import ".."

ShellRoot {
    AudioMenu { id: page }
    property int assertions: 0
    function check(condition, message) {
        if (!condition)
            throw new Error("FAIL: " + message)
        assertions++
    }
    function audioChecks() {
        AudioMenuService.data = {
            info: { default_sink_name: "speakers", default_source_name: "mic" },
            sinks: [{ index: 1, name: "speakers", description: "Speakers" },
                    { index: 5, name: "hdmi", description: "HDMI 1", ports: [{ type: "HDMI", availability: "not available" }] }],
            sources: [{ index: 2, name: "mic", description: "Microphone" },
                      { index: 1, name: "speakers.monitor", monitor_source: "speakers" }],
            sink_inputs: [{ index: 3, sink: 1, properties: { "node.passive": "true" } },
                          { index: 6, sink: 1, properties: { "application.name": "Player" } }],
            source_outputs: [{ index: 4, source: 2, mute: true, properties: { "application.name": "Recorder" } }]
        }
        check(page.results.length === 4 && page.results[0].sub === "Speakers" && page.results[1].sub === "Microphone"
              && page.results[2].sub === "1", "audio defaults and stream counts update from the service")
        page.activate(page.results[0])
        check(page.results.some(r => r.key === "device:hdmi") === !Settings.hideDisconnectedHdmi
              && page.results.some(r => r.key === "device:speakers"), "HDMI filter in default output picker")
        page.handleKey(Qt.Key_Escape)
        page.activate(page.results[2])
        page.activate(page.results[1])
        check(page.results.some(r => r.key === "device:hdmi") === !Settings.hideDisconnectedHdmi,
              "HDMI filter in playback route picker")
        const [speakers, hdmi] = AudioMenuService.data.sinks
        AudioMenuService.data = Object.assign({}, AudioMenuService.data, {
            sinks: [speakers, Object.assign({}, hdmi, { ports: [{ type: "HDMI", availability: "available" }] })]
        })
        check(page.results.some(r => r.key === "device:hdmi"), "connected HDMI appears while the picker is open")
        page.handleKey(Qt.Key_Escape)
        page.handleKey(Qt.Key_Escape)
        page.activate(page.results[1])
        check(page.results.length === 2 && page.results[1].badge === "Default", "audio input picker marks default and hides monitors")
        check(page.handleKey(Qt.Key_Escape), "audio back to overview")
        page.activate(page.results[3])
        check(page.results[1].name === "Recorder", "audio recording stream is listed")
        page.activate(page.results[1])
        check(page.results[1].name === "Unmute stream" && page.filter("mic").length === 3
              && page.results[2].badge === "Current", "audio stream mute action and current route")
        AudioMenuService.data = Object.assign({}, AudioMenuService.data, { source_outputs: [] })
        check(page.results.length === 1 && page.handleKey(Qt.Key_Escape), "audio stream disappearing leaves a safe back action")
    }
    Component.onCompleted: Qt.callLater(() => {
        try {
            audioChecks()
            console.log("AUDIO PASS: " + assertions + " assertions")
        } finally {
            Qt.quit()
        }
    })
}
