// a cover with a title and subtitle under it, and a play button on hover.
// artists get a round cover.

import QtQuick
import QtQuick.Effects
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: tile

    required property var looks
    required property var fonts
    required property string themeDirectory

    property string title: ""
    property string subtitle: ""
    property string thumbnailUrl: ""
    // round cover and centred text, for artists
    property bool round: false
    property bool playable: true

    signal opened()
    signal playRequested()
    signal menuRequested(real x, real y)

    readonly property bool hovered: hover.hovered

    width: looks.cover_size
    height: looks.cover_size + looks.text_gap + looks.text_height

    HoverHandler {
        id: hover
    }

    Item {
        id: cover
        width: tile.looks.cover_size
        height: width

        layer.enabled: tile.round
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: tile.themeDirectory
            fill: tile.looks.cover_fill
        }
        Image {
            anchors.fill: parent
            source: tile.thumbnailUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        // thin border so pale covers don't bleed into the page
        Rectangle {
            visible: !tile.round
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: ThemeValues.color(tile.looks.cover_edge_color)
        }
    }
    // mask for the round cover; only layered when round, since each one costs a shader
    Item {
        id: roundMask
        visible: false
        width: cover.width
        height: cover.height
        layer.enabled: tile.round
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "black"
        }
    }

    // bottom-left play button; on a round cover it's pulled in so it sits inside the circle
    readonly property real playInset: looks.play_inset + (round ? looks.cover_size * roundCornerShare : 0)
    readonly property real roundCornerShare: 0.12
    Rectangle {
        id: playButton
        visible: tile.playable && tile.hovered
        x: tile.playInset
        y: cover.height - height - tile.playInset
        width: tile.looks.play_size
        height: width
        radius: width / 2
        color: ThemeValues.color(playArea.pressed ? tile.looks.play_pressed_fill : tile.looks.play_fill)

        TransportGlyph {
            anchors.centerIn: parent
            // the triangle looks off-centre otherwise
            anchors.horizontalCenterOffset: 1
            width: parent.width * 0.42
            height: width
            kind: "play"
            color: ThemeValues.color(tile.looks.play_glyph_color)
        }
        MouseArea {
            id: playArea
            anchors.fill: parent
            onClicked: tile.playRequested()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                tile.menuRequested(mouse.x, mouse.y)
            } else {
                tile.opened()
            }
        }
    }

    Text {
        id: titleText
        y: cover.height + tile.looks.text_gap
        width: parent.width
        horizontalAlignment: tile.round ? Text.AlignHCenter : Text.AlignLeft
        elide: Text.ElideRight
        text: tile.title
        color: ThemeValues.color(tile.looks.title_color)
        font.family: tile.fonts.music_text.family
        font.pixelSize: tile.fonts.music_text.size
    }
    Text {
        y: titleText.y + titleText.height
        width: parent.width
        horizontalAlignment: tile.round ? Text.AlignHCenter : Text.AlignLeft
        elide: Text.ElideRight
        text: tile.subtitle
        color: ThemeValues.color(tile.looks.subtitle_color)
        font.family: tile.fonts.music_small.family
        font.pixelSize: tile.fonts.music_small.size
    }
}
