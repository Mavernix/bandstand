// theme values to qml values

.pragma library
.import QtQuick as QtQuick

// themes write #rrggbbaa but qml reads 8 digits as #aarrggbb, so never pass one straight through
function color(text) {
    if (text === undefined || text === null) {
        return "transparent"
    }

    const red = parseInt(text.substr(1, 2), 16) / 255
    const green = parseInt(text.substr(3, 2), 16) / 255
    const blue = parseInt(text.substr(5, 2), 16) / 255
    const alpha = text.length === 9 ? parseInt(text.substr(7, 2), 16) / 255 : 1.0
    return Qt.rgba(red, green, blue, alpha)
}

// spread evenly unless the theme gives positions
function gradientPositions(fill) {
    if (fill.positions !== undefined) {
        return fill.positions
    }

    const count = fill.gradient.length
    const positions = []
    for (let index = 0; index < count; index++) {
        positions.push(index / (count - 1))
    }
    return positions
}

// "linear", "ease-in", "ease-out", anything else is ease-in-out
function easing(curve) {
    if (curve === "linear") {
        return QtQuick.Easing.Linear
    }
    if (curve === "ease-in") {
        return QtQuick.Easing.InQuad
    }
    if (curve === "ease-out") {
        return QtQuick.Easing.OutQuad
    }
    return QtQuick.Easing.InOutQuad
}
