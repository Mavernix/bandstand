// the lcd-style display in the middle of the top bar: cover, title, artist and the seek bar

import QtQuick
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues
import "Format.js" as Format

Item {
    id: display

    required property var looks
    required property var fonts
    required property string themeDirectory

    // track map (title, artist, thumbnailUrl) or {} when idle
    property var track: ({})
    property int positionMs: 0
    property int durationMs: 0
    property string idleText: ""
    property string loadingText: ""
    property bool loading: false
    property string problemText: ""
    property bool queueOpen: false
    property bool liked: false

    signal seekRequested(int positionMs)
    signal queueRequested()
    signal likeRequested()

    // bottom centre of the queue button in window coordinates, for the up next arrow
    function queueButtonBottom() {
        return display.mapToItem(null, queueButton.x + queueButton.width / 2, queueButton.y + queueButton.height)
    }

    readonly property bool hasTrack: (track.title ?? "") !== ""
    readonly property bool canSeek: durationMs > 0

    Shell.Fill {
        anchors.fill: parent
        themeDirectory: display.themeDirectory
        fill: display.looks.fill
    }

    // the fill shows until the image has loaded
    Item {
        id: cover
        x: display.looks.cover_inset
        // cover_top, if the theme places the cover lower or higher than in from the side
        y: display.looks.cover_top ?? display.looks.cover_inset
        width: display.looks.cover_size
        height: display.looks.cover_size
        visible: display.hasTrack

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: display.themeDirectory
            fill: display.looks.cover_fill
        }
        Image {
            anchors.fill: parent
            source: display.track.thumbnailUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    // queue button: the theme's glyph pictures (queue_glyph.normal/pressed/open) or three drawn lines
    Item {
        id: queueButton
        x: display.width - width - display.looks.queue_button_inset
        y: (display.height - height) / 2
        width: display.looks.queue_button_width
        height: display.looks.queue_button_height

        readonly property var pictures: display.looks.queue_glyph

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: display.themeDirectory
            fill: display.queueOpen || buttonArea.pressed ? display.looks.queue_button_open_fill
                : display.looks.queue_button_fill
        }
        Image {
            visible: queueButton.pictures !== undefined
            anchors.centerIn: parent
            source: !visible ? ""
                : "file://" + display.themeDirectory + "/" + (buttonArea.pressed ? queueButton.pictures.pressed
                    : display.queueOpen ? queueButton.pictures.open : queueButton.pictures.normal)
        }
        Column {
            visible: queueButton.pictures === undefined
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: 3
                Rectangle {
                    width: 12
                    height: 2
                    color: ThemeValues.color(display.looks.queue_glyph_color)
                }
            }
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            onClicked: display.queueRequested()
        }
    }

    Item {
        id: likeButton
        visible: display.hasTrack
        x: queueButton.x - width - display.looks.like_gap
        y: queueButton.y
        width: display.looks.queue_button_width
        height: display.looks.queue_button_height

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: display.themeDirectory
            fill: likeArea.pressed ? display.looks.queue_button_open_fill : display.looks.queue_button_fill
        }
        HeartGlyph {
            anchors.centerIn: parent
            width: display.looks.like_glyph_size
            height: width
            filled: display.liked
            color: ThemeValues.color(display.liked ? display.looks.liked_glyph_color : display.looks.queue_glyph_color)
        }
        MouseArea {
            id: likeArea
            anchors.fill: parent
            onClicked: display.likeRequested()
        }
    }

    readonly property real textLeft: hasTrack ? cover.x + cover.width + looks.cover_inset : looks.cover_inset
    readonly property real textWidth: width - textLeft - looks.cover_inset
        - looks.queue_button_width - looks.queue_button_inset
        - (hasTrack ? looks.queue_button_width + looks.like_gap : 0)

    Text {
        x: display.textLeft
        width: display.textWidth
        anchors.verticalCenter: parent.verticalCenter
        visible: !display.hasTrack
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: display.idleText
        color: ThemeValues.color(display.looks.idle_color)
        font.family: display.fonts.music_text.family
        font.pixelSize: display.fonts.music_text.size
    }

    Text {
        id: title
        x: display.textLeft
        y: display.looks.text_top
        width: display.textWidth
        visible: display.hasTrack
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: display.track.title ?? ""
        color: ThemeValues.color(display.looks.title_color)
        font.family: display.fonts.music_title.family
        font.pixelSize: display.fonts.music_title.size
        font.bold: display.fonts.music_title.bold ?? false
    }

    Text {
        x: display.textLeft
        y: title.y + title.height + (display.looks.line_gap ?? 0)
        width: display.textWidth
        visible: display.hasTrack
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: display.problemText !== "" ? display.problemText
            : display.loading ? display.loadingText : (display.track.artist ?? "")
        color: ThemeValues.color(display.problemText !== "" ? display.looks.problem_color : display.looks.artist_color)
        font.family: display.fonts.music_small.family
        font.pixelSize: display.fonts.music_small.size
    }

    // elapsed time, seek bar, remaining time
    Item {
        id: progress
        x: display.textLeft
        width: display.textWidth
        height: display.looks.scrubber_height
        y: display.height - display.looks.scrubber_bottom - height
        visible: display.hasTrack

        readonly property real timeWidth: display.looks.time_width
        readonly property real fraction: display.durationMs > 0
            ? Math.min(1, display.positionMs / display.durationMs) : 0

        Text {
            width: progress.timeWidth
            anchors.verticalCenter: parent.verticalCenter
            text: Format.clock(display.positionMs / 1000)
            color: ThemeValues.color(display.looks.time_color)
            font.family: display.fonts.music_time.family
            font.pixelSize: display.fonts.music_time.size
        }
        Text {
            x: parent.width - progress.timeWidth
            width: progress.timeWidth
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: display.canSeek ? "-" + Format.clock((display.durationMs - display.positionMs) / 1000) : ""
            color: ThemeValues.color(display.looks.time_color)
            font.family: display.fonts.music_time.family
            font.pixelSize: display.fonts.music_time.size
        }

        Item {
            id: line
            x: progress.timeWidth + display.looks.time_gap
            width: parent.width - 2 * (progress.timeWidth + display.looks.time_gap)
            height: parent.height

            // the line and its played part are fills (line_fill, line_played_fill) when
            // the theme gives them, else drawn in line_color and line_played_color
            Shell.Fill {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: display.looks.line_height
                themeDirectory: display.themeDirectory
                fill: display.looks.line_fill
                      ?? { color: display.looks.line_color, radius: display.looks.line_height / 2 }
            }
            // with a knob, the played line runs to its middle, and is never
            // narrower than its left end, which the knob covers at the start
            Shell.Fill {
                anchors.verticalCenter: parent.verticalCenter
                width: knob.visible
                    ? Math.max(knob.x + knob.width / 2, display.looks.line_played_fill?.slice?.[3] ?? 0)
                    : parent.width * progress.fraction
                height: display.looks.line_height
                visible: width > 0
                themeDirectory: display.themeDirectory
                fill: display.looks.line_played_fill
                      ?? { color: display.looks.line_played_color, radius: display.looks.line_height / 2 }
            }
            // the knob at the playing position, if the theme has a picture for it
            Image {
                id: knob
                visible: display.looks.knob !== undefined
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - width) * progress.fraction
                source: visible ? "file://" + display.themeDirectory + "/" + display.looks.knob : ""
            }
            MouseArea {
                anchors.fill: parent
                enabled: display.canSeek
                onPressed: mouse => display.seekRequested(Math.round(mouse.x / width * display.durationMs))
                onPositionChanged: mouse => {
                    if (pressed) {
                        display.seekRequested(Math.round(Math.max(0, Math.min(mouse.x, width)) / width * display.durationMs))
                    }
                }
            }
        }
    }
}
