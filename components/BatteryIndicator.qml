import QtQuick
import ".."

// Scale the drawing and its layout footprint together.
Item {
    id: indicator
    property real iconScale: 0.7225
    property int percentage: BatteryService.battery
    property bool plugged: BatteryService.plugged
    property bool charging: BatteryService.charging
    readonly property int level: Math.max(0, Math.min(100, percentage))
    readonly property bool powerSymbol: plugged || charging
    readonly property color ink: powerSymbol ? Theme.foreground : level <= 15 ? Theme.danger : level <= 30 ? Theme.warning : Theme.foreground
    implicitWidth: 44 * iconScale
    implicitHeight: 28 * iconScale

    Item {
        width: 44
        height: 28
        scale: indicator.iconScale
        transformOrigin: Item.TopLeft
        Rectangle {
            x: 40
            y: 9.5
            width: 3
            height: 9
            radius: 1.5
            color: indicator.ink
        }
        Rectangle {
            id: body
            x: 0
            y: 3
            width: 38
            height: 22
            radius: 5
            color: "transparent"
            border.width: 1.5
            border.color: indicator.ink
        }
        Rectangle {
            id: fill
            x: 2
            y: 5
            width: 34 * indicator.level / 100
            height: 18
            radius: 3
            color: indicator.ink
        }
        Text {
            id: value
            anchors.centerIn: body
            visible: !indicator.powerSymbol
            text: indicator.level
            color: indicator.ink
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
        }
        // Invert the percentage only over the filled part of the battery.
        Item {
            x: fill.x
            y: fill.y
            width: fill.width
            height: fill.height
            clip: true
            visible: !indicator.powerSymbol
            Text {
                x: (body.width - implicitWidth) / 2 - fill.x
                y: (body.height - implicitHeight) / 2 + body.y - fill.y
                text: value.text
                color: Theme.surface
                font: value.font
            }
        }
        Canvas {
            id: symbol
            x: 8
            y: 0
            width: 22
            height: 28
            visible: indicator.powerSymbol
            antialiasing: true
            property bool bolt: indicator.charging
            property color ink: indicator.ink
            onBoltChanged: requestPaint()
            onInkChanged: requestPaint()
            onVisibleChanged: if (visible)
                requestPaint()
            onAvailableChanged: if (available)
                requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.lineWidth = 4
                ctx.strokeStyle = Theme.surface
                ctx.fillStyle = ink
                ctx.beginPath()
                if (bolt) {
                    ctx.moveTo(14, 1)
                    ctx.lineTo(3, 16)
                    ctx.lineTo(10, 16)
                    ctx.lineTo(8, 27)
                    ctx.lineTo(20, 11)
                    ctx.lineTo(12, 11)
                    ctx.closePath()
                } else {
                    ctx.moveTo(4, 1)
                    ctx.lineTo(8, 1)
                    ctx.lineTo(8, 9)
                    ctx.lineTo(13, 9)
                    ctx.lineTo(13, 1)
                    ctx.lineTo(17, 1)
                    ctx.lineTo(17, 9)
                    ctx.lineTo(20, 9)
                    ctx.lineTo(20, 14)
                    ctx.bezierCurveTo(20, 19, 16, 22, 13, 23)
                    ctx.lineTo(13, 28)
                    ctx.lineTo(8, 28)
                    ctx.lineTo(8, 23)
                    ctx.bezierCurveTo(5, 22, 1, 19, 1, 14)
                    ctx.lineTo(1, 9)
                    ctx.lineTo(4, 9)
                    ctx.closePath()
                }
                ctx.stroke()
                ctx.fill()
            }
        }
    }
}
