// saved albums or artists as a grid, depending on the route

import QtQuick

Item {
    id: page

    required property var hub

    readonly property bool showsAlbums: hub.route.kind === "albums"
    readonly property var strings: hub.strings

    PageHeader {
        id: head
        compact: true
        width: parent.width
        looks: page.hub.looks.page_header
        fonts: page.hub.fonts
        themeDirectory: page.hub.themeDirectory
        buttonLooks: page.hub.buttonLooks
        title: page.showsAlbums ? page.strings.page_albums : page.strings.page_artists
        canGoBack: page.hub.canGoBack
        onBackRequested: page.hub.backRequested()
    }

    HubCardGrid {
        hub: page.hub
        y: head.height
        width: parent.width
        height: parent.height - head.height
        model: page.showsAlbums ? page.hub.library.albums : page.hub.library.artists
        emptyText: page.showsAlbums ? page.strings.empty_albums : page.strings.empty_artists
    }
}
