// what an empty list says: busy, the error, or a hint

import QtQuick
import "shell/ThemeValues.js" as ThemeValues

Text {
    id: message

    required property var looks
    required property var fonts

    property bool busy: false
    property string busyText: ""
    property string problem: ""
    property string emptyText: ""

    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: busy ? busyText : (problem !== "" ? problem : emptyText)
    color: ThemeValues.color(problem !== "" && !busy ? looks.problem_color : looks.message_color)
    font.family: fonts.music_text.family
    font.pixelSize: fonts.music_text.size
}
