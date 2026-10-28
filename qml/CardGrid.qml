// a grid of album/artist/playlist covers, with a message when empty

import QtQuick
import "shell" as Shell

Item {
    id: grid

    required property var looks
    // looks.song_list, for the empty message colours
    required property var messageLooks
    required property var fonts
    required property string themeDirectory
    // a CardModel
    required property var model

    property bool busy: false
    property string busyText: ""
    property string problem: ""
    property string emptyText: ""

    signal opened(var card)
    signal playRequested(var card)
    signal menuRequested(var card, real x, real y)

    GridView {
        id: view
        anchors.fill: parent
        anchors.leftMargin: grid.looks.page_padding
        anchors.rightMargin: grid.looks.page_padding
        topMargin: grid.looks.page_padding
        bottomMargin: grid.looks.page_padding
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: grid.model
        cellWidth: grid.looks.cover_size + grid.looks.spacing_x
        cellHeight: grid.looks.cover_size + grid.looks.text_gap + grid.looks.text_height + grid.looks.spacing_y

        delegate: Item {
            id: cell

            required property int index
            required property string kind
            required property string browseId
            required property string title
            required property string subtitle
            required property string thumbnailUrl

            width: view.cellWidth
            height: view.cellHeight

            Tile {
                looks: grid.looks
                fonts: grid.fonts
                themeDirectory: grid.themeDirectory
                title: cell.title
                subtitle: cell.subtitle
                thumbnailUrl: cell.thumbnailUrl
                round: cell.kind === "artist"
                onOpened: grid.opened(grid.model.cardAt(cell.index))
                onPlayRequested: grid.playRequested(grid.model.cardAt(cell.index))
                onMenuRequested: (x, y) => {
                    const place = mapToItem(grid, x, y)
                    grid.menuRequested(grid.model.cardAt(cell.index), place.x, place.y)
                }
            }
        }
    }

    EmptyMessage {
        anchors.centerIn: parent
        width: parent.width * 0.7
        visible: view.count === 0
        looks: grid.messageLooks
        fonts: grid.fonts
        busy: grid.busy
        busyText: grid.busyText
        problem: grid.problem
        emptyText: grid.emptyText
    }
}
