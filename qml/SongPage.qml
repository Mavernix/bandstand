// one list of songs under a header. serves liked, history, the user's playlists
// ("mine") and youtube albums/playlists; the route kind picks the buttons.

import QtQuick
import "Format.js" as Format

Item {
    id: page

    required property var hub

    readonly property var route: hub.route
    readonly property string kind: route.kind
    readonly property var strings: hub.strings
    readonly property var songs: hub.songs
    readonly property var content: hub.contentPage
    readonly property bool isRemote: kind === "album" || kind === "playlist"
    readonly property int count: songs ? songs.count : 0

    // revision counter: trackAt() is a call, so the cover binding reads this to re-run on changes
    property int songsRevision: 0
    Connections {
        target: page.songs
        function onChanged() {
            page.songsRevision++
        }
    }

    readonly property string title: {
        // revision counter, so a renamed playlist shows its new name
        hub.playlistRevision
        switch (kind) {
        case "liked": return strings.page_liked
        case "history": return strings.page_history
        case "mine": return hub.library.playlistName(route.id)
        default: return content ? content.title : ""
        }
    }
    readonly property string subtitle: isRemote && content ? content.subtitle : ""
    // summed from the songs even for youtube pages, so it matches the status bar
    readonly property string summary: Format.listSummary(count, songs ? songs.totalSeconds : 0, strings)
    readonly property string coverUrl: {
        if (isRemote) {
            return content ? content.thumbnailUrl : ""
        }
        songsRevision
        return count > 0 ? songs.trackAt(0).thumbnailUrl : ""
    }

    readonly property bool isSaved: {
        // savedVersion is a revision counter for isSaved()
        hub.library.savedVersion
        return kind === "album" && hub.library.isSaved(route.id)
    }

    readonly property var actions: {
        const hasSongs = count > 0
        const list = [
            { id: "play", label: strings.action_play, primary: true, enabled: hasSongs },
            { id: "shuffle", label: strings.action_shuffle, enabled: hasSongs }
        ]
        if (kind === "history") {
            list.push({ id: "clear", label: strings.action_clear_history, enabled: hasSongs })
        } else if (kind === "mine") {
            list.push({ id: "rename", label: strings.action_rename })
            list.push({ id: "delete", label: strings.action_delete })
        } else if (kind === "album") {
            list.push({ id: "save", label: isSaved ? strings.action_unsave_album : strings.action_save_album })
            list.push({ id: "copy", label: strings.action_save_playlist, enabled: hasSongs })
        } else if (kind === "playlist") {
            list.push({ id: "copy", label: strings.action_save_playlist, enabled: hasSongs })
        }
        return list
    }

    readonly property string emptyText: {
        switch (kind) {
        case "liked": return strings.empty_liked
        case "history": return strings.empty_history
        case "mine": return strings.empty_playlist
        default: return strings.empty_remote
        }
    }

    function run(action) {
        switch (action) {
        case "play":
            hub.playRequested(songs, 0)
            break
        case "shuffle":
            hub.shuffleRequested(songs)
            break
        case "clear":
            hub.clearHistoryRequested()
            break
        case "rename":
            hub.renameRequested()
            break
        case "delete":
            hub.deletePlaylistRequested()
            break
        case "save":
            hub.toggleSaved({ kind: kind, browseId: route.id, title: content.title,
                              subtitle: content.subtitle, thumbnailUrl: content.thumbnailUrl })
            break
        case "copy": {
            // a local copy, so it survives youtube changing or removing the original
            const id = hub.library.createPlaylistFrom(content.title, songs)
            hub.openRequested("mine:" + id)
            break
        }
        }
    }

    PageHeader {
        id: head
        width: parent.width
        looks: page.hub.looks.page_header
        fonts: page.hub.fonts
        themeDirectory: page.hub.themeDirectory
        buttonLooks: page.hub.buttonLooks
        title: page.title
        subtitle: page.subtitle
        summary: page.summary
        coverUrl: page.coverUrl
        actions: page.actions
        canGoBack: page.hub.canGoBack
        renaming: page.hub.renaming && page.kind === "mine"
        onActionTriggered: id => page.run(id)
        onBackRequested: page.hub.backRequested()
        onRenamed: name => page.hub.renamed(name)
        onRenameCancelled: page.hub.renameCancelled()
    }

    HubSongList {
        hub: page.hub
        y: head.height
        width: parent.width
        height: parent.height - head.height
        model: page.songs
        showAlbum: page.kind !== "album"
        reorderable: page.kind === "mine"
        removable: page.kind === "mine" || page.kind === "history"
        busy: page.isRemote && page.content !== null && page.content.loading
        busyText: page.strings.loading
        problem: page.isRemote && page.content !== null ? page.content.problem : ""
        emptyText: page.emptyText
        onMoved: (from, to) => page.songs.moveRow(from, to)
        onRemoveRequested: row => page.songs.removeAt(row)
    }
}
