// youtube music's home page: shelves of cards and songs

import QtQuick
import "Routes.js" as Routes

Flickable {
    id: page

    required property var hub

    readonly property var content: hub.contentPage
    readonly property var shelves: content !== null ? content.shelves : []

    contentHeight: column.height + hub.looks.cards.page_padding
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        width: page.width
        topPadding: page.hub.looks.cards.page_padding / 2

        Repeater {
            model: page.shelves

            CardShelf {
                id: shelf
                required property var modelData

                width: column.width
                looks: page.hub.looks.cards
                fonts: page.hub.fonts
                themeDirectory: page.hub.themeDirectory
                title: modelData.title
                items: modelData.items

                // a song plays with the rest of the shelf queued after it
                onItemOpened: index => {
                    const item = items[index]
                    if (item.type === "track") {
                        page.hub.playItemsRequested(items, index)
                    } else {
                        page.hub.openRequested(Routes.make(item.kind, item.browseId))
                    }
                }
                onItemPlayRequested: index => {
                    const item = items[index]
                    if (item.type === "track") {
                        page.hub.playItemsRequested(items, index)
                    } else {
                        page.hub.playCardRequested(item.kind, item.browseId)
                    }
                }
                onItemMenuRequested: (index, x, y) => {
                    const item = items[index]
                    const place = shelf.mapToItem(page.hub, x, y)
                    if (item.type === "track") {
                        page.hub.songMenuRequested(item, -1, place.x, place.y)
                    } else {
                        page.hub.cardMenuRequested(item, place.x, place.y)
                    }
                }
            }
        }
    }

    EmptyMessage {
        x: (page.width - width) / 2
        y: page.height / 2 - height / 2
        width: page.width * 0.7
        visible: page.shelves.length === 0
        looks: page.hub.looks.song_list
        fonts: page.hub.fonts
        busy: page.content !== null && page.content.loading
        busyText: page.hub.strings.loading
        problem: page.content !== null ? page.content.problem : ""
        emptyText: page.hub.strings.empty_remote
    }
}
