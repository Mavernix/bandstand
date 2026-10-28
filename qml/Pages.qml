// the area right of the sidebar. each page gets this item as `hub`: it reads
// shared state from it and sends requests up through its signals; Main decides
// what they mean. only plain library edits (likes, saves) are done here.

import QtQuick
import "Routes.js" as Routes

Item {
    id: pages

    required property var looks
    required property var fonts
    required property string themeDirectory
    // the dialog look (theme.dialog, or one from [controls]), for the push buttons
    required property var buttonLooks
    required property var strings
    required property var client
    required property var library

    property var route: ({ kind: "search", id: "" })
    property var contentPage: null
    property bool canGoBack: false
    property string playingVideoId: ""
    property string searchKind: "songs"
    property string searchQuery: ""
    property bool renaming: false

    // the TrackModel the page lists, or null
    readonly property var songs: {
        switch (route.kind) {
        // the other search tabs list cards
        case "search": return searchKind === "songs" ? client.results : null
        case "liked": return library.liked
        case "history": return library.history
        case "mine": return library.playlistTracks(route.id)
        case "album":
        case "playlist":
        case "artist": return contentPage !== null ? contentPage.tracks : null
        }
        return null
    }

    // revision counter: playlistName() is a call with no notify signal, so bindings that
    // use it read this to re-run when the playlists change
    property int playlistRevision: 0
    Connections {
        target: pages.library.playlists
        function onDataChanged() { pages.playlistRevision++ }
        function onRowsInserted() { pages.playlistRevision++ }
        function onRowsRemoved() { pages.playlistRevision++ }
        function onModelReset() { pages.playlistRevision++ }
    }

    signal playRequested(var songs, int row)
    signal shuffleRequested(var songs)
    // a list of track maps (home shelves)
    signal playItemsRequested(var items, int index)
    signal playCardRequested(string kind, string id)
    signal openRequested(string page)
    signal backRequested()
    // row is -1 for a song that isn't in the page's list; x/y are in this item
    signal songMenuRequested(var song, int row, real x, real y)
    signal cardMenuRequested(var card, real x, real y)
    signal searchKindChosen(string kind)
    // dragging a song to the sidebar; x/y are in the window
    signal songDragged(var song, real x, real y)
    signal songDropped(var song, real x, real y)
    signal songDragEnded()
    signal renameRequested()
    signal renamed(string name)
    signal renameCancelled()
    signal deletePlaylistRequested()
    signal clearHistoryRequested()

    function toggleLike(song) {
        library.setLiked(song, !library.isLiked(song.videoId))
    }

    function toggleSaved(card) {
        if (library.isSaved(card.browseId)) {
            library.unsave(card.browseId)
        } else {
            library.save(card)
        }
    }

    // search stays alive so it keeps its results; the rest are loaded on demand
    // (two views on one model would each build their rows)
    SearchPage {
        hub: pages
        anchors.fill: parent
        visible: pages.route.kind === "search"
    }
    Loader {
        anchors.fill: parent
        active: pages.route.kind === "home"
        sourceComponent: HomePage { hub: pages }
    }
    Loader {
        anchors.fill: parent
        active: Routes.isSongPage(pages.route.kind)
        sourceComponent: SongPage { hub: pages }
    }
    Loader {
        anchors.fill: parent
        active: pages.route.kind === "albums" || pages.route.kind === "artists"
        sourceComponent: CardPage { hub: pages }
    }
    Loader {
        anchors.fill: parent
        active: pages.route.kind === "artist"
        sourceComponent: ArtistPage { hub: pages }
    }
}
