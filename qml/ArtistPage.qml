// an artist: header, top songs, then albums and singles; the whole page scrolls as one

import QtQuick
import "shell/ThemeValues.js" as ThemeValues
import "Routes.js" as Routes

Flickable {
    id: page

    required property var hub

    readonly property var content: hub.contentPage
    readonly property var strings: hub.strings
    readonly property var route: hub.route
    readonly property var cardLooks: hub.looks.cards
    readonly property int songCount: content !== null ? content.tracks.count : 0
    readonly property bool hasContent: content !== null && content.title !== ""

    readonly property bool isSaved: {
        // savedVersion is a revision counter for isSaved()
        hub.library.savedVersion
        return hub.library.isSaved(route.id)
    }

    // first line only, descriptions are often a whole paragraph
    readonly property string blurb: content !== null ? content.description.split("\n")[0] : ""

    readonly property var actions: [
        { id: "play", label: strings.action_play, primary: true, enabled: songCount > 0 },
        { id: "shuffle", label: strings.action_shuffle, enabled: songCount > 0 },
        { id: "save", label: isSaved ? strings.action_unsave_artist : strings.action_save_artist }
    ]

    function run(action) {
        if (action === "play") {
            hub.playRequested(content.tracks, 0)
        } else if (action === "shuffle") {
            hub.shuffleRequested(content.tracks)
        } else if (action === "save") {
            hub.toggleSaved({ kind: "artist", browseId: route.id, title: content.title,
                              subtitle: "", thumbnailUrl: content.thumbnailUrl })
        }
    }

    contentHeight: column.height + cardLooks.page_padding
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component CardRow: CardShelf {
        width: column.width
        looks: page.cardLooks
        fonts: page.hub.fonts
        themeDirectory: page.hub.themeDirectory
        visible: cards !== null && cards.count > 0
        height: visible ? implicitHeight : 0

        onItemOpened: index => page.hub.openRequested(Routes.make(items[index].kind, items[index].browseId))
        onItemPlayRequested: index => page.hub.playCardRequested(items[index].kind, items[index].browseId)
        onItemMenuRequested: (index, x, y) => {
            const place = mapToItem(page.hub, x, y)
            page.hub.cardMenuRequested(items[index], place.x, place.y)
        }
    }

    Column {
        id: column
        width: page.width

        PageHeader {
            id: head
            width: parent.width
            looks: page.hub.looks.page_header
            fonts: page.hub.fonts
            themeDirectory: page.hub.themeDirectory
            buttonLooks: page.hub.buttonLooks
            title: page.content !== null ? page.content.title : ""
            subtitle: page.blurb
            coverUrl: page.content !== null ? page.content.thumbnailUrl : ""
            actions: page.actions
            canGoBack: page.hub.canGoBack
            onActionTriggered: id => page.run(id)
            onBackRequested: page.hub.backRequested()
        }

        // styled like the shelf titles below
        Text {
            visible: page.songCount > 0
            leftPadding: page.cardLooks.page_padding
            height: visible ? page.cardLooks.shelf_title_height : 0
            verticalAlignment: Text.AlignVCenter
            text: page.strings.section_top_songs
            color: ThemeValues.color(page.cardLooks.shelf_title_color)
            font.family: page.hub.fonts.music_title.family
            font.pixelSize: page.hub.fonts.music_title.size + 3
            font.bold: page.hub.fonts.music_title.bold ?? false
        }

        // full height, so the page scrolls instead of the list
        HubSongList {
            hub: page.hub
            width: parent.width
            visible: page.songCount > 0
            height: visible ? page.hub.looks.song_list.header_height
                + page.songCount * page.hub.looks.song_list.row_height : 0
            model: page.content !== null ? page.content.tracks : null
        }

        CardRow {
            title: page.strings.section_albums
            cards: page.content !== null ? page.content.albums : null
        }
        CardRow {
            title: page.strings.section_singles
            cards: page.content !== null ? page.content.singles : null
        }
    }

    EmptyMessage {
        x: (page.width - width) / 2
        y: head.height + (page.height - head.height) / 2
        width: page.width * 0.7
        visible: !page.hasContent
        looks: page.hub.looks.song_list
        fonts: page.hub.fonts
        busy: page.content !== null && page.content.loading
        busyText: page.strings.loading
        problem: page.content !== null ? page.content.problem : ""
        emptyText: page.strings.empty_remote
    }
}
