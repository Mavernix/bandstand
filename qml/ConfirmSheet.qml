// a confirm dialog over a dimmed window. Return agrees, Escape cancels.

import QtQuick
import QtQuick.Effects
import "shell" as Shell
import "shell/ThemeValues.js" as ThemeValues

Item {
    id: sheet

    required property var looks
    // the dialog look (theme.dialog, or one from [controls]), for the buttons and the box colours
    required property var buttonLooks
    required property var fonts
    required property string themeDirectory

    // { text, button, cancel } while asking, else null
    property var request: null

    signal agreed()
    signal cancelled()

    function ask(question) {
        request = question
    }
    function agree() {
        if (request !== null) {
            request = null
            agreed()
        }
    }
    function cancel() {
        if (request !== null) {
            request = null
            cancelled()
        }
    }

    anchors.fill: parent
    visible: request !== null

    // dim the window and swallow clicks
    Rectangle {
        anchors.fill: parent
        color: ThemeValues.color(sheet.looks.dim_color)
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Item {
        id: box
        anchors.centerIn: parent
        width: Math.min(sheet.buttonLooks.width ?? 420, sheet.width - 2 * sheet.looks.padding)
        height: sheet.looks.padding + message.height + sheet.looks.button_gap_above + buttons.height + sheet.looks.padding

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: ThemeValues.color(sheet.looks.shadow_color)
            shadowBlur: Math.min(1, sheet.looks.shadow_blur / 32)
            shadowVerticalOffset: sheet.looks.shadow_drop
        }

        Rectangle {
            anchors.fill: parent
            radius: sheet.looks.radius
            color: ThemeValues.color(sheet.buttonLooks.background)
            border.width: 1
            border.color: ThemeValues.color(sheet.looks.border_color)
        }
        MouseArea {
            anchors.fill: parent
        }

        Text {
            id: message
            x: sheet.looks.padding
            y: sheet.looks.padding
            width: box.width - 2 * sheet.looks.padding
            wrapMode: Text.WordWrap
            text: sheet.request?.text ?? ""
            color: ThemeValues.color(sheet.buttonLooks.text_color)
            font.family: sheet.fonts.dialog_text.family
            font.pixelSize: sheet.fonts.dialog_text.size
        }

        Row {
            id: buttons
            x: box.width - width - sheet.looks.padding
            y: message.y + message.height + sheet.looks.button_gap_above
            spacing: sheet.buttonLooks.button_spacing ?? 8

            // both buttons as wide as the wider one
            readonly property real buttonWidth: Math.max(cancelButton.wantedWidth, agreeButton.wantedWidth)

            Shell.PushButton {
                id: cancelButton
                looks: sheet.buttonLooks
                fonts: sheet.fonts
                themeDirectory: sheet.themeDirectory
                text: sheet.request?.cancel ?? ""
                width: buttons.buttonWidth
                onClicked: sheet.cancel()
            }
            Shell.PushButton {
                id: agreeButton
                looks: sheet.buttonLooks
                fonts: sheet.fonts
                themeDirectory: sheet.themeDirectory
                text: sheet.request?.button ?? ""
                isDefault: true
                width: buttons.buttonWidth
                onClicked: sheet.agree()
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: sheet.visible
        onActivated: sheet.cancel()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: sheet.visible
        onActivated: sheet.agree()
    }
}
