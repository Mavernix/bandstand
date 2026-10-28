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
        y: display.looks.cover_inset
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

    // queue button, drawn as three lines
    Item {
        id: queueButton
        x: display.width - width - display.looks.queue_button_inset
        y: (display.height - height) / 2
        width: display.looks.queue_button_width
        height: display.looks.queue_button_height

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: display.themeDirectory
            fill: display.queueOpen || buttonArea.pressed ? display.looks.queue_button_open_fill
                : display.looks.queue_button_fill
        }
        Column {
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

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: display.looks.line_height
                radius: height / 2
                color: ThemeValues.color(display.looks.line_color)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * progress.fraction
                height: display.looks.line_height
                radius: height / 2
                color: ThemeValues.color(display.looks.line_played_color)
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
