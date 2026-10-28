// the top bar: transport and volume on the left, the display in the middle, search on the right

import QtQuick
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: bar

    required property var looks
    required property var displayLooks
    required property var searchLooks
    required property var fonts
    required property string themeDirectory

    property bool playing: false
    property bool canPlay: false
    property bool canPrevious: false
    property bool canNext: false
    property var track: ({})
    property int positionMs: 0
    property int durationMs: 0
    property bool loading: false
    property string problemText: ""
    property real volume: 1.0
    property bool queueOpen: false
    property bool liked: false

    property string idleText: ""
    property string loadingText: ""
    property string searchPlaceholder: ""

    signal previousClicked()
    signal playPauseClicked()
    signal nextClicked()
    signal seekRequested(int positionMs)
    signal volumeRequested(real volume)
    signal searchAccepted(string text)
    signal queueRequested()
    signal likeRequested()

    function focusSearch() {
        search.focusAndSelect()
    }

    function queueButtonBottom() {
        return display.queueButtonBottom()
    }

    // uses the theme's images (top_bar.pictures.<kind>.normal/pressed/disabled) when there
    // are any, otherwise a drawn glyph. the click area reaches a bit past the edge.
    component TransportButton: Item {
        id: button

        property string kind: "play"
        property bool usable: true
        signal clicked()

        readonly property var pictures: bar.looks.pictures?.[kind]
        readonly property string pictureState: !usable ? "disabled" : area.pressed ? "pressed" : "normal"
        // a theme may only ship the normal image
        readonly property string picturePath: pictures ? (pictures[pictureState] ?? pictures.normal) : ""

        // the loader has no item yet during creation
        width: look.item?.implicitWidth ?? 0
        height: look.item?.implicitHeight ?? 0

        Loader {
            id: look
            sourceComponent: button.pictures ? pictureLook : glyphLook
        }
        Component {
            id: pictureLook
            // qt picks the @2x file by itself on hidpi
            Image {
                source: "file://" + bar.themeDirectory + "/" + button.picturePath
            }
        }
        Component {
            id: glyphLook
            TransportGlyph {
                implicitWidth: bar.looks.glyph_size
                implicitHeight: bar.looks.glyph_size
                kind: button.kind
                color: ThemeValues.color(!button.usable ? bar.looks.glyph_disabled_color
                    : area.pressed ? bar.looks.glyph_pressed_color : bar.looks.glyph_color)
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -(bar.looks.transport_spacing / 2)
            enabled: button.usable
            onClicked: button.clicked()
        }
    }

    // like a window's tool bar, paler while the window is in the background (if the theme says how)
    readonly property bool inBackground: !Window.active

    Shell.Fill {
        anchors.fill: parent
        themeDirectory: bar.themeDirectory
        fill: bar.inBackground ? (bar.looks.fill_inactive ?? bar.looks.fill) : bar.looks.fill
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: ThemeValues.color(bar.inBackground ? (bar.looks.line_color_inactive ?? bar.looks.line_color)
                                                  : bar.looks.line_color)
    }

    Row {
        id: transport
        x: bar.looks.inset
        anchors.verticalCenter: parent.verticalCenter
        spacing: bar.looks.transport_spacing

        TransportButton {
            kind: "previous"
            usable: bar.canPrevious
            onClicked: bar.previousClicked()
        }
        TransportButton {
            kind: bar.playing ? "pause" : "play"
            usable: bar.canPlay
            onClicked: bar.playPauseClicked()
        }
        TransportButton {
            kind: "next"
            usable: bar.canNext
            onClicked: bar.nextClicked()
        }
    }

    // volume slider: the theme's slider pictures (volume_slider, from [controls.slider]) or drawn
    Item {
        id: volume
        readonly property var pictures: bar.looks.volume_slider ?? null
        x: transport.x + transport.width + bar.looks.volume_gap
        width: bar.looks.volume_width
        height: pictures !== null ? knobPicture.implicitHeight : bar.looks.volume_knob_size
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            visible: volume.pictures === null
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: bar.looks.volume_line_height
            radius: height / 2
            color: ThemeValues.color(bar.looks.volume_line_color)
        }
        Rectangle {
            visible: volume.pictures === null
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * bar.volume
            height: bar.looks.volume_line_height
            radius: height / 2
            color: ThemeValues.color(bar.looks.volume_filled_color)
        }
        Rectangle {
            visible: volume.pictures === null
            x: (parent.width - width) * bar.volume
            width: bar.looks.volume_knob_size
            height: width
            radius: width / 2
            color: ThemeValues.color(bar.looks.volume_knob_color)
            border.width: 1
            border.color: ThemeValues.color(bar.looks.volume_knob_border_color)
        }

        BorderImage {
            visible: volume.pictures !== null
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            source: visible ? "file://" + bar.themeDirectory + "/" + volume.pictures.track : ""
            readonly property var slice: volume.pictures?.track_slice ?? [0, 0, 0, 0]
            border.top: slice[0]
            border.right: slice[1]
            border.bottom: slice[2]
            border.left: slice[3]
        }
        Image {
            id: knobPicture
            visible: volume.pictures !== null
            x: (parent.width - width) * bar.volume
            source: visible ? "file://" + bar.themeDirectory + "/"
                + (volumeArea.pressed ? (volume.pictures.thumb_pressed ?? volume.pictures.thumb) : volume.pictures.thumb) : ""
        }
        MouseArea {
            id: volumeArea
            // a bit bigger than the slider so it's easier to grab
            readonly property real reach: 4
            anchors.fill: parent
            anchors.margins: -reach

            function volumeAt(x) {
                return Math.max(0, Math.min(1, (x - reach) / volume.width))
            }
            onPressed: mouse => bar.volumeRequested(volumeAt(mouse.x))
            onPositionChanged: mouse => {
                if (pressed) {
                    bar.volumeRequested(volumeAt(mouse.x))
                }
            }
        }
    }

    Display {
        id: display
        x: (bar.width - width) / 2
        y: (bar.height - height) / 2
        width: bar.displayLooks.width
        height: bar.displayLooks.height
        looks: bar.displayLooks
        fonts: bar.fonts
        themeDirectory: bar.themeDirectory
        track: bar.track
        positionMs: bar.positionMs
        durationMs: bar.durationMs
        loading: bar.loading
        problemText: bar.problemText
        idleText: bar.idleText
        loadingText: bar.loadingText
        queueOpen: bar.queueOpen
        liked: bar.liked
        onQueueRequested: bar.queueRequested()
        onLikeRequested: bar.likeRequested()
        onSeekRequested: positionMs => bar.seekRequested(positionMs)
    }

    Shell.SearchBox {
        id: search
        x: bar.width - bar.looks.inset - width
        y: (bar.height - height) / 2
        width: bar.searchLooks.width
        height: bar.searchLooks.height
        looks: bar.searchLooks
        font: bar.fonts.interface
        themeDirectory: bar.themeDirectory
        placeholder: bar.searchPlaceholder
        selectionColor: ThemeValues.color(bar.searchLooks.selection_color)
        selectedTextColor: ThemeValues.color(bar.searchLooks.selection_text_color)
        onAccepted: bar.searchAccepted(text)
    }
}
