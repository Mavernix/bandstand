// a round-ended search field; every looks key is optional

import QtQuick
import QtQuick.Shapes
import "ThemeValues.js" as ThemeValues

Item {
    id: box

    required property var looks
    // { family, size }
    required property var font
    required property string themeDirectory

    // shown while empty and unfocused
    property string placeholder: ""
    property color selectionColor: "#3a6ea5"
    property color selectedTextColor: "#ffffff"

    property alias text: input.text
    readonly property bool focused: input.activeFocus

    signal accepted()
    signal moveDown()
    // escape clears the box first, then sends this
    signal cancelled()

    function focusAndSelect() {
        input.forceActiveFocus()
        input.selectAll()
    }
    function clear() {
        input.text = ""
    }

    readonly property real roundness: Math.floor(height / 2)

    Fill {
        anchors.fill: parent
        themeDirectory: box.themeDirectory
        fill: box.looks.fill ?? ({ color: "#ffffff", radius: box.roundness,
                                    border: { color: "#a0a0a0", width: 1 } })
    }

    // the magnifying glass, drawn in a 12x12 box scaled to glyph_size
    Shape {
        id: glass
        x: box.looks.glyph_inset ?? 7
        anchors.verticalCenter: parent.verticalCenter
        width: box.looks.glyph_size ?? 12
        height: width
        preferredRendererType: Shape.CurveRenderer

        readonly property real unit: width / 12
        readonly property color ink: ThemeValues.color(box.looks.glyph_color ?? "#747474")

        ShapePath {
            strokeColor: glass.ink
            strokeWidth: 1.9 * glass.unit
            fillColor: "transparent"
            PathAngleArc {
                centerX: 5 * glass.unit
                centerY: 5 * glass.unit
                radiusX: 3.9 * glass.unit
                radiusY: 3.9 * glass.unit
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: glass.ink
            strokeWidth: 2.4 * glass.unit
            capStyle: ShapePath.RoundCap
            startX: 8 * glass.unit
            startY: 8 * glass.unit
            PathLine {
                x: 11 * glass.unit
                y: 11 * glass.unit
            }
        }
    }

    Rectangle {
        id: clearButton
        visible: input.text !== ""
        width: box.looks.clear_size ?? 14
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: box.width - width - (box.looks.clear_inset ?? 4)
        color: ThemeValues.color(box.looks.clear_color ?? "#b9b9b9")

        Repeater {
            model: [45, -45]
            Rectangle {
                required property int modelData
                anchors.centerIn: parent
                width: clearButton.width * 0.5
                height: 1.5
                rotation: modelData
                color: ThemeValues.color(box.looks.clear_cross_color ?? "#ffffff")
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                box.clear()
                input.forceActiveFocus()
            }
        }
    }

    TextInput {
        id: input
        x: glass.x + glass.width + (box.looks.text_gap ?? 5)
        width: (clearButton.visible ? clearButton.x : box.width - 6) - x - 3
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        selectByMouse: true
        selectionColor: box.selectionColor
        selectedTextColor: box.selectedTextColor
        color: ThemeValues.color(box.looks.text_color ?? "#000000")
        font.family: box.font.family
        font.pixelSize: box.font.size

        Keys.onEscapePressed: {
            box.clear()
            box.cancelled()
        }
        Keys.onReturnPressed: box.accepted()
        Keys.onEnterPressed: box.accepted()
        Keys.onDownPressed: box.moveDown()

        Text {
            visible: input.text === "" && !input.activeFocus && box.placeholder !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: box.placeholder
            color: ThemeValues.color(box.looks.placeholder_color ?? "#808080")
            font: input.font
        }
    }
}
