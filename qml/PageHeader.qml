// a page's header: back arrow, cover, title (renamable in place), subtitle,
// summary and action buttons. buttons are shell push buttons styled by the dialog look.

import QtQuick
import QtQuick.Shapes
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: head

    required property var looks
    required property var fonts
    required property string themeDirectory
    // the dialog look (theme.dialog, or one from [controls])
    required property var buttonLooks

    property string title: ""
    property string subtitle: ""
    property string summary: ""
    property string coverUrl: ""
    // [{ id, label, primary, enabled }], primary gets the default button look
    property var actions: []
    property bool canGoBack: false
    property bool renaming: false
    // title only, no cover or buttons
    property bool compact: false

    signal actionTriggered(string id)
    signal backRequested()
    // on Return or when the field loses focus
    signal renamed(string name)
    signal renameCancelled()

    height: compact ? looks.compact_height : looks.height

    onRenamingChanged: {
        if (renaming) {
            titleField.text = title
            // the field only becomes visible (and focusable) after this handler
            Qt.callLater(() => {
                titleField.forceActiveFocus()
                titleField.selectAll()
            })
        }
    }

    readonly property real contentLeft: looks.padding + (canGoBack ? looks.back_width : 0)
    readonly property real textLeft: compact ? contentLeft : contentLeft + looks.cover_size + looks.cover_gap

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: ThemeValues.color(head.looks.line_color)
    }

    Item {
        visible: head.canGoBack
        x: head.looks.padding - 4
        y: (head.height - height) / 2
        width: head.looks.back_width
        height: 28

        Shape {
            anchors.centerIn: parent
            width: 10
            height: 16
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: ThemeValues.color(backArea.containsMouse ? head.looks.back_hover_color : head.looks.back_color)
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 8
                startY: 1
                PathLine { x: 2; y: 8 }
                PathLine { x: 8; y: 15 }
            }
        }
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: head.backRequested()
        }
    }

    Item {
        visible: !head.compact
        x: head.contentLeft
        y: head.looks.padding
        width: head.looks.cover_size
        height: width

        Shell.Fill {
            anchors.fill: parent
            themeDirectory: head.themeDirectory
            fill: head.looks.cover_fill
        }
        Image {
            anchors.fill: parent
            source: head.coverUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    FontMetrics {
        id: titleMetrics
        font.family: head.fonts.music_page_title.family
        font.pixelSize: head.fonts.music_page_title.size
        font.bold: head.fonts.music_page_title.bold ?? false
    }

    Column {
        x: head.textLeft
        // the title's capitals start level with the cover's top, not the empty space above them
        y: head.compact ? (head.height - height) / 2
                        : head.looks.padding - Math.round(titleMetrics.ascent - titleMetrics.capitalHeight)
        width: head.width - head.textLeft - head.looks.padding
        spacing: 2

        Text {
            visible: !head.renaming
            width: parent.width
            elide: Text.ElideRight
            text: head.title
            color: ThemeValues.color(head.looks.title_color)
            font.family: head.fonts.music_page_title.family
            font.pixelSize: head.fonts.music_page_title.size
            font.bold: head.fonts.music_page_title.bold ?? false
        }

        Item {
            visible: head.renaming
            width: parent.width
            // the line sits a little below the descenders
            height: titleField.implicitHeight + Math.round(titleMetrics.descent / 2) + renameLine.height

            TextInput {
                id: titleField
                width: parent.width
                color: ThemeValues.color(head.looks.title_color)
                font.family: head.fonts.music_page_title.family
                font.pixelSize: head.fonts.music_page_title.size
                font.bold: head.fonts.music_page_title.bold ?? false
                selectionColor: ThemeValues.color(head.looks.rename_line_color)
                selectedTextColor: ThemeValues.color(head.looks.rename_selected_text_color)
                clip: true

                // so Return/Escape followed by the focus loss only reports once
                property bool finished: false
                onActiveFocusChanged: {
                    if (head.renaming && !activeFocus && !finished) {
                        finished = true
                        head.renamed(text)
                    }
                    if (activeFocus) {
                        finished = false
                    }
                }
                Keys.onReturnPressed: {
                    finished = true
                    head.renamed(text)
                }
                Keys.onEnterPressed: {
                    finished = true
                    head.renamed(text)
                }
                Keys.onEscapePressed: {
                    finished = true
                    head.renameCancelled()
                }
            }
            Rectangle {
                id: renameLine
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2
                color: ThemeValues.color(head.looks.rename_line_color)
            }
        }

        Text {
            visible: head.subtitle !== ""
            width: parent.width
            elide: Text.ElideRight
            text: head.subtitle
            color: ThemeValues.color(head.looks.subtitle_color)
            font.family: head.fonts.music_text.family
            font.pixelSize: head.fonts.music_text.size
        }
        Text {
            visible: head.summary !== ""
            width: parent.width
            elide: Text.ElideRight
            text: head.summary
            color: ThemeValues.color(head.looks.summary_color)
            font.family: head.fonts.music_small.family
            font.pixelSize: head.fonts.music_small.size
        }
    }

    Row {
        visible: !head.compact
        x: head.textLeft
        y: head.height - head.looks.padding - (head.buttonLooks.button_height ?? 24)
        spacing: head.looks.button_gap

        Repeater {
            model: head.actions

            Shell.PushButton {
                required property var modelData
                looks: head.buttonLooks
                fonts: head.fonts
                themeDirectory: head.themeDirectory
                text: modelData.label
                isDefault: modelData.primary ?? false
                enabled: modelData.enabled ?? true
                width: wantedWidth
                onClicked: head.actionTriggered(modelData.id)
            }
        }
    }
}
