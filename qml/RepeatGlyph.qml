// a drawn repeat icon, for themes without pictures for it: two arrows chasing each other
// round a loop, with a 1 inside for repeating one song

import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    property bool one: false
    property color color: "#555555"

    // in a 20x20 box, scaled to the item
    Shape {
        width: 20
        height: 20
        scale: glyph.width / 20
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        // the loop: top line heading right, bottom line heading left
        ShapePath {
            fillColor: "transparent"
            strokeColor: glyph.color
            strokeWidth: 1.8
            capStyle: ShapePath.FlatCap
            PathSvg {
                path: "M 3 11 V 8 Q 3 5.5 5.5 5.5 H 14 M 17 9 V 12 Q 17 14.5 14.5 14.5 H 6"
            }
        }
        // the arrow heads
        ShapePath {
            fillColor: glyph.color
            strokeColor: "transparent"
            PathSvg {
                path: "M 13.5 2.5 L 17.5 5.5 L 13.5 8.5 Z M 6.5 11.5 L 2.5 14.5 L 6.5 17.5 Z"
            }
        }
    }

    Text {
        visible: glyph.one
        anchors.centerIn: parent
        text: "1"
        color: glyph.color
        font.pixelSize: Math.round(glyph.height * 0.45)
        font.bold: true
    }
}
