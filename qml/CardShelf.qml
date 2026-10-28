// a titled, sideways-scrolling row of tiles (home shelves, an artist's albums).
// the arrow buttons are for mice without horizontal scrolling.

import QtQuick
import QtQuick.Shapes
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: shelf

    required property var looks
    required property var fonts
    required property string themeDirectory

    property string title: ""
    // either set `cards` (a CardModel) or `items` directly.
    property var cards: null
    // card maps, or track maps marked with type: "track"
    property var items: {
        cardsRevision
        if (cards === null) {
            return []
        }
        const list = []
        for (let row = 0; row < cards.count; row++) {
            list.push(cards.cardAt(row))
        }
        return list
    }
    // revision counter: cardAt() is a call, so `items` reads this to rebuild on changes
    property int cardsRevision: 0

    Connections {
        target: shelf.cards
        function onChanged() {
            shelf.cardsRevision++
        }
    }

    signal itemOpened(int index)
    signal itemPlayRequested(int index)
    signal itemMenuRequested(int index, real x, real y)

    readonly property real titleHeight: looks.shelf_title_height
    readonly property real tileHeight: looks.cover_size + looks.text_gap + looks.text_height

    implicitHeight: titleHeight + tileHeight + looks.shelf_bottom_gap
    height: implicitHeight

    // scrolls by about a page
    function scrollBy(direction) {
        const step = Math.max(view.cellStep, view.width - view.cellStep)
        const farthest = Math.max(0, view.contentWidth - view.width + view.rightMargin)
        slide.to = Math.max(-view.leftMargin, Math.min(farthest, view.contentX + direction * step))
        slide.restart()
    }

    NumberAnimation {
        id: slide
        target: view
        property: "contentX"
        duration: 220
        easing.type: Easing.OutCubic
    }

    Text {
        x: shelf.looks.page_padding
        height: shelf.titleHeight
        verticalAlignment: Text.AlignVCenter
        text: shelf.title
        color: ThemeValues.color(shelf.looks.shelf_title_color)
        font.family: shelf.fonts.music_title.family
        font.pixelSize: shelf.fonts.music_title.size + 3
        font.bold: shelf.fonts.music_title.bold ?? false
    }

    component Arrow: Item {
        id: arrow
        property int direction: 1
        signal pressed()
        width: 22
        height: shelf.titleHeight

        Shape {
            anchors.centerIn: parent
            width: 8
            height: 12
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: ThemeValues.color(area.containsMouse ? shelf.looks.arrow_hover_color : shelf.looks.arrow_color)
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: arrow.direction > 0 ? 1.5 : 6.5
                startY: 1
                PathLine { x: arrow.direction > 0 ? 6.5 : 1.5; y: 6 }
                PathLine { x: arrow.direction > 0 ? 1.5 : 6.5; y: 11 }
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: arrow.pressed()
        }
    }
    Row {
        x: shelf.width - width - shelf.looks.page_padding
        Arrow { direction: -1; onPressed: shelf.scrollBy(-1) }
        Arrow { direction: 1; onPressed: shelf.scrollBy(1) }
    }

    ListView {
        id: view
        y: shelf.titleHeight
        width: parent.width
        height: shelf.tileHeight
        orientation: ListView.Horizontal
        leftMargin: shelf.looks.page_padding
        rightMargin: shelf.looks.page_padding
        spacing: shelf.looks.spacing_x
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: shelf.items

        readonly property real cellStep: shelf.looks.cover_size + shelf.looks.spacing_x

        delegate: Tile {
            id: item
            required property int index
            required property var modelData

            readonly property bool isSong: modelData.type === "track"

            looks: shelf.looks
            fonts: shelf.fonts
            themeDirectory: shelf.themeDirectory
            title: modelData.title ?? ""
            subtitle: isSong ? (modelData.artist ?? "") : (modelData.subtitle ?? "")
            thumbnailUrl: modelData.thumbnailUrl ?? ""
            round: modelData.kind === "artist"
            onOpened: shelf.itemOpened(index)
            onPlayRequested: shelf.itemPlayRequested(index)
            onMenuRequested: (x, y) => {
                const place = mapToItem(shelf, x, y)
                shelf.itemMenuRequested(index, place.x, place.y)
            }
        }
    }
}
