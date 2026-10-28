// a row of tabs, used by the search page

import QtQuick
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: tabs

    required property var looks
    required property var fonts
    required property string themeDirectory

    // [{ id, label }]
    property var entries: []
    property string current: ""

    signal chosen(string id)

    height: looks.height

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: ThemeValues.color(tabs.looks.line_color)
    }

    // tabs drawn from the theme's pictures may be joined into one control: then only the
    // row's two ends show the pictures' rounded end strips (fill.slice), the rest are cut off
    readonly property bool joined: looks.joined ?? false
    readonly property var endStrips: looks.fill?.slice ?? [0, 0, 0, 0]

    Row {
        id: row
        x: tabs.looks.centered ? (tabs.width - width) / 2 : tabs.looks.inset
        anchors.verticalCenter: parent.verticalCenter
        spacing: tabs.looks.spacing

        Repeater {
            model: tabs.entries

            Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool isChosen: modelData.id === tabs.current
                readonly property bool cutLeft: tabs.joined && index > 0
                readonly property bool cutRight: tabs.joined && index < tabs.entries.length - 1

                width: label.implicitWidth + 2 * tabs.looks.padding
                height: tabs.looks.tab_height
                clip: tabs.joined

                Shell.Fill {
                    x: tab.cutLeft ? -tabs.endStrips[3] : 0
                    width: tab.width - x + (tab.cutRight ? tabs.endStrips[1] : 0)
                    height: tab.height
                    // a theme may draw the tabs that are not chosen too
                    visible: tab.isChosen || tabs.looks.fill !== undefined
                    themeDirectory: tabs.themeDirectory
                    fill: tab.isChosen ? tabs.looks.selected_fill : (tabs.looks.fill ?? ({}))
                }
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tab.modelData.label
                    color: ThemeValues.color(tab.isChosen ? tabs.looks.selected_text_color : tabs.looks.text_color)
                    font.family: tabs.fonts.music_text.family
                    font.pixelSize: tabs.fonts.music_text.size
                    font.bold: tab.isChosen
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: tabs.chosen(tab.modelData.id)
                }
            }
        }
    }
}
