// a SongList wired to the pages hub (Pages.qml)

SongList {
    id: songs

    required property var hub

    looks: hub.looks.song_list
    fonts: hub.fonts
    themeDirectory: hub.themeDirectory
    strings: hub.strings
    library: hub.library
    playingVideoId: hub.playingVideoId

    onActivated: row => hub.playRequested(model, row)
    onLikeRequested: row => hub.toggleLike(model.trackAt(row))
    onSongDragged: (row, x, y) => hub.songDragged(model.trackAt(row), x, y)
    onSongDropped: (row, x, y) => hub.songDropped(model.trackAt(row), x, y)
    onSongDragEnded: hub.songDragEnded()
    onMenuRequested: (row, x, y) => {
        const place = songs.mapToItem(hub, x, y)
        hub.songMenuRequested(model.trackAt(row), row, place.x, place.y)
    }
}
