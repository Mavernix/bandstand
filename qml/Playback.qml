// the queue, looking up a song's audio, and the media player

import QtQuick
import QtMultimedia

Item {
    id: playback

    required property var queue
    required property var client
    required property var library
    required property var strings

    property real volume: 1.0

    // the queue's current song as a track map, or {} when idle
    property var nowPlaying: ({})
    property bool findingAudio: false
    property string problem: ""

    readonly property bool hasSong: (nowPlaying.videoId ?? "") !== ""
    readonly property bool isPlaying: player.playbackState === MediaPlayer.PlayingState
    readonly property bool nowPlayingLiked: {
        // likedVersion is a revision counter: isLiked() is a call, so read it to re-run on likes
        library.likedVersion
        return hasSong && library.isLiked(nowPlaying.videoId)
    }

    // while the next song's audio is looked up the player still has the old song's times
    readonly property int positionMs: findingAudio ? 0 : player.position
    readonly property int durationMs: !findingAudio && player.duration > 0
        ? player.duration : (nowPlaying.durationSeconds ?? 0) * 1000

    // "previous" within this many ms of the start goes to the song before, otherwise restarts
    readonly property int restartAfterMs: 3000

    // a card (album/artist/playlist) whose page is still loading, played once it arrives
    property var pendingCard: null
    property bool radioPending: false

    // a message for the status bar; "" clears it
    signal notify(string text)

    function startCurrent() {
        const song = queue.currentTrack()
        if (song.videoId === undefined) {
            return
        }
        pendingCard = null
        radioPending = false
        nowPlaying = song
        problem = ""
        findingAudio = true
        // clear the source too, otherwise play() during the lookup plays the previous song
        player.stop()
        player.source = ""
        client.findAudio(song.videoId)
    }

    function stop() {
        player.stop()
        player.source = ""
        nowPlaying = ({})
        findingAudio = false
        problem = ""
    }

    function playSongs(songs, row) {
        queue.playFrom(songs, row)
        startCurrent()
    }

    function playShuffled(songs) {
        queue.playShuffled(songs)
        startCurrent()
    }

    // a list of track maps, e.g. a shelf on the home page
    function playItems(items, index) {
        queue.playList(items, index)
        startCurrent()
    }

    function playQueueRow(row) {
        if (queue.jumpTo(row)) {
            startCurrent()
        }
    }

    function next() {
        if (queue.step(1)) {
            startCurrent()
        }
    }

    function previous() {
        if (queue.hasPrevious && player.position <= restartAfterMs) {
            queue.step(-1)
            startCurrent()
        } else {
            player.position = 0
        }
    }

    function playOrPause() {
        if (isPlaying) {
            player.pause()
        } else if (!findingAudio && player.source.toString() !== "") {
            player.play()
        }
    }

    function seek(positionMs) {
        player.position = positionMs
    }

    // play next, or append at the end; starts playing if the queue was empty
    function addToQueue(song, atEnd) {
        const wasEmpty = queue.count === 0
        if (atEnd) {
            queue.addToEnd(song)
        } else {
            queue.playNext(song)
        }
        if (wasEmpty) {
            startCurrent()
        }
    }

    function playCard(kind, id) {
        const page = client.page(kind, id)
        if (page.loading) {
            pendingCard = page
            notify(strings.status_loading)
        } else {
            // cached, or it failed right away (e.g. the helper didn't start)
            playLoadedCard(page)
        }
    }

    function playLoadedCard(page) {
        if (page.tracks.count > 0) {
            notify("")
            playSongs(page.tracks, 0)
        } else {
            notify(page.problem !== "" ? page.problem : strings.empty_remote)
        }
    }

    function cancelPendingCard() {
        pendingCard = null
    }

    function startRadio(song) {
        radioPending = true
        notify(strings.status_radio)
        client.startRadio(song.videoId)
    }

    Connections {
        target: playback.client

        // answers for a song we've already moved on from are dropped
        function onAudioFound(videoId, url) {
            if (videoId === playback.nowPlaying.videoId) {
                playback.findingAudio = false
                player.source = url
                player.play()
                playback.library.recordPlayed(playback.nowPlaying)
            }
        }
        function onAudioNotFound(videoId, message) {
            if (videoId === playback.nowPlaying.videoId) {
                playback.findingAudio = false
                playback.problem = message
            }
        }
        // ignored if something else was started meanwhile
        function onRadioFound(videoId) {
            if (playback.radioPending) {
                playback.notify("")
                playback.playSongs(playback.client.radioTracks, 0)
            }
        }
        function onRadioFailed(videoId, message) {
            if (playback.radioPending) {
                playback.radioPending = false
                playback.notify(message)
            }
        }
    }

    Connections {
        target: playback.pendingCard
        function onLoadingChanged() {
            const page = playback.pendingCard
            if (page !== null && !page.loading) {
                playback.pendingCard = null
                playback.playLoadedCard(page)
            }
        }
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            volume: playback.volume
        }
        onMediaStatusChanged: {
            if (mediaStatus !== MediaPlayer.EndOfMedia) {
                return
            }
            // back to the idle display once the queue runs out
            if (playback.queue.step(1)) {
                playback.startCurrent()
            } else {
                playback.stop()
            }
        }
        onErrorOccurred: (error, errorString) => playback.problem = errorString
    }
}
