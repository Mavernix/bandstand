// the "up next" popover under the display: the queue, with an arrow pointing at its button

import QtQuick
import QtQuick.Effects
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues
import "Format.js" as Format

Item {
    id: panel

    required property var looks
    required property var fonts
    required property string themeDirectory
    // a PlayQueue
    required property var queue
    required property var strings

    // where the arrow points, in window coordinates
    property point target: Qt.point(0, 0)

    signal chosen(int row)
    signal removeRequested(int row)
    signal clearRequested()
    signal closed()

    anchors.fill: parent
    visible: false

    function open() {
        visible = true
        // scroll so the current song is at the top, already played ones above it
        view.positionViewAtIndex(Math.max(0, queue.current), ListView.Beginning)
    }
    function close() {
        if (visible) {
            visible = false
            closed()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: panel.close()
    }

    // the button sits at the display's right end, so the box hangs mostly to its left
    readonly property real arrowSize: looks.arrow_size
    readonly property real boxWidth: looks.width
    readonly property real rowsHeight: Math.max(1, queue.count) * looks.row_height
    readonly property real boxHeight: Math.min(looks.max_height, looks.header_height + 2 * looks.padding + rowsHeight)
    readonly property real boxX: Math.max(8, Math.min(width - boxWidth - 8, target.x - boxWidth + 40))
    readonly property real boxY: target.y + looks.gap + arrowSize
    // kept off the rounded corners
    readonly property real arrowCenter: Math.max(arrowSize + 8, Math.min(boxWidth - arrowSize - 8, target.x - boxX))

    // the arrow is drawn plainly in the box's colour; a box drawn from a picture names it in arrow_color
    readonly property color fillColor: ThemeValues.color(looks.fill.color ?? looks.fill.gradient?.[0] ?? looks.arrow_color)
    readonly property color rimColor: ThemeValues.color(looks.fill.border?.color)

    // the arrow is a rotated square, half hidden behind the box
    Rectangle {
        x: panel.boxX + panel.arrowCenter - width / 2
        y: panel.boxY - height / 2
        width: panel.arrowSize * Math.SQRT2
        height: width
        rotation: 45
        color: panel.fillColor
        border.width: 1
        border.color: panel.rimColor
    }

    Item {
        id: box
        x: panel.boxX
        y: panel.boxY
        width: panel.boxWidth
        height: panel.boxHeight

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: ThemeValues.color(panel.looks.shadow_color)
            shadowBlur: Math.min(1, panel.looks.shadow_blur / 32)
            shadowVerticalOffset: panel.looks.shadow_drop
        }

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: panel.themeDirectory
            fill: panel.looks.fill
        }

        // keep presses inside the box from closing it
        MouseArea {
            anchors.fill: parent
        }

        Text {
            x: panel.looks.title_inset
            y: (panel.looks.header_height - height) / 2
            text: panel.strings.queue_title
            color: ThemeValues.color(panel.looks.title_color)
            font.family: panel.fonts.music_title.family
            font.pixelSize: panel.fonts.music_title.size + 1
            font.bold: panel.fonts.music_title.bold ?? false
        }
        Text {
            id: clearLink
            x: box.width - width - panel.looks.title_inset
            y: (panel.looks.header_height - height) / 2
            text: panel.strings.queue_clear
            color: ThemeValues.color(panel.queue.hasNext ? panel.looks.clear_color : panel.looks.clear_disabled_color)
            font.family: panel.fonts.music_small.family
            font.pixelSize: panel.fonts.music_small.size

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: panel.queue.hasNext
                onClicked: panel.clearRequested()
            }
        }

        ListView {
            id: view
            x: panel.looks.padding
            y: panel.looks.header_height
            width: box.width - 2 * panel.looks.padding
            height: box.height - panel.looks.header_height - panel.looks.padding
            clip: true
            model: panel.queue
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row

                required property int index
                required property string title
                required property string artist
                required property int durationSeconds
                required property string thumbnailUrl

                readonly property bool isCurrent: index === panel.queue.current
                readonly property bool isPast: index < panel.queue.current
                readonly property bool showsCross: hover.hovered && !isCurrent

                width: view.width
                height: panel.looks.row_height

                Shell.Fill {
                    anchors.fill: parent
                    visible: row.isCurrent
                    themeDirectory: panel.themeDirectory
                    fill: panel.looks.current_fill
                }

                Item {
                    x: panel.looks.cover_inset
                    y: (parent.height - height) / 2
                    width: panel.looks.cover_size
                    height: width
                    opacity: row.isPast ? 0.55 : 1.0

                    Shell.Fill {
                        anchors.fill: parent
                        themeDirectory: panel.themeDirectory
                        fill: panel.looks.cover_fill
                    }
                    Image {
                        anchors.fill: parent
                        source: row.thumbnailUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                readonly property real textWidth: width - panel.looks.text_inset - panel.looks.time_width - 8
                readonly property color mainColor: ThemeValues.color(isPast ? panel.looks.past_text_color : panel.looks.text_color)

                // title over artist, the pair centred in the row whatever the fonts' sizes
                Column {
                    x: panel.looks.text_inset
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.textWidth

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: row.title
                        color: row.mainColor
                        font.family: panel.fonts.music_text.family
                        font.pixelSize: panel.fonts.music_text.size
                        font.bold: row.isCurrent
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: row.artist
                        color: ThemeValues.color(row.isPast ? panel.looks.past_text_color : panel.looks.quiet_text_color)
                        font.family: panel.fonts.music_small.family
                        font.pixelSize: panel.fonts.music_small.size
                    }
                }

                // length, swapped for a remove cross on hover
                Text {
                    visible: !row.showsCross
                    x: row.width - panel.looks.time_width - 8
                    width: panel.looks.time_width
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    // some songs (an artist's top songs) come without a length
                    text: row.durationSeconds > 0 ? Format.clock(row.durationSeconds) : ""
                    color: ThemeValues.color(row.isPast ? panel.looks.past_text_color : panel.looks.quiet_text_color)
                    font.family: panel.fonts.music_small.family
                    font.pixelSize: panel.fonts.music_small.size
                }
                Text {
                    visible: row.showsCross
                    x: row.width - width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: ThemeValues.color(panel.looks.remove_color)
                    font.family: panel.fonts.music_text.family
                    font.pixelSize: panel.looks.remove_size + 4
                }

                HoverHandler {
                    id: hover
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!row.isCurrent) {
                            panel.chosen(row.index)
                        }
                    }
                }
                MouseArea {
                    x: row.width - 36
                    width: 36
                    height: parent.height
                    enabled: row.showsCross
                    onClicked: panel.removeRequested(row.index)
                }
            }
        }

        Text {
            anchors.centerIn: view
            width: view.width - 32
            visible: panel.queue.count === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: panel.strings.queue_empty
            color: ThemeValues.color(panel.looks.empty_color)
            font.family: panel.fonts.music_small.family
            font.pixelSize: panel.fonts.music_small.size
        }
    }

    // covers the box's border where it crosses the arrow's base
    Rectangle {
        x: panel.boxX + panel.arrowCenter - panel.arrowSize + 2
        y: panel.boxY
        width: 2 * panel.arrowSize - 4
        height: 2
        color: panel.fillColor
    }
}
