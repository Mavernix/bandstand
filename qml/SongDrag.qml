// a song dragged out of a list onto the sidebar, and the little title box that
// follows the pointer. coordinates are in the window.

import QtQuick
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: songDrag

    required property var looks
    required property var fonts
    required property string themeDirectory
    required property Sidebar dropZone

    property var song: null
    property point pointer: Qt.point(0, 0)

    // target is a playlist id, "new" (the playlists heading) or "liked"
    signal dropped(var song, string target)

    anchors.fill: parent
    // the drag belongs to the row it started on, so this takes no input
    enabled: false

    function targetAt(x, y) {
        const place = dropZone.mapFromItem(null, x, y)
        return dropZone.dropTargetAt(place.x, place.y)
    }

    function move(song, x, y) {
        songDrag.song = song
        pointer = Qt.point(x, y)
        dropZone.dropTarget = targetAt(x, y)
    }

    function drop(song, x, y) {
        const target = targetAt(x, y)
        end()
        if (target !== "") {
            dropped(song, target)
        }
    }

    function end() {
        song = null
        dropZone.dropTarget = ""
    }

    Item {
        id: ghost
        visible: songDrag.song !== null
        x: songDrag.pointer.x + songDrag.looks.sidebar.drag_ghost_offset[0]
        y: songDrag.pointer.y + songDrag.looks.sidebar.drag_ghost_offset[1]
        width: label.width + 2 * songDrag.looks.sidebar.drag_ghost_padding
        height: label.implicitHeight + songDrag.looks.sidebar.drag_ghost_padding
        opacity: 0.92

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: songDrag.themeDirectory
            fill: songDrag.looks.queue.fill
        }
        Text {
            id: label
            x: songDrag.looks.sidebar.drag_ghost_padding
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, songDrag.looks.sidebar.drag_ghost_max_width)
            elide: Text.ElideRight
            text: songDrag.song?.title ?? ""
            color: ThemeValues.color(songDrag.looks.queue.text_color)
            font.family: songDrag.fonts.music_text.family
            font.pixelSize: songDrag.fonts.music_text.size
        }
    }
}
