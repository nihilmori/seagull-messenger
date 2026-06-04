import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient
import "ApiClient.js" as WebApi

Rectangle {
    id: root

    property int currentChatId: -1
    property int currentUserId: -1
    property int editingMessageId: -1
    property string errorText: ""
    property string statusText: ""

    property string receiverText: ""
    property alias messageText: messageField.text

    property bool _typingActive: false

    signal sendClicked()
    signal cancelEditClicked()

    function _sendTyping(isTyping) {
        if (currentChatId <= 0 || currentUserId <= 0) {
            return
        }
        WebApi.ApiClient.setTyping(currentChatId, currentUserId, isTyping, function() {})
    }

    function _stopTyping() {
        typingHeartbeat.stop()
        typingIdle.stop()
        if (_typingActive) {
            _typingActive = false
            _sendTyping(false)
        }
    }

    function _handleTextChanged(text) {
        if (currentChatId <= 0 || currentUserId <= 0) {
            return
        }
        if (text && text.length > 0) {
            if (!_typingActive) {
                _typingActive = true
                _sendTyping(true)
                typingHeartbeat.start()
            }
            typingIdle.restart()
        } else {
            _stopTyping()
        }
    }

    function notifyMessageSent() {
        _typingActive = false
        typingHeartbeat.stop()
        typingIdle.stop()
    }

    onCurrentChatIdChanged: _stopTyping()

    Timer {
        id: typingHeartbeat
        interval: 3000
        repeat: true
        onTriggered: {
            if (_typingActive && currentChatId > 0 && currentUserId > 0) {
                _sendTyping(true)
            } else {
                stop()
            }
        }
    }

    Timer {
        id: typingIdle
        interval: 4000
        repeat: false
        onTriggered: _stopTyping()
    }

    Layout.fillWidth: true
    implicitHeight: composerContent.implicitHeight + 24
    Layout.minimumHeight: implicitHeight
    radius: 10
    color: Theme.bgSecondary
    border.color: Theme.border

    ColumnLayout {
        id: composerContent
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                id: emojiButton
                text: "😊"
                padding: 6
                implicitWidth: 40
                implicitHeight: 40
                background: Rectangle {
                    radius: 12
                    color: emojiButton.hovered ? Theme.hover : Theme.hoverSubtle
                    border.color: Theme.border
                }
                contentItem: Text {
                    text: emojiButton.text
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: emojiPicker.opened ? emojiPicker.close() : emojiPicker.open()
            }

            TextField {
                id: messageField
                placeholderText: root.editingMessageId > 0
                                 ? "Редактирование сообщения"
                                 : (root.currentChatId > 0 ? "Введите сообщение в чат" : "Введите сообщение для личного чата")
                Layout.fillWidth: true
                padding: 10
                color: Theme.textPrimary
                placeholderTextColor: Theme.textFaint
                background: Rectangle {
                    radius: 12
                    color: Theme.inputBg
                    border.color: Theme.border
                }
                onTextChanged: root._handleTextChanged(text)
                onAccepted: root.sendClicked()
            }

            Button {
                id: sendButton
                text: root.editingMessageId > 0 ? "✓" : "➤"
                padding: 6
                implicitWidth: 40
                implicitHeight: 40
                background: Rectangle {
                    radius: 12
                    color: sendButton.hovered ? Theme.bubbleOutBorder : Theme.bubbleOut
                    border.color: Theme.bubbleOutBorder
                }
                contentItem: Text {
                    text: sendButton.text
                    font.pixelSize: 20
                    font.bold: true
                    color: Theme.bubbleOutText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.sendClicked()
            }

            Button {
                id: cancelButton
                text: "✕"
                visible: root.editingMessageId > 0
                padding: 6
                implicitWidth: 40
                implicitHeight: 40
                background: Rectangle {
                    radius: 12
                    color: cancelButton.hovered ? Theme.hover : Theme.hoverSubtle
                    border.color: Theme.border
                }
                contentItem: Text {
                    text: cancelButton.text
                    font.pixelSize: 18
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.cancelEditClicked()
            }
        }

        EmojiPicker {
            id: emojiPicker
            x: 0
            y: -height - 6
            onEmojiSelected: function(emoji) {
                messageField.text = messageField.text + emoji
                messageField.forceActiveFocus()
                messageField.cursorPosition = messageField.text.length
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.errorText
                color: Theme.error
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Text {
                text: root.statusText
                color: Theme.success
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.Wrap
            }
        }
    }
}
