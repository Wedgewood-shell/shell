import QtQuick
import Quickshell
import ".."
import Quickshell.Widgets

ListView {
    id: list
    property var results: []
    property bool tileMode: false
    property int tile: 104
    property int tileGap: 12
    property int rowH: 46
    signal activated(var item)
    orientation: list.tileMode ? ListView.Horizontal : ListView.Vertical
    spacing: list.tileMode ? list.tileGap : 0
    model: list.results
    clip: true
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 120
    highlightMoveVelocity: -1
    highlight: Rectangle {
        radius: list.tileMode ? 18 : 10
        color: Theme.raisedHover
    }
    delegate: Item {
        id: row
        required property var modelData
        required property int index
        width: list.tileMode ? list.tile : list.width
        height: list.tileMode ? list.tile : list.rowH
        IconImage {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 28
            visible: !list.tileMode && !row.modelData.glyph
            source: list.tileMode || row.modelData.glyph ? "" : (row.modelData.iconFile ? "file://"
                                                                                          + row.modelData.iconFile :
                                                                                          Quickshell.iconPath(
                                                                                              row.modelData.icon
                                                                                              || "application-x-executable",
                                                                                              "application-x-executable"))
        }
        Text {
            x: 12
            width: 28
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            visible: !list.tileMode && !!row.modelData.glyph
            text: row.modelData.glyph || ""
            color: row.modelData.tint || Theme.highlight
            font.family: Theme.fontFamily
            font.pixelSize: 20
        }
        Rectangle {
            id: badgeRect
            visible: !list.tileMode && !!row.modelData.badge
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + 16
            height: 22
            radius: 11
            // badge palette: [fill, border, text]
            readonly property var pal: ({
                                            "2.4 GHz": Theme.badge(Theme.warning)
                                            ,
                                            "5 GHz": Theme.badge(Theme.success)
                                            ,
                                            "6 GHz": Theme.badge(Theme.highlight)
                                            ,
                                            "WIFI 6": Theme.badge(Theme.cyan)
                                            ,
                                            "WIFI 7": Theme.badge(Theme.purple)
                                        })
            readonly property var colors: pal[row.modelData.badge] || [Theme.raised, Theme.border, Theme.muted]
            color: colors[0]
            border.width: 1
            border.color: colors[1]
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: row.modelData.badge || ""
                color: badgeRect.colors[2]
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
        Text {
            id: subText
            visible: !list.tileMode
            anchors.right: badgeRect.visible ? badgeRect.left : parent.right
            anchors.rightMargin: badgeRect.visible ? 12 : 14
            anchors.verticalCenter: parent.verticalCenter
            // Per row: `subMax` caps the width, `subElideRight` keeps a description's start.
            width: Math.min(implicitWidth, row.modelData.subMax || 320)
            horizontalAlignment: Text.AlignRight
            elide: row.modelData.subElideRight ? Text.ElideRight : Text.ElideLeft
            text: row.modelData.sub || ""
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
        // square tile layout (capture menu)
        Column {
            visible: list.tileMode
            anchors.centerIn: parent
            spacing: 10
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: row.modelData.glyph || ""
                color: row.modelData.tint || Theme.highlight
                font.family: Theme.fontFamily
                font.pixelSize: 34
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: list.tile - 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: row.modelData.label || row.modelData.name
                color: row.ListView.isCurrentItem ? Theme.text : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
        Text {
            visible: !list.tileMode
            x: 54
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 54 - subText.width - 28 - (badgeRect.visible ? badgeRect.width + 12 : 0))
            elide: Text.ElideRight
            // `markup` (optional): the name as StyledText, e.g. with matched characters coloured.
            textFormat: row.modelData.markup ? Text.StyledText : Text.PlainText
            text: row.modelData.markup || row.modelData.name
            color: row.ListView.isCurrentItem ? Theme.text : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }
        HoverFocus {
            anchors.fill: parent
            onMoved: list.currentIndex = row.index
            onClicked: list.activated(row.modelData)
        }
    }
}
