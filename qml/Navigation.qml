// which page is shown, the back history, and the search state.
// pages are named as in Routes.js.

import QtQml
import "Routes.js" as Routes

QtObject {
    id: navigation

    required property var client
    required property var library
    required property string startPage

    property string page: ""
    // pages to go back to, latest last
    property var history: []
    readonly property var route: Routes.parse(page)
    readonly property bool canGoBack: history.length > 0
    // the ContentPage for album/artist/playlist/home routes, else null
    property var contentPage: null
    // the shown playlist's title is an editable field
    property bool renaming: false

    property string searchKind: "songs"
    property string searchQuery: ""
    // kinds already searched for the current query; other tabs search when first opened
    property var searchedKinds: ({})

    function enter(name) {
        const parsed = Routes.parse(name)
        // a deleted playlist can still be in the history
        if (parsed.kind === "mine" && library.playlistTracks(parsed.id) === null) {
            enter("search")
            return
        }
        page = name
        contentPage = Routes.isRemote(parsed.kind) ? client.page(parsed.kind, parsed.id) : null
        renaming = false
    }

    // from the sidebar: starts a fresh history
    function show(name) {
        if (name !== page) {
            history = []
            enter(name)
        }
    }

    // from inside a page: back leads to where we were
    function open(name) {
        if (name !== page) {
            history = history.concat([page])
            enter(name)
        }
    }

    function back() {
        if (history.length > 0) {
            const previous = history[history.length - 1]
            history = history.slice(0, -1)
            enter(previous)
        }
    }

    // a page that no longer exists (a deleted playlist)
    function forget(name) {
        history = history.filter(entry => entry !== name)
        if (page === name) {
            show("search")
        }
    }

    function search(text) {
        const query = text.trim()
        if (query === "") {
            return
        }
        searchQuery = query
        searchedKinds = ({})
        show("search")
        runSearch(searchKind)
    }

    function runSearch(kind) {
        client.search(searchQuery, kind)
        searchedKinds[kind] = true
    }

    function chooseSearchKind(kind) {
        searchKind = kind
        if (searchQuery !== "" && searchedKinds[kind] !== true) {
            runSearch(kind)
        }
    }

    Component.onCompleted: enter(startPage)
}
