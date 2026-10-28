// search results under tabs; the query itself comes from the top bar's search box

import QtQuick

Item {
    id: page

    required property var hub

    readonly property string kind: hub.searchKind
    readonly property var strings: hub.strings
    readonly property var client: hub.client

    readonly property string emptyText: hub.searchQuery === "" ? strings.empty
        : strings.nothing_found.replace("%1", hub.searchQuery)

    Tabs {
        id: tabs
        width: parent.width
        looks: page.hub.looks.tabs
        fonts: page.hub.fonts
        themeDirectory: page.hub.themeDirectory
        entries: [
            { id: "songs", label: page.strings.tab_songs },
            { id: "albums", label: page.strings.tab_albums },
            { id: "artists", label: page.strings.tab_artists },
            { id: "playlists", label: page.strings.tab_playlists }
        ]
        current: page.kind
        onChosen: id => page.hub.searchKindChosen(id)
    }

    HubSongList {
        hub: page.hub
        visible: page.kind === "songs"
        y: tabs.height
        width: parent.width
        height: parent.height - tabs.height
        model: page.client.results
        busy: page.client.searching
        busyText: page.strings.searching
        problem: page.client.problem
        emptyText: page.emptyText
    }

    HubCardGrid {
        hub: page.hub
        visible: page.kind !== "songs"
        y: tabs.height
        width: parent.width
        height: parent.height - tabs.height
        model: page.kind === "albums" ? page.client.albumResults
            : page.kind === "artists" ? page.client.artistResults : page.client.playlistResults
        busy: page.client.searching
        busyText: page.strings.searching
        problem: page.client.problem
        emptyText: page.emptyText
    }
}
