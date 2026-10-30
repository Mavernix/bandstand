// the line along the bottom: a short notice if there is one, else a summary of the listed songs

import QtQuick
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues
import "Format.js" as Format

Item {
    id: statusBar

    required property var looks
    required property var fonts
    required property string themeDirectory
    required property var strings
    // the TrackModel of the page shown, or null
    property var songs: null

    property string notice: ""
    readonly property int noticeMs: 8000

    function show(text) {
        notice = text
        if (text !== "") {
            noticeTimer.restart()
        }
    }

    height: looks.height

    Timer {
        id: noticeTimer
        interval: statusBar.noticeMs
        onTriggered: statusBar.notice = ""
    }

    Shell.Fill {
        anchors.fill: parent
        themeDirectory: statusBar.themeDirectory
        // like the top bar, paler while the window is in the background (if the theme says how)
        fill: !Window.active ? (statusBar.looks.fill_inactive ?? statusBar.looks.fill) : statusBar.looks.fill
    }
    Rectangle {
        width: parent.width
        height: 1
        color: ThemeValues.color(statusBar.looks.line_color)
    }
    Text {
        anchors.centerIn: parent
        width: parent.width - 2 * statusBar.height
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: statusBar.notice !== "" ? statusBar.notice
            : statusBar.songs !== null && statusBar.songs.count > 0
            ? Format.listSummary(statusBar.songs.count, statusBar.songs.totalSeconds, statusBar.strings) : ""
        color: ThemeValues.color(statusBar.looks.text_color)
        font.family: statusBar.fonts.music_small.family
        font.pixelSize: statusBar.fonts.music_small.size
    }
}
