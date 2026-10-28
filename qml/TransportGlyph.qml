// drawn transport icons, for themes without images for them

import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    // previous, play, pause or next
    property string kind: "play"
    property color color: "#555555"

    // in a 20x20 box, scaled to the item
    readonly property var paths: ({
        "play": "M 4 2 L 18 10 L 4 18 Z",
        "pause": "M 3 2 H 8 V 18 H 3 Z M 12 2 H 17 V 18 H 12 Z",
        "previous": "M 10 3 V 17 L 1 10 Z M 19 3 V 17 L 10 10 Z",
        "next": "M 10 3 V 17 L 19 10 Z M 1 3 V 17 L 10 10 Z"
    })

    Shape {
        width: 20
        height: 20
        scale: glyph.width / 20
        transformOrigin: Item.TopLeft

        ShapePath {
            fillColor: glyph.color
            strokeColor: "transparent"
            PathSvg {
                path: glyph.paths[glyph.kind] ?? glyph.paths["play"]
            }
        }
    }
}
