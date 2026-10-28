// one menu box; items are { id, label, enabled, separator, checkable, checked, shortcut, children, slider }

import QtQuick
import QtQuick.Shapes
import "ThemeValues.js" as ThemeValues

Item {
    id: menu

    required property var settings
    property var items: []

    // square where the menu hangs from something (a submenu from its parent item)
    property bool squareTopLeft: false
    property bool squareTopRight: false

    // also re-sent from submenus
    signal chosen(int id)
    // before a submenu shows, so its items can be filled in
    signal submenuWanted(int id)
    // value is 0..1. a slider item should have enabled: false so key navigation skips it
    signal slid(int id, real value)

    property var looks: settings.theme.menu

    // see BoxFrame
    property real pointerX: -1
    readonly property var font: settings.theme.fonts.menu

    // hoveredIndex is also the keyboard mark; -1 for none
    property int hoveredIndex: -1
    property int submenuIndex: -1

    onItemsChanged: {
        hoveredIndex = -1
        submenuIndex = -1
    }

    // --- keyboard; the owner forwards keys to innermost()

    property var parentMenu: null
    property var openSubmenu: null

    function innermost() {
        return openSubmenu !== null ? openSubmenu.innermost() : menu
    }

    function canBeMarked(index) {
        const item = items[index]
        return item !== undefined && !item.separator && item.enabled
    }

    // by is 1 or -1; wraps around
    function moveMark(by) {
        const count = items.length
        let index = hoveredIndex
        for (let step = 0; step < count; step++) {
            index = index < 0 ? (by > 0 ? 0 : count - 1) : (index + by + count) % count
            if (canBeMarked(index)) {
                hoveredIndex = index
                submenuIndex = -1
                return
            }
        }
    }

    // type-to-select, case-insensitive
    function markByName(beginning) {
        const wanted = beginning.toLowerCase()
        for (let index = 0; index < items.length; index++) {
            if (canBeMarked(index) && items[index].label.toLowerCase().startsWith(wanted)) {
                hoveredIndex = index
                submenuIndex = -1
                return
            }
        }
    }

    function openMarkedSubmenu() {
        if (!canBeMarked(hoveredIndex) || items[hoveredIndex].children.length === 0) {
            return false
        }
        submenuWanted(items[hoveredIndex].id)
        submenuIndex = hoveredIndex
        if (openSubmenu !== null) {
            openSubmenu.moveMark(1)
        }
        return true
    }

    function closeAsSubmenu() {
        if (parentMenu === null) {
            return false
        }
        parentMenu.submenuIndex = -1
        return true
    }

    function chooseMarked() {
        if (!canBeMarked(hoveredIndex)) {
            return
        }
        if (!openMarkedSubmenu()) {
            chosen(items[hoveredIndex].id)
        }
    }

    // rows report their width, so this is redone whenever one changes
    property real widestRow: 0
    function measureRows() {
        let widest = 0
        for (let index = 0; index < rowItems.count; index++) {
            const rowItem = rowItems.itemAt(index)
            if (rowItem !== null) {
                widest = Math.max(widest, rowItem.neededWidth)
            }
        }
        widestRow = widest
    }

    width: Math.ceil(widestRow)
    height: rows.height + 2 * looks.padding

    // eats clicks on padding and separators so they don't fall through
    MouseArea {
        anchors.fill: parent
    }

    function shortcutText(keys) {
        let text = ""
        for (const key of keys) {
            text += menu.looks.key_symbols[key] ?? key
        }
        return text
    }

    BoxFrame {
        looks: menu.looks
        squareTopLeft: menu.squareTopLeft
        squareTopRight: menu.squareTopRight
        pointerX: menu.pointerX
    }

    Column {
        id: rows
        y: menu.looks.padding
        width: parent.width

        Repeater {
            id: rowItems
            model: menu.items
            onItemAdded: menu.measureRows()
            onItemRemoved: menu.measureRows()

            Item {
                id: row
                required property int index
                required property var modelData

                readonly property bool isSeparator: modelData.separator
                readonly property bool hasSubmenu: modelData.children.length > 0
                readonly property bool selected:
                    !isSeparator && modelData.enabled
                    && (menu.hoveredIndex === index || menu.submenuIndex === index)

                readonly property real endWidth: Math.max(shortcut.implicitWidth, arrow.implicitWidth)
                readonly property bool isSlider: modelData.slider !== undefined
                readonly property real neededWidth:
                    isSlider ? (menu.looks.slider_min_width ?? 180) :
                    menu.looks.text_inset + label.implicitWidth
                    + (endWidth > 0 ? menu.looks.shortcut_gap + endWidth : 0)
                    + menu.looks.shortcut_end_inset
                onNeededWidthChanged: menu.measureRows()

                width: rows.width
                height: isSeparator ? menu.looks.separator_height
                                    : (isSlider ? (menu.looks.slider_row_height ?? menu.looks.item_height + 4)
                                                : menu.looks.item_height)

                readonly property color textColor: ThemeValues.color(
                    selected ? menu.looks.highlight_text_color
                             : (modelData.enabled ? menu.looks.text_color : menu.looks.disabled_text_color))

                // separator_line_row counts from 1
                Rectangle {
                    visible: row.isSeparator
                    y: menu.looks.separator_line_row - 1
                    width: parent.width
                    height: 1
                    color: ThemeValues.color(menu.looks.separator_color)
                }

                Fill {
                    anchors.fill: parent
                    visible: row.selected
                    fill: menu.looks.highlight
                    themeDirectory: menu.settings.theme_directory
                }

                component RowText: Text {
                    visible: !row.isSeparator
                    color: row.textColor
                    font.family: menu.font.family
                    font.pixelSize: menu.font.size
                    // text_baseline_row counts from 1
                    y: menu.looks.text_baseline_row - baselineOffset
                }

                // a drawn tick if the theme describes one, else its character
                readonly property var tickShape: menu.looks.check_mark_shape
                RowText {
                    visible: !row.isSeparator && row.modelData.checked && row.tickShape === undefined
                    text: menu.looks.check_mark
                    x: (menu.looks.text_inset - implicitWidth) / 2
                }
                Shape {
                    visible: !row.isSeparator && row.modelData.checked && row.tickShape !== undefined
                    width: row.tickShape?.width ?? 0
                    height: row.tickShape?.height ?? 0
                    x: row.tickShape?.left_inset ?? 0
                    y: Math.round(label.y + label.baselineOffset - (row.tickShape?.middle_above_baseline ?? 4) - height / 2)
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        id: tickStrokes
                        readonly property var from: row.tickShape?.start ?? [0, 0]
                        readonly property var bend: row.tickShape?.bend ?? [0, 0]
                        readonly property var to: row.tickShape?.end ?? [0, 0]
                        fillColor: "transparent"
                        strokeWidth: row.tickShape?.stroke ?? 2
                        strokeColor: row.selected || row.tickShape?.color === undefined
                            ? row.textColor : ThemeValues.color(row.tickShape.color)
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.MiterJoin
                        startX: from[0]
                        startY: from[1]
                        PathLine { x: tickStrokes.bend[0]; y: tickStrokes.bend[1] }
                        PathLine { x: tickStrokes.to[0]; y: tickStrokes.to[1] }
                    }
                }

                RowText {
                    id: label
                    x: menu.looks.text_inset
                    text: row.modelData.label
                }

                RowText {
                    id: shortcut
                    text: menu.shortcutText(row.modelData.shortcut)
                    x: parent.width - menu.looks.shortcut_end_inset - implicitWidth
                }

                // a drawn triangle if the theme describes one, else its character
                readonly property var arrowShape: menu.looks.submenu_arrow_shape
                RowText {
                    id: arrow
                    text: row.hasSubmenu && row.arrowShape === undefined ? menu.looks.submenu_arrow : ""
                    x: parent.width - menu.looks.shortcut_end_inset - implicitWidth
                }
                Shape {
                    visible: row.hasSubmenu && row.arrowShape !== undefined
                    width: row.arrowShape?.width ?? 0
                    height: row.arrowShape?.height ?? 0
                    x: parent.width - (row.arrowShape?.end_inset ?? menu.looks.shortcut_end_inset) - width
                    // centred on the label's capitals
                    y: Math.round(label.y + label.baselineOffset - (row.arrowShape?.middle_above_baseline ?? 5) - height / 2)
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeWidth: -1
                        fillColor: row.selected || row.arrowShape?.color === undefined
                            ? row.textColor : ThemeValues.color(row.arrowShape.color)
                        startX: 0
                        startY: 0
                        PathLine { x: row.arrowShape?.width ?? 0; y: (row.arrowShape?.height ?? 0) / 2 }
                        PathLine { x: 0; y: row.arrowShape?.height ?? 0 }
                        PathLine { x: 0; y: 0 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    // on movement, not hover, so a menu opening under a resting pointer doesn't light anything up
                    onPositionChanged: {
                        if (menu.hoveredIndex === row.index) {
                            return
                        }
                        menu.hoveredIndex = row.index
                        if (row.hasSubmenu && row.modelData.enabled) {
                            menu.submenuWanted(row.modelData.id)
                            menu.submenuIndex = row.index
                        } else {
                            menu.submenuIndex = -1
                        }
                    }
                    onExited: {
                        if (menu.hoveredIndex === row.index) {
                            menu.hoveredIndex = -1
                        }
                    }
                    onClicked: {
                        if (!row.isSeparator && row.modelData.enabled && !row.hasSubmenu) {
                            menu.chosen(row.modelData.id)
                        }
                    }
                }

                // slider row, with the theme's [controls.slider] pictures if it has them
                Item {
                    id: sliderItem
                    visible: row.isSlider
                    readonly property var pictures: menu.settings.theme.controls?.slider ?? null
                    readonly property string themeDirectory: menu.settings.theme_directory
                    readonly property real inset: menu.looks.slider_inset ?? menu.looks.text_inset
                    // don't change items mid-drag: new rows would drop the drag
                    property real value: Math.max(0, Math.min(1, row.modelData.slider ?? 0))
                    x: inset
                    width: parent.width - 2 * inset
                    height: parent.height
                    readonly property real knobSide: pictures !== null ? knob.implicitWidth : (menu.looks.slider_knob_size ?? 15)
                    readonly property real travel: width - knobSide

                    BorderImage {
                        visible: sliderItem.pictures !== null
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        source: sliderItem.pictures !== null ? "file://" + sliderItem.themeDirectory + "/" + sliderItem.pictures.track : ""
                        readonly property var slice: sliderItem.pictures?.track_slice ?? [0, 0, 0, 0]
                        border.top: slice[0]
                        border.right: slice[1]
                        border.bottom: slice[2]
                        border.left: slice[3]
                    }
                    Rectangle {
                        visible: sliderItem.pictures === null
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: ThemeValues.color(menu.looks.separator_color)
                    }
                    Image {
                        id: knob
                        visible: sliderItem.pictures !== null
                        anchors.verticalCenter: parent.verticalCenter
                        x: sliderItem.value * sliderItem.travel
                        source: sliderItem.pictures !== null
                            ? "file://" + sliderItem.themeDirectory + "/" + (slideArea.pressed ? (sliderItem.pictures.thumb_pressed ?? sliderItem.pictures.thumb) : sliderItem.pictures.thumb)
                            : ""
                        width: sliderItem.pictures !== null ? implicitWidth : sliderItem.knobSide
                    }
                    Rectangle {
                        visible: sliderItem.pictures === null
                        anchors.verticalCenter: parent.verticalCenter
                        x: sliderItem.value * sliderItem.travel
                        width: sliderItem.knobSide
                        height: sliderItem.knobSide
                        radius: sliderItem.knobSide / 2
                        color: ThemeValues.color(slideArea.pressed ? menu.looks.highlight_text_color : menu.looks.text_color)
                    }
                    MouseArea {
                        id: slideArea
                        anchors.fill: parent
                        function set(x) {
                            const share = (x - sliderItem.knobSide / 2) / Math.max(1, sliderItem.travel)
                            sliderItem.value = Math.max(0, Math.min(1, share))
                            menu.slid(row.modelData.id, sliderItem.value)
                        }
                        onPressed: mouse => set(mouse.x)
                        onPositionChanged: mouse => {
                            if (pressed) {
                                set(mouse.x)
                            }
                        }
                    }
                }

                // loaded by file name since a component can't contain itself
                Loader {
                    id: submenu
                    readonly property bool wanted: menu.submenuIndex === row.index
                    onWantedChanged: {
                        if (!wanted) {
                            menu.openSubmenu = null
                            source = ""
                            return
                        }
                        setSource("MenuBox.qml", {
                            settings: menu.settings,
                            looks: menu.looks,
                            parentMenu: menu,
                            items: row.modelData.children
                        })
                    }
                    // mapToItem(null) gives window coordinates
                    readonly property bool fitsAfter: item === null
                        || row.mapToItem(null, row.width, 0).x + item.width <= menu.Window.width
                    onLoaded: {
                        menu.openSubmenu = item
                        // to the right, or left if it wouldn't fit; raised by the padding so the first rows line up
                        // bindings because the submenu's width is only known once its rows are measured
                        item.x = Qt.binding(() => submenu.fitsAfter ? row.width : -item.width)
                        item.y = -menu.looks.padding
                        item.squareTopLeft = Qt.binding(() => submenu.fitsAfter)
                        item.squareTopRight = Qt.binding(() => !submenu.fitsAfter)
                        item.chosen.connect(menu.chosen)
                        item.submenuWanted.connect(menu.submenuWanted)
                        item.slid.connect(menu.slid)
                    }
                }
            }
        }
    }
}
