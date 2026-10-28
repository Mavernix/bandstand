// a CardGrid wired to the pages hub (Pages.qml)

import "Routes.js" as Routes

CardGrid {
    id: grid

    required property var hub

    looks: hub.looks.cards
    messageLooks: hub.looks.song_list
    fonts: hub.fonts
    themeDirectory: hub.themeDirectory

    onOpened: card => hub.openRequested(Routes.make(card.kind, card.browseId))
    onPlayRequested: card => hub.playCardRequested(card.kind, card.browseId)
    onMenuRequested: (card, x, y) => {
        const place = grid.mapToItem(hub, x, y)
        hub.cardMenuRequested(card, place.x, place.y)
    }
}
