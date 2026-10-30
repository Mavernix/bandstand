// a table of songs with a header row, hearts, drag to reorder and drag out to the sidebar.
// used by every page that lists songs; the flags below switch features per page.

import QtQuick
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues
import "Format.js" as Format

Item {
    id: page

    required property var looks
    required property var fonts
    required property string themeDirectory
    // a TrackModel
    required property var model
    required property var strings

    property string playingVideoId: ""
    // null hides the heart column
    property var library: null
    // off on an album's own page, where it's the same for every row
    property bool showAlbum: true
    // rows can be dragged within the list (the user's playlists)
    property bool reorderable: false
    // the Delete key removes the marked row
    property bool removable: false

    // shown by EmptyMessage when there are no rows
    property bool busy: false
    property string busyText: ""
    property string problem: ""
    property string emptyText: ""

    // double-click, the row's play button, or Return
    signal activated(int row)
    signal menuRequested(int row, real x, real y)
    signal likeRequested(int row)
    signal moved(int from, int to)
    signal removeRequested(int row)
    // dragging a row out towards the sidebar, in window coordinates. in a reorderable
    // list that starts once the pointer is left of the list, elsewhere on any sideways drag
    signal songDragged(int row, real windowX, real windowY)
    signal songDropped(int row, real windowX, real windowY)
    // sent after a drop too, or when the row comes back into the list
    signal songDragEnded()

    // the title column takes whatever the others leave
    readonly property real numberWidth: looks.number_width
    readonly property real timeWidth: looks.time_width
    readonly property real artistWidth: width * looks.artist_fraction
    readonly property real albumWidth: showAlbum ? width * looks.album_fraction : 0
    readonly property real likeWidth: library !== null ? looks.like_width : 0
    readonly property real titleWidth: width - numberWidth - timeWidth - artistWidth - albumWidth - likeWidth
    readonly property real timeLeft: numberWidth + titleWidth
    readonly property real artistLeft: timeLeft + timeWidth
    readonly property real albumLeft: artistLeft + artistWidth
    readonly property real likeLeft: width - likeWidth

    readonly property var textFont: fonts.music_text

    // our own selection instead of ListView.currentIndex, which jumps to row 0 whenever the model fills
    property int markedRow: -1

    // without a mark, starts from the top or bottom end
    function moveMark(by) {
        if (view.count === 0) {
            return
        }
        const start = markedRow < 0 ? (by > 0 ? -1 : view.count) : markedRow
        markedRow = Math.max(0, Math.min(view.count - 1, start + by))
        view.positionViewAtIndex(markedRow, ListView.Contain)
    }

    Connections {
        target: page.model
        function onModelReset() {
            page.markedRow = -1
        }
    }

    component Cell: Text {
        property real inset: page.looks.cell_inset
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: inset
        rightPadding: inset
        elide: Text.ElideRight
        font.family: page.textFont.family
        font.pixelSize: page.textFont.size
    }

    // --- header

    Item {
        id: header
        width: parent.width
        height: page.looks.header_height

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: page.themeDirectory
            fill: !Window.active ? (page.looks.header_fill_inactive ?? page.looks.header_fill) : page.looks.header_fill
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: ThemeValues.color(page.looks.header_line_color)
        }

        // a column title with a separator line on its left
        component Title: Item {
            property string text
            property real columnLeft: 0
            property real columnWidth: 0
            property bool alignRight: false
            x: columnLeft
            width: columnWidth
            height: header.height

            Rectangle {
                width: 1
                height: parent.height - 6
                y: 3
                color: ThemeValues.color(page.looks.header_separator_color)
            }
            Cell {
                width: parent.width
                horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
                text: parent.text
                color: ThemeValues.color(page.looks.header_text_color)
                font.pixelSize: page.fonts.music_small.size
            }
        }

        Title { text: page.strings.column_title; columnLeft: page.numberWidth; columnWidth: page.titleWidth }
        Title { text: page.strings.column_time; columnLeft: page.timeLeft; columnWidth: page.timeWidth; alignRight: true }
        Title { text: page.strings.column_artist; columnLeft: page.artistLeft; columnWidth: page.artistWidth }
        Title { visible: page.showAlbum; text: page.strings.column_album; columnLeft: page.albumLeft; columnWidth: page.albumWidth }
    }

    // --- dragging rows

    // row being dragged or -1; dropGap 0 is above the first row, count below the last
    property int dragFrom: -1
    property int dropGap: -1
    // true while the row is being dragged out of the list rather than moved within it
    property bool dragLeaves: false
    // pointer y in the view, for auto-scrolling near the edges
    property real dragPointerY: 0
    readonly property real autoScrollZone: 28
    readonly property real autoScrollStep: 7

    function updateDropGap(pointerYInView) {
        const gap = Math.round((view.contentY + pointerYInView) / looks.row_height)
        dropGap = Math.max(0, Math.min(view.count, gap))
    }

    function dragMoved(xInView, yInView, windowX, windowY) {
        dragPointerY = yInView
        const leaves = !reorderable || xInView < 0
        if (leaves) {
            dropGap = -1
            songDragged(dragFrom, windowX, windowY)
        } else {
            if (dragLeaves) {
                // came back into the list
                songDragEnded()
            }
            updateDropGap(yInView)
        }
        dragLeaves = leaves
    }

    function dragDropped(windowX, windowY) {
        const from = dragFrom
        // removing the row first shifts the gaps below it up by one
        const to = dropGap > from ? dropGap - 1 : dropGap
        const leaving = dragLeaves
        dragFrom = -1
        dropGap = -1
        dragLeaves = false
        if (leaving) {
            songDropped(from, windowX, windowY)
        } else if (from >= 0 && to >= 0 && to !== from) {
            moved(from, to)
            markedRow = to
        }
        songDragEnded()
    }

    Timer {
        interval: 30
        repeat: true
        running: page.dragFrom >= 0 && !page.dragLeaves
            && (page.dragPointerY < page.autoScrollZone || page.dragPointerY > view.height - page.autoScrollZone)
        onTriggered: {
            const direction = page.dragPointerY < page.autoScrollZone ? -1 : 1
            const farthest = Math.max(0, view.contentHeight - view.height)
            view.contentY = Math.max(0, Math.min(farthest, view.contentY + direction * page.autoScrollStep))
            page.updateDropGap(page.dragPointerY)
        }
    }

    // --- rows

    ListView {
        id: view
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        model: page.model
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: page.dragFrom < 0
        keyNavigationEnabled: false

        Keys.onUpPressed: page.moveMark(-1)
        Keys.onDownPressed: page.moveMark(1)
        Keys.onReturnPressed: if (page.markedRow >= 0) page.activated(page.markedRow)
        Keys.onEnterPressed: if (page.markedRow >= 0) page.activated(page.markedRow)
        Keys.onDeletePressed: if (page.removable && page.markedRow >= 0) page.removeRequested(page.markedRow)

        delegate: Item {
            id: row

            required property int index
            required property string videoId
            required property string title
            required property string artist
            required property string album
            required property int durationSeconds

            readonly property bool playing: videoId !== "" && videoId === page.playingVideoId
            readonly property bool marked: index === page.markedRow
            readonly property bool hovered: hover.hovered
            readonly property bool liked: {
                if (page.library === null) {
                    return false
                }
                // likedVersion is a revision counter, read so this re-runs when likes change
                page.library.likedVersion
                return page.library.isLiked(videoId)
            }

            width: view.width
            height: page.looks.row_height
            opacity: page.dragFrom === index ? 0.45 : 1.0

            Rectangle {
                anchors.fill: parent
                visible: !row.playing
                color: ThemeValues.color(row.marked ? page.looks.marked_color
                    : row.index % 2 === 0 ? page.looks.row_color : page.looks.row_alternate_color)
            }
            Shell.Fill {
                anchors.fill: parent
                visible: row.playing
                themeDirectory: page.themeDirectory
                fill: !Window.active ? (page.looks.playing_fill_inactive ?? page.looks.playing_fill)
                    : page.looks.playing_fill
            }

            readonly property color mainColor: ThemeValues.color(playing ? page.looks.playing_text_color : page.looks.text_color)
            readonly property color quietColor: ThemeValues.color(playing ? page.looks.playing_quiet_text_color : page.looks.quiet_text_color)

            // number column; becomes a play button on hover
            Cell {
                visible: !row.hovered
                width: page.numberWidth
                horizontalAlignment: Text.AlignRight
                text: row.playing ? "♪" : row.index + 1
                color: row.quietColor
            }
            TransportGlyph {
                visible: row.hovered
                x: page.numberWidth - width - page.looks.cell_inset
                anchors.verticalCenter: parent.verticalCenter
                width: page.looks.play_glyph_size
                height: width
                kind: "play"
                color: row.mainColor
            }

            Cell { x: page.numberWidth; width: page.titleWidth; text: row.title; color: row.mainColor
                   font.bold: row.playing }
            Cell { x: page.timeLeft; width: page.timeWidth; text: row.durationSeconds > 0 ? Format.clock(row.durationSeconds) : ""; color: row.quietColor
                   horizontalAlignment: Text.AlignRight }
            Cell { x: page.artistLeft; width: page.artistWidth; text: row.artist; color: row.quietColor }
            Cell { visible: page.showAlbum; x: page.albumLeft; width: page.albumWidth; text: row.album; color: row.quietColor }

            HoverHandler {
                id: hover
            }
            MouseArea {
                id: rowArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // otherwise the ListView grabs the drag as a flick
                preventStealing: page.reorderable || dragging

                readonly property real dragStartPx: 6
                property real pressedX: 0
                property real pressedY: 0
                property bool dragging: false
                property bool dragEndedHere: false

                // in a non-reorderable list only a sideways drag counts, vertical is scrolling
                function startsDrag(mouse) {
                    const across = Math.abs(mouse.x - pressedX)
                    const along = Math.abs(mouse.y - pressedY)
                    if (Math.max(across, along) <= dragStartPx) {
                        return false
                    }
                    return page.reorderable || across > along
                }

                onPressed: mouse => {
                    pressedX = mouse.x
                    pressedY = mouse.y
                }
                onPositionChanged: mouse => {
                    if (!(pressedButtons & Qt.LeftButton)) {
                        return
                    }
                    if (!dragging && startsDrag(mouse)) {
                        dragging = true
                        page.dragFrom = row.index
                        page.markedRow = row.index
                    }
                    if (dragging) {
                        const inView = mapToItem(view, mouse.x, mouse.y)
                        const inWindow = mapToItem(null, mouse.x, mouse.y)
                        page.dragMoved(inView.x, inView.y, inWindow.x, inWindow.y)
                    }
                }
                onReleased: mouse => {
                    if (dragging) {
                        dragging = false
                        // swallow the click that follows the release
                        dragEndedHere = true
                        const inWindow = mapToItem(null, mouse.x, mouse.y)
                        page.dragDropped(inWindow.x, inWindow.y)
                    }
                }
                onClicked: mouse => {
                    if (dragEndedHere) {
                        dragEndedHere = false
                        return
                    }
                    page.markedRow = row.index
                    view.forceActiveFocus()
                    if (mouse.button === Qt.RightButton) {
                        const place = mapToItem(page, mouse.x, mouse.y)
                        page.menuRequested(row.index, place.x, place.y)
                    }
                }
                onDoubleClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        page.activated(row.index)
                    }
                }
            }
            // the hover play button: a single click in the number column
            MouseArea {
                width: page.numberWidth
                height: parent.height
                enabled: row.hovered && page.dragFrom < 0
                onClicked: page.activated(row.index)
            }

            // shown when liked, or on hover
            HeartGlyph {
                visible: page.library !== null && (row.liked || row.hovered)
                x: page.likeLeft + (page.likeWidth - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: page.looks.like_size
                height: width
                filled: row.liked
                color: ThemeValues.color(row.playing ? page.looks.playing_text_color
                    : row.liked ? page.looks.liked_color : page.looks.quiet_text_color)
            }
            MouseArea {
                x: page.likeLeft
                width: page.likeWidth
                height: parent.height
                enabled: page.library !== null && page.dragFrom < 0
                onClicked: page.likeRequested(row.index)
            }
        }
    }

    // drop indicator
    Rectangle {
        visible: page.dragFrom >= 0 && page.dropGap >= 0
        x: 0
        y: header.height + page.dropGap * page.looks.row_height - view.contentY - height / 2
        width: page.width
        height: 2
        color: ThemeValues.color(page.looks.drop_line_color)
        z: 2
    }

    EmptyMessage {
        anchors.centerIn: view
        width: view.width * 0.7
        visible: view.count === 0
        looks: page.looks
        fonts: page.fonts
        busy: page.busy
        busyText: page.busyText
        problem: page.problem
        emptyText: page.emptyText
    }
}
