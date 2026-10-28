// the like heart, drawn so it looks the same in every theme

import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    property bool filled: false
    property color color: "#707070"

    // in a 20x20 box, scaled to the item
    readonly property string heartPath:
        "M 10 17.5 C 3 12 1.5 9 1.5 6 C 1.5 3.5 3.5 2 5.5 2 C 7.5 2 9.2 3 10 4.5 "
        + "C 10.8 3 12.5 2 14.5 2 C 16.5 2 18.5 3.5 18.5 6 C 18.5 9 17 12 10 17.5 Z"

    Shape {
        width: 20
        height: 20
        scale: glyph.width / 20
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: glyph.filled ? glyph.color : "transparent"
            strokeColor: glyph.color
            strokeWidth: 1.6
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: glyph.heartPath
            }
        }
    }
}
