// the start page: what was played lately, over youtube music's home page of
// shelves of cards and songs. the local shelf shows at once, even offline.
// hidden songs (Library.isHidden) are left off every shelf.

import QtQuick
import "Routes.js" as Routes

Flickable {
    id: page

    required property var hub

    readonly property var content: hub.contentPage
    readonly property var remoteShelves: content !== null ? content.shelves : []

    // how many of the latest played songs the first shelf shows
    readonly property int recentLimit: 20
    // the history newest first, as track maps marked the way shelves want them;
    // fromHistory gets them a "remove from history" in their menu
    property var recentItems: []

    function updateRecentItems() {
        const history = hub.library.history
        const items = []
        for (let row = 0; row < Math.min(history.count, recentLimit); row++) {
            items.push(Object.assign({ type: "track", fromHistory: true }, history.trackAt(row)))
        }
        recentItems = items
    }

    Component.onCompleted: updateRecentItems()

    Connections {
        target: page.hub.library.history
        // a play changes the history up to three times (remove, insert, trim);
        // callLater rebuilds the shelf once, after the last of them
        function onChanged() {
            Qt.callLater(page.updateRecentItems)
        }
    }

    contentHeight: column.height + hub.looks.cards.page_padding
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component Shelf: CardShelf {
        id: shelf

        width: column.width
        looks: page.hub.looks.cards
        fonts: page.hub.fonts
        themeDirectory: page.hub.themeDirectory

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

    Column {
        id: column
        width: page.width
        topPadding: page.hub.looks.cards.page_padding / 2

        Shelf {
            visible: page.recentItems.length > 0
            title: page.hub.strings.shelf_recent
            items: page.recentItems
        }

        // apart from the recent shelf, so a play doesn't rebuild youtube's shelves
        // and scroll them all back to the start
        Repeater {
            model: page.remoteShelves

            Shelf {
                required property var modelData

                // filtered per shelf, so hiding a song doesn't rebuild the repeater
                // and scroll every shelf back to the start
                readonly property var shownItems: {
                    // hiddenVersion is a revision counter for withoutHidden()
                    page.hub.library.hiddenVersion
                    return page.hub.library.withoutHidden(modelData.items)
                }

                visible: shownItems.length > 0
                title: modelData.title
                items: shownItems
            }
        }
    }

    // under the recent shelf while youtube's shelves load, in the middle when there's nothing
    EmptyMessage {
        readonly property bool hasRecent: page.recentItems.length > 0

        x: (page.width - width) / 2
        y: hasRecent ? column.height + page.hub.looks.cards.page_padding : page.height / 2 - height / 2
        width: page.width * 0.7
        visible: page.remoteShelves.length === 0 && (!hasRecent || text !== "")
        looks: page.hub.looks.song_list
        fonts: page.hub.fonts
        busy: page.content !== null && page.content.loading
        busyText: page.hub.strings.loading
        problem: page.content !== null ? page.content.problem : ""
        emptyText: page.hub.strings.empty_remote
    }
}
