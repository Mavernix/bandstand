// the program's look, worked out once from the theme:
//   1. a whole [music] table drawn from the theme's shared [controls] colours and
//      pictures, with plain sizes for everything else (lookFromControls below)
//   2. the theme's own [music] table on top, key by key, so it only needs the keys a
//      look wants to change, and a full table (like the plain theme's) wins outright
// a theme with neither table gets a neutral light look.
// plain javascript without qt, so it can be checked outside the program.

.pragma library

// --- colours, as the theme writes them: "#rrggbb" or "#rrggbbaa"

function channels(text) {
    const value = [1, 3, 5, 7].map(at => parseInt(text.substr(at, 2), 16))
    if (text.length < 9) {
        value[3] = 255
    }
    return value
}

function hex(value) {
    const parts = value.map(part => Math.round(part).toString(16).padStart(2, "0"))
    return "#" + parts.slice(0, 3).join("") + (value[3] < 255 ? parts[3] : "")
}

// `from` moved `amount` (0 to 1) of the way towards `to`
function mix(from, to, amount) {
    const a = channels(from)
    const b = channels(to)
    return hex(a.map((part, index) => part + (b[index] - part) * amount))
}

function withAlpha(color, alpha) {
    const value = channels(color)
    value[3] = alpha * 255
    return hex(value)
}

function isDark(color) {
    const [red, green, blue] = channels(color)
    return 0.299 * red + 0.587 * green + 0.114 * blue < 128
}

// --- fills from what [controls] writes

// [controls] gives one colour or two from top to bottom
function colorFill(colors, extra) {
    const list = Array.isArray(colors) ? colors : [colors]
    const fill = list.length > 1 ? { gradient: list } : { color: list[0] }
    return Object.assign(fill, extra ?? {})
}

function middleColor(colors) {
    const list = Array.isArray(colors) ? colors : [colors]
    return list.length > 1 ? mix(list[0], list[list.length - 1], 0.5) : list[0]
}

function pictureFill(image, slice) {
    return { image: image, slice: slice ?? [0, 0, 0, 0] }
}

// --- the shared colours, with neutral ones for a theme without [controls]

function paletteOf(controls) {
    const window = controls.window_color ?? "#efefef"
    const dark = controls.dark ?? isDark(window)
    const text = controls.text_color ?? (dark ? "#e6e6e6" : "#202020")
    const base = controls.base_color ?? (dark ? "#1f2023" : "#ffffff")
    const highlight = controls.highlight_color ?? "#3a6ea5"
    const toolBar = controls.tool_bar ?? {}
    const selected = controls.selected_item ?? {}
    const barFill = toolBar.fill ?? [mix(window, text, 0.05)]

    return {
        dark: dark,
        window: window,
        text: text,
        base: base,
        highlight: highlight,
        highlightText: controls.highlight_text_color ?? "#ffffff",
        // lesser text: artists, times, headings
        quiet: mix(text, base, 0.45),
        faint: mix(text, base, 0.6),
        // a line that separates parts of the window, and a finer one inside a page
        rule: mix(text, window, 0.65),
        hairline: mix(text, base, 0.82),
        placeholder: mix(text, base, 0.78),
        barFill: barFill,
        barColor: middleColor(barFill),
        barLine: toolBar.bottom_line ?? mix(text, window, 0.65),
        barFillInactive: toolBar.fill_inactive,
        barLineInactive: toolBar.bottom_line_inactive,
        selectedFill: selected.fill ?? [highlight],
        selectedText: selected.text_color ?? controls.highlight_text_color ?? "#ffffff",
        // a gradient selection is a mac-style bar across the whole list, a flat one a rounded box
        selectedIsBar: Array.isArray(selected.fill) && selected.fill.length > 1,
        // a shade over whatever is below: darker on a light theme, lighter on a dark one
        overlay: alpha => withAlpha(dark ? "#ffffff" : "#000000", alpha),
    }
}

// the whole [music] table from the shared controls.
// every colour comes from the palette; the sizes are the plain theme's.
function lookFromControls(p, controls, fontSize) {
    const textField = controls.text_field
    const tabs = controls.tabs
    const slider = controls.slider
    // a picture control is as tall as its two end strips and a line of text, as toolkits draw it
    const pictureHeight = slice => slice[0] + slice[2] + fontSize

    return {
        window_size: [1100, 700],
        page_color: p.base,

        // the bar across the top is the window's tool bar
        top_bar: {
            height: 64,
            fill: colorFill(p.barFill),
            fill_inactive: p.barFillInactive !== undefined ? colorFill(p.barFillInactive) : undefined,
            line_color: p.barLine,
            line_color_inactive: p.barLineInactive,
            inset: 20,
            transport_spacing: 20,
            glyph_size: 18,
            glyph_color: mix(p.text, p.barColor, 0.2),
            glyph_pressed_color: mix(p.text, p.dark ? "#ffffff" : "#000000", 0.5),
            glyph_disabled_color: mix(p.text, p.barColor, 0.65),
            volume_gap: 28,
            volume_width: 80,
            volume_line_height: 4,
            volume_line_color: mix(p.text, p.barColor, 0.7),
            // the volume is filled like a progress: in the selection colour
            volume_filled_color: p.highlight,
            volume_knob_size: 12,
            volume_knob_color: p.base,
            volume_knob_border_color: p.rule,
            // [controls.slider]'s pictures stand in for the drawn volume
            volume_slider: slider !== undefined && slider.track !== undefined ? slider : undefined,
        },

        // the display sits in the tool bar like a well, a shade off the window colour
        display: {
            width: 400,
            height: 46,
            fill: { gradient: [mix(p.window, p.text, 0.06), mix(p.window, p.base, 0.6)], radius: 4,
                    border: { color: mix(p.text, p.window, 0.7), width: 1 } },
            cover_size: 34,
            cover_inset: 6,
            cover_fill: { color: p.placeholder },
            text_top: 5,
            line_gap: 0,
            title_color: p.text,
            artist_color: mix(p.text, p.window, 0.35),
            idle_color: p.quiet,
            problem_color: "#b02020",
            time_color: p.quiet,
            time_width: 34,
            time_gap: 6,
            scrubber_height: 10,
            scrubber_bottom: 4,
            line_height: 4,
            line_color: p.placeholder,
            line_played_color: p.highlight,
            queue_button_width: 26,
            queue_button_height: 24,
            queue_button_inset: 8,
            queue_button_fill: { color: p.overlay(0.07), radius: 4 },
            queue_button_open_fill: { color: p.overlay(0.16), radius: 4 },
            queue_glyph_color: mix(p.text, p.window, 0.25),
            like_gap: 6,
            like_glyph_size: 14,
            // a heart stays red whatever the selection colour is
            liked_glyph_color: "#d0344a",
        },

        // the theme's text field, as a picture if it has one
        search_field: {
            width: 200,
            height: 26,
            fill: textField !== undefined && textField.normal !== undefined
                ? pictureFill(textField.normal, textField.slice)
                : { color: p.base, radius: 13, border: { color: p.rule, width: 1 } },
            glyph_inset: 9,
            glyph_size: 12,
            glyph_color: p.quiet,
            text_color: p.text,
            placeholder_color: p.faint,
            clear_color: p.faint,
            clear_size: 14,
            clear_inset: 6,
            selection_color: p.highlight,
            selection_text_color: p.highlightText,
        },

        // the list of places is the window's body, its chosen row the theme's selected item
        sidebar: {
            width: 200,
            fill: { color: p.window },
            edge_color: p.rule,
            top: 10,
            row_height: 26,
            row_inset: p.selectedIsBar ? 0 : 8,
            text_inset: p.selectedIsBar ? 20 : 12,
            heading_height: 28,
            heading_text_inset: 18,
            heading_drop: 4,
            heading_color: p.quiet,
            text_color: p.text,
            selected_fill: colorFill(p.selectedFill, { radius: p.selectedIsBar ? 0 : 4 }),
            selected_text_color: p.selectedText,
            drop_fill: { color: withAlpha(p.highlight, 0.15), radius: 4, border: { color: p.highlight, width: 2 } },
            drag_ghost_offset: [14, 10],
            drag_ghost_padding: 10,
            drag_ghost_max_width: 260,
        },

        // the songs are a list in the theme's list colours
        song_list: {
            header_height: 24,
            header_fill: { gradient: [mix(p.window, p.base, 0.6), p.window] },
            header_line_color: p.rule,
            header_separator_color: p.hairline,
            header_text_color: mix(p.text, p.window, 0.1),
            row_height: 24,
            row_color: p.base,
            row_alternate_color: mix(p.base, p.text, 0.04),
            text_color: p.text,
            quiet_text_color: p.quiet,
            playing_fill: colorFill(p.selectedFill, { radius: p.selectedIsBar ? 0 : 4 }),
            playing_text_color: p.selectedText,
            playing_quiet_text_color: mix(p.selectedText, middleColor(p.selectedFill), 0.2),
            number_width: 44,
            time_width: 64,
            artist_fraction: 0.26,
            album_fraction: 0.26,
            cell_inset: 8,
            play_glyph_size: 11,
            message_color: p.quiet,
            problem_color: "#b02020",
            like_width: 40,
            like_size: 13,
            liked_color: "#d0344a",
            marked_color: mix(p.highlight, p.base, 0.8),
            drop_line_color: p.highlight,
        },

        queue: {
            width: 340,
            max_height: 420,
            gap: 2,
            arrow_size: 8,
            arrow_color: mix(p.base, p.window, 0.4),
            fill: { color: mix(p.base, p.window, 0.4), radius: 6, border: { color: p.rule, width: 1 } },
            shadow_color: p.dark ? "#00000090" : "#00000050",
            shadow_blur: 12,
            shadow_drop: 3,
            padding: 6,
            header_height: 34,
            title_inset: 16,
            title_color: p.text,
            // a link, so in the selection colour
            clear_color: p.highlight,
            clear_disabled_color: p.faint,
            row_height: 41,
            current_fill: { color: mix(p.highlight, p.base, 0.8), radius: 4 },
            cover_size: 29,
            cover_inset: 8,
            cover_fill: { color: p.placeholder },
            text_inset: 46,
            time_width: 44,
            text_color: p.text,
            quiet_text_color: p.quiet,
            past_text_color: p.faint,
            remove_color: p.quiet,
            remove_size: 14,
            empty_color: p.quiet,
        },

        page_header: {
            height: 124,
            compact_height: 64,
            padding: 16,
            back_width: 24,
            cover_size: 92,
            cover_gap: 18,
            cover_fill: { color: p.placeholder },
            title_color: p.text,
            subtitle_color: mix(p.text, p.base, 0.35),
            summary_color: p.quiet,
            back_color: p.quiet,
            back_hover_color: p.text,
            line_color: p.hairline,
            // renaming selects the title like any selected text
            rename_line_color: p.highlight,
            rename_selected_text_color: p.highlightText,
            button_gap: 8,
        },

        cards: {
            page_padding: 20,
            cover_size: 150,
            spacing_x: 20,
            spacing_y: 14,
            text_gap: 8,
            text_height: 38,
            cover_fill: { color: p.placeholder },
            cover_edge_color: p.overlay(0.15),
            title_color: p.text,
            subtitle_color: p.quiet,
            play_size: 34,
            play_inset: 8,
            // on the cover, so the same on light and dark themes
            play_fill: "#000000b0",
            play_pressed_fill: "#000000e0",
            play_glyph_color: "#ffffff",
            shelf_title_height: 40,
            shelf_title_color: p.text,
            shelf_bottom_gap: 12,
            arrow_color: p.quiet,
            arrow_hover_color: p.text,
        },

        // the theme's tabs, as pictures if it has them, else a pill in the selection colour
        tabs: tabs !== undefined && tabs.selected !== undefined ? {
            height: 40,
            tab_height: pictureHeight(tabs.slice ?? [0, 0, 0, 0]),
            inset: 16,
            spacing: tabs.joined ? 0 : 6,
            padding: 14,
            line_color: p.hairline,
            text_color: p.text,
            fill: pictureFill(tabs.normal, tabs.slice),
            selected_fill: pictureFill(tabs.selected, tabs.slice),
            selected_text_color: tabs.selected_text_color ?? p.text,
            joined: tabs.joined ?? false,
            centered: tabs.centered ?? false,
        } : {
            height: 40,
            tab_height: 24,
            inset: 16,
            spacing: 6,
            padding: 14,
            line_color: p.hairline,
            text_color: mix(p.text, p.base, 0.15),
            selected_fill: { color: p.highlight, radius: 12 },
            selected_text_color: p.highlightText,
        },

        sheet: {
            dim_color: p.dark ? "#00000060" : "#00000040",
            padding: 20,
            radius: 8,
            border_color: p.overlay(0.3),
            shadow_color: "#00000060",
            shadow_blur: 20,
            shadow_drop: 6,
            button_gap_above: 16,
        },

        // the line along the bottom is the window's body again
        status_bar: {
            height: 22,
            fill: { color: p.window },
            line_color: p.rule,
            text_color: p.quiet,
        },
    }
}

// [controls] may add parts to a look that only fit next to its own look of the part.
// a [music] table that draws such a part itself (the first key) keeps it as it was.
const ownLooks = [
    ["top_bar", "fill", ["fill_inactive", "line_color_inactive"]],
    ["top_bar", "volume_knob_color", ["volume_slider"]],
    ["tabs", "selected_fill", ["fill", "joined", "centered"]],
]

// the buttons of the page heads and the question. a theme's own [dialog] is used
// whole, since its buttons and drawn ones would not match; one without gets them
// from [controls.button] or drawn in the palette.
function dialogLook(p, controls, given, fontSize) {
    const look = { background: p.window, text_color: p.text }
    if (given !== undefined) {
        return mergeLooks(look, given)
    }
    const button = controls.button
    const pictures = button !== undefined && button.normal !== undefined
    const picture = name => pictureFill(button[name] ?? button.normal, button.slice)
    return Object.assign(look, {
        button_height: pictures ? button.slice[0] + button.slice[2] + fontSize : 24,
        button_padding: 16,
        button_min_width: 88,
        button_spacing: 8,
        button: pictures ? picture("normal") : { color: p.base, radius: 4, border: { color: p.rule, width: 1 } },
        button_pressed: pictures ? picture("pressed")
            : { color: mix(p.base, p.text, 0.12), radius: 4, border: { color: p.rule, width: 1 } },
        button_default: pictures ? picture("default") : colorFill(p.selectedFill, { radius: 4 }),
        button_default_pressed: pictures ? picture("default_pressed")
            : { color: mix(middleColor(p.selectedFill), "#000000", 0.2), radius: 4 },
        button_default_text_color: pictures ? p.text : p.selectedText,
    })
}

// --- fonts

function sized(font, size, bold) {
    return Object.assign({}, font, { size: size, bold: bold })
}

// the music fonts follow the interface font, in the steps the plain theme takes from its 13 px
function fontsOf(given) {
    const fonts = Object.assign({}, given ?? {})
    const ui = fonts.interface ?? { family: "sans-serif", size: 13 }
    const size = ui.size
    const steps = {
        interface: [size, ui.bold ?? false],
        dialog_text: [size - 1, false],
        music_title: [size - 1, true],
        music_text: [size - 1, false],
        music_small: [size - 2, false],
        music_time: [size - 3, false],
        music_heading: [size - 3, true],
        music_page_title: [Math.round(size * 1.5), true],
    }
    for (const name in steps) {
        if (fonts[name] === undefined) {
            fonts[name] = sized(ui, steps[name][0], steps[name][1])
        }
    }
    return fonts
}

// --- merging

// a fill or a picture is one value, replaced whole; any other table is merged key by key
function isTable(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
        && value.color === undefined && value.gradient === undefined && value.image === undefined
}

function mergeLooks(base, over) {
    const result = {}
    for (const key in base) {
        // parts a theme lacks are written as undefined above; leave them out
        if (base[key] !== undefined) {
            result[key] = isTable(base[key]) ? mergeLooks(base[key], {}) : base[key]
        }
    }
    for (const key in over) {
        result[key] = isTable(result[key]) && isTable(over[key]) ? mergeLooks(result[key], over[key]) : over[key]
    }
    return result
}

// the settings reach qml as qt's own list and map objects, where Array.isArray
// is false; copied into plain arrays and objects, the checks above hold
function plain(value) {
    if (value === null || typeof value !== "object") {
        return value
    }
    if (typeof value.length === "number") {
        return Array.from(value, plain)
    }
    const result = {}
    for (const key in value) {
        result[key] = plain(value[key])
    }
    return result
}

// { music, fonts, dialog } for a theme as the settings carry it
function resolve(theme) {
    const given = plain(theme ?? {})
    const controls = given.controls ?? {}
    const palette = paletteOf(controls)
    const fonts = fontsOf(given.fonts)
    const ownMusic = given.music ?? {}

    const music = mergeLooks(lookFromControls(palette, controls, fonts.interface.size), ownMusic)
    for (const [part, ownKey, added] of ownLooks) {
        if (ownMusic[part]?.[ownKey] !== undefined) {
            for (const key of added) {
                delete music[part][key]
            }
        }
    }

    return {
        music: music,
        fonts: fonts,
        dialog: dialogLook(palette, controls, given.dialog, fonts.interface.size),
    }
}
