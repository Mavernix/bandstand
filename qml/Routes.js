// page names:
//   "search", "home", "liked", "history", "albums", "artists"
//   "mine:ID"                                the user's own playlist
//   "album:ID", "artist:ID", "playlist:ID"   youtube music pages by browse id
// config.music.sidebar uses the same names.

.pragma library

// the sidebar for a config without config.music.sidebar, in the config's words
function defaultSidebar(strings) {
    return [
        { heading: strings.sidebar_music },
        { label: strings.page_search, page: "search" },
        { label: strings.page_home, page: "home" },
        { heading: strings.sidebar_library },
        { label: strings.page_liked, page: "liked" },
        { label: strings.page_history, page: "history" },
        { label: strings.page_albums, page: "albums" },
        { label: strings.page_artists, page: "artists" },
        { heading: strings.sidebar_playlists, playlists: true },
    ]
}

// "mine:abc" -> { kind: "mine", id: "abc" }, "history" -> { kind: "history", id: "" }
function parse(page) {
    const colon = page.indexOf(":")
    if (colon < 0) {
        return { kind: page, id: "" }
    }
    return { kind: page.substring(0, colon), id: page.substring(colon + 1) }
}

function make(kind, id) {
    return kind + ":" + id
}

// pages the helper fetches, so they can be loading or fail
function isRemote(kind) {
    return kind === "album" || kind === "artist" || kind === "playlist" || kind === "home"
}

// pages shown by SongPage
function isSongPage(kind) {
    return kind === "liked" || kind === "history" || kind === "mine"
        || kind === "album" || kind === "playlist"
}
