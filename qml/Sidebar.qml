// the sidebar. its entries come from config.music.sidebar:
//   { heading = "Music" }
//   { label = "Search", page = "search" }
//   { heading = "Playlists", playlists = true }   heading with a "+", the user's playlists below

import QtQuick
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: sidebar

    required property var looks
    required property var fonts
    required property string themeDirectory

    property var entries: []
    // library.playlists (roles id, name, count)
    property var playlists: null
    property string currentPage: ""

    // highlighted while a song is dragged over it: a playlist id, "new" (the playlists
    // heading), "liked", or "" for nothing. set from SongDrag.
    property string dropTarget: ""

    // hit-tests by hand because the song drag is a plain MouseArea drag, not a Drag/DropArea one
    function dropTargetAt(x, y) {
        for (let index = 0; index < groups.count; index++) {
            const group = groups.itemAt(index)
            if (group === null) {
                continue
            }
            const place = group.mapFromItem(sidebar, x, y)
            if (place.x < 0 || place.x > group.width || place.y < 0 || place.y >= group.height) {
                continue
            }
            if (group.modelData.page === "liked") {
                return "liked"
            }
            if (!group.listsPlaylists) {
                continue
            }
            if (place.y < looks.heading_height) {
                return "new"
            }
            const row = Math.floor((place.y - looks.heading_height) / looks.row_height)
            const line = group.playlistRows.itemAt(row)
            return line !== null ? line.playlistId : ""
        }
        return ""
    }

    signal pageChosen(string page)
    signal newPlaylistRequested()
    signal playlistMenuRequested(string id, real x, real y)

    Shell.Fill {
        anchors.fill: parent
        themeDirectory: sidebar.themeDirectory
        fill: sidebar.looks.fill
    }
    // edge between the sidebar and the page
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: ThemeValues.color(sidebar.looks.edge_color)
    }

    FontMetrics {
        id: headingMetrics
        font.family: sidebar.fonts.music_heading.family
        font.pixelSize: sidebar.fonts.music_heading.size
    }

    component HeadingLine: Item {
        id: heading
        property string label: ""
        property bool hasAddButton: false
        property bool isDropTarget: false
        signal addPressed()

        width: parent.width
        height: sidebar.looks.heading_height

        Shell.Fill {
            visible: heading.isDropTarget
            x: sidebar.looks.row_inset
            width: parent.width - 2 * sidebar.looks.row_inset
            height: parent.height
            themeDirectory: sidebar.themeDirectory
            fill: sidebar.looks.drop_fill
        }
        Text {
            x: sidebar.looks.heading_text_inset
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: sidebar.looks.heading_drop
            text: heading.label
            color: ThemeValues.color(sidebar.looks.heading_color)
            font.family: sidebar.fonts.music_heading.family
            font.pixelSize: sidebar.fonts.music_heading.size
            font.bold: sidebar.fonts.music_heading.bold ?? false
        }
        Text {
            visible: heading.hasAddButton
            x: heading.width - width - sidebar.looks.heading_text_inset
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: sidebar.looks.heading_drop
            text: "+"
            color: ThemeValues.color(addArea.containsMouse ? sidebar.looks.text_color : sidebar.looks.heading_color)
            font.family: sidebar.fonts.music_heading.family
            // a plus somewhat taller than the heading's line, so it reads as a button
            font.pixelSize: Math.round(headingMetrics.height * 1.4)

            MouseArea {
                id: addArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                onClicked: heading.addPressed()
            }
        }
    }

    component PlaceLine: Item {
        id: place
        property string label: ""
        property bool isChosen: false
        property bool isDropTarget: false
        signal chosen()
        signal menuRequested(real x, real y)

        width: parent.width
        height: sidebar.looks.row_height

        Shell.Fill {
            visible: place.isChosen
            x: sidebar.looks.row_inset
            width: parent.width - 2 * sidebar.looks.row_inset
            height: parent.height
            themeDirectory: sidebar.themeDirectory
            fill: sidebar.looks.selected_fill
        }
        Shell.Fill {
            visible: place.isDropTarget
            x: sidebar.looks.row_inset
            width: parent.width - 2 * sidebar.looks.row_inset
            height: parent.height
            themeDirectory: sidebar.themeDirectory
            fill: sidebar.looks.drop_fill
        }
        Text {
            x: sidebar.looks.row_inset + sidebar.looks.text_inset
            width: parent.width - x - sidebar.looks.row_inset - sidebar.looks.text_inset
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: place.label
            color: ThemeValues.color(place.isChosen ? sidebar.looks.selected_text_color : sidebar.looks.text_color)
            font.family: sidebar.fonts.music_text.family
            font.pixelSize: sidebar.fonts.music_text.size
            font.bold: place.isChosen
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    place.menuRequested(mouse.x, mouse.y)
                } else {
                    place.chosen()
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.rightMargin: 1
        contentHeight: list.y + list.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            y: sidebar.looks.top
            width: parent.width

            Repeater {
                id: groups
                model: sidebar.entries

                // one config entry, plus the playlist rows if it's the playlists heading
                Column {
                    id: group
                    // for dropTargetAt()
                    property alias playlistRows: playlistRepeater
                    required property var modelData
                    readonly property bool isHeading: modelData.heading !== undefined
                    readonly property bool listsPlaylists: modelData.playlists === true

                    width: list.width

                    HeadingLine {
                        visible: group.isHeading
                        label: group.modelData.heading ?? ""
                        hasAddButton: group.listsPlaylists
                        isDropTarget: group.listsPlaylists && sidebar.dropTarget === "new"
                        onAddPressed: sidebar.newPlaylistRequested()
                    }
                    PlaceLine {
                        visible: !group.isHeading
                        label: group.modelData.label ?? ""
                        isChosen: !group.isHeading && group.modelData.page === sidebar.currentPage
                        isDropTarget: !group.isHeading && group.modelData.page === "liked" && sidebar.dropTarget === "liked"
                        onChosen: sidebar.pageChosen(group.modelData.page)
                    }

                    Repeater {
                        id: playlistRepeater
                        model: group.listsPlaylists ? sidebar.playlists : null

                        PlaceLine {
                            id: playlistLine
                            // the model has an `id` role, so roles are read through `model.`
                            readonly property string playlistId: model.id
                            label: model.name
                            isChosen: ("mine:" + playlistId) === sidebar.currentPage
                            isDropTarget: playlistId === sidebar.dropTarget
                            onChosen: sidebar.pageChosen("mine:" + playlistId)
                            onMenuRequested: (x, y) => {
                                const place = mapToItem(sidebar, x, y)
                                sidebar.playlistMenuRequested(playlistId, place.x, place.y)
                            }
                        }
                    }
                }
            }
        }
    }
}
