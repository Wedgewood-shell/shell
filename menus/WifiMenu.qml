import QtQuick
import Quickshell
import ".."

MenuPage {
    id: page
    readonly property int cardH: 74
    readonly property int rowH: 46
    glyph: "\uf1eb"
    title: wifiPassword ? "Password for " + (WifiService.wifiTarget ? WifiService.wifiTarget.ssid : "") : WifiService.wifiStage
                          === "connecting" ? "Connecting…" : "Search networks…"
    inputReadOnly: WifiService.wifiStage === "connecting"
    password: wifiPassword
    maxRows: 6
    listY: 50 + cardH + 10
    showResults: wifiList
    contentHeight: wifiList ? listY + Math.min(results.length, 6) * rowH + (results.length ? 12 : 4) : listY + 40
    readonly property var wifiInfo: WifiService.wifiData.wifi || ({
                                                                      radio: "enabled",
                                                                      connected: false
                                                                  })
    readonly property bool radioOn: wifiInfo.radio !== "disabled"
    readonly property var cardBtns: {
        const b = []
        if (radioOn)
            b.push("refresh")
        if (radioOn && wifiInfo.connected)
            b.push("disconnect")
        b.push("radio")
        return b
    }
    readonly property real btnsW: cardBtns.length * page.cardH + Math.max(0, cardBtns.length - 1) * 4
    property int cardFocus: -1          // -1 = network list, otherwise index into cardBtns

    function cardAction(id) {
        if (id === "refresh")
            WifiService.wifiRefreshNow()
        else if (id === "disconnect")
            WifiService.wifiDisconnect()
        else
            WifiService.wifiRadio(!page.radioOn)
    }

    readonly property bool wifiList: WifiService.wifiStage === "list"
    readonly property bool wifiPassword: WifiService.wifiStage === "password"

    Connections {
        target: WifiService
        function onWifiDataChanged() {
            if (page.wifiList)
                page.refresh()
        }
        function onWifiStageChanged() {
            page.clearQuery()
            page.cardFocus = -1
            page.refresh()
        }
    }
    function wifiIconFor(n) {
        return n.hotspot ? NetworkService.netGlyph("hotspot", 0) : NetworkService.netGlyph("wifi", n.signal)
    }
    function filter(q) {
        q = q.trim().toLowerCase()
        let nets = page.radioOn ? (WifiService.wifiData.networks || []) : []
        nets = nets.filter(n => !n.inuse)
        // the connected network is shown in the card above
        if (q)
            nets = nets.filter(n => n.ssid.toLowerCase().includes(q))
        return nets.map(n => ({
            name: n.ssid,
            glyph: page.wifiIconFor(n),
            tint: n.inuse ? Theme.success : Theme.highlight,
            sub: (n.inuse ? "Connected" : n.saved ? "Saved" : "") + (n.secure ? (n.inuse || n.saved ? "  " : "")
                                                                                + Theme.cp(0xF033E) : ""),
            badge: n.badge || "",
            net: n
        }))
    }
        function initialIndex() {
        return Math.max(0, Math.min(currentIndex, results.length - 1))
    }
        function activate(item) {
        if (!item)
        return
        if (WifiService.wifiStage === "password") {
        if (page.query.length === 0)
        return
        const pw = page.query
        page.clearQuery()
        WifiService.wifiConnect(WifiService.wifiTarget, pw)
        return
    }
        if (WifiService.wifiStage !== "list" || !item.net || item.net.inuse)
        return
        WifiService.wifiError = ""
        if (item.net.secure && !item.net.saved) {
        WifiService.wifiTarget = item.net
        WifiService.wifiStage = "password"
        page.clearQuery()
    } else {
        WifiService.wifiConnect(item.net, "")
    }
        return
    }

        function handleKey(key) {
        if ((key === Qt.Key_Escape || (key === Qt.Key_Backspace && query.length === 0)) && wifiPassword) {
        WifiService.wifiStage = "list"
        WifiService.wifiError = ""
        return true
    }
        if (wifiPassword && (key === Qt.Key_Up || key === Qt.Key_Down))
        return true
        if (!wifiList)
        return false
        if (cardFocus < 0 && (key === Qt.Key_Right || (key === Qt.Key_Up && currentIndex === 0))) {
        cardFocus = 0
        return true
    }
        if (cardFocus >= 0) {
        if (key === Qt.Key_Right) {
        cardFocus = Math.min(cardFocus + 1, cardBtns.length - 1)
        return true
    }
        if (key === Qt.Key_Left) {
        cardFocus = cardFocus === 0 ? -1 : cardFocus - 1
        return true
    }
        if (key === Qt.Key_Down || key === Qt.Key_Up) {
        if (key === Qt.Key_Down)
        cardFocus = -1
        return true
    }
        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
        cardAction(cardBtns[cardFocus])
        return true
    }
    }
        return false
    }
        function submit() {
        activate(wifiPassword ? {
        net: WifiService.wifiTarget
    } : results[currentIndex])
    }
        // ---- wifi: current network card + status line ----
        Rectangle {
        id: wifiCard
        visible: true
        x: 14
        y: 50
        width: parent.width - 28 - (page.wifiList ? page.btnsW + 6 : 0)
        height: page.cardH
        radius: 14
        color: Theme.raised
        readonly property var cur: WifiService.wifiData.current || ({
        kind: "none"
    })
        readonly property bool connecting: WifiService.wifiStage === "connecting"
        readonly property string kind: cur.hotspot && cur.kind !== "none" ? "hotspot" : cur.kind
        readonly property string detail: {
        if (!page.radioOn)
        return "Turn Wi-Fi on to see networks"
        if (connecting)
        return "Connecting to " + (WifiService.wifiTarget ? WifiService.wifiTarget.ssid : "") + "…"
        if (WifiService.wifiResult === "ok")
        return "Connected"
        if (cur.kind === "none")
        return "Not connected"
        const bits = []
        bits.push(cur.hotspot ? "Mobile hotspot" : cur.kind === "eth" ? "Wired" : "Connected")
        if (cur.kind === "wifi" && cur.signal !== undefined)
        bits.push(cur.signal + "%")
        if (cur.band)
        bits.push(cur.band)
        if (cur.kind === "eth" && cur.rate)
        bits.push(cur.rate)
        if (cur.ip)
        bits.push(cur.ip)
        return bits.join("  ·  ")
    }
        Text {
        id: cardIcon
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignHCenter
        text: NetworkService.netGlyph(!page.radioOn || wifiCard.kind === "none" ? "none" : wifiCard.kind,
        wifiCard.cur.signal || 0)
        color: !page.radioOn || wifiCard.kind === "none" ? Theme.danger : Theme.highlight
        font.family: Theme.fontFamily
        font.pixelSize: 30
        SequentialAnimation on opacity {
        running: wifiCard.connecting
        loops: Animation.Infinite
        NumberAnimation {
        to: 0.35
        duration: 500
    }
        NumberAnimation {
        to: 1
        duration: 500
    }
    }
        opacity: wifiCard.connecting ? opacity : 1
    }
        Column {
        anchors.left: cardIcon.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Text {
        width: parent.width
        elide: Text.ElideRight
        text: !page.radioOn ? "Wi-Fi is off" : wifiCard.cur.kind === "none" ? "No network" : (wifiCard.cur.name
        || "Network")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }
        Text {
        width: parent.width
        elide: Text.ElideRight
        text: wifiCard.detail
        color: wifiCard.connecting ? Theme.warning : WifiService.wifiResult === "ok" ? Theme.success : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
    }
    }
        Row {
        id: cardButtons
        visible: page.wifiList
        x: parent.width - 14 - page.btnsW
        y: 50
        spacing: 4
        Repeater {
        model: page.cardBtns
        delegate: ActionTile {
        required property string modelData
        required property int index
        glyph: modelData === "refresh" ? "\uf021" : modelData === "disconnect" ? "\uf127" : "\uf011"
        label: modelData === "refresh" ? "Refresh" : modelData === "disconnect" ? "Unlink" : (page.radioOn ? "Disable" :
        "Enable")
        tint: modelData === "refresh" ? Theme.highlight : modelData === "disconnect" ? Theme.warning : (page.radioOn
        ? Theme.danger : Theme.success)
        spinning: modelData === "refresh" && WifiService.wifiScanning
        focused: page.cardFocus === index
        onClicked: page.cardAction(modelData)
    }
    }
    }
        Text {
        id: wifiMsg
        visible: !page.wifiList
        x: 18
        y: 50 + page.cardH + 10
        width: parent.width - 36
        height: 34
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: WifiService.wifiError ? WifiService.wifiError + " — try again" : page.wifiPassword ? "Password for " + (
        WifiService.wifiTarget ? WifiService.wifiTarget.ssid : "") + "  ·  Enter to connect  ·  Backspace to go back" :
        ""
        color: WifiService.wifiError ? Theme.danger : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
        Text {
        visible: page.wifiList && WifiService.wifiError !== ""
        x: 18
        y: 50 + page.cardH + 4
        width: parent.width - 36
        elide: Text.ElideRight
        text: WifiService.wifiError
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
    }
