import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ApiClient.js" as WebApi

Rectangle {
    id: root

    property int currentChatId: -1
    property int currentUserId: -1
    property int editingMessageId: -1
    property string errorText: ""
    property string statusText: ""

    property alias receiverText: privateReceiverField.text
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
    color: "#ffffff"
    border.color: "#e5e7eb"

    ColumnLayout {
        id: composerContent
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: privateReceiverField
                placeholderText: "user_id для личного чата"
                visible: root.currentChatId <= 0 && root.editingMessageId <= 0
                Layout.preferredWidth: 200
                padding: 10
                background: Rectangle {
                    radius: 12
                    color: "#f9fafb"
                    border.color: "#e5e7eb"
                }
            }

            TextField {
                id: messageField
                placeholderText: root.editingMessageId > 0
                                 ? "Редактирование сообщения"
                                 : (root.currentChatId > 0 ? "Введите сообщение в чат" : "Введите сообщение для личного чата")
                Layout.fillWidth: true
                padding: 10
                background: Rectangle {
                    radius: 12
                    color: "#f9fafb"
                    border.color: "#e5e7eb"
                }
                onTextChanged: root._handleTextChanged(text)
                onAccepted: root.sendClicked()
            }

            Button {
                text: root.editingMessageId > 0 ? "Сохранить" : "Отправить"
                padding: 10
                background: Rectangle {
                    radius: 12
                    color: "#dbeafe"
                    border.color: "#93c5fd"
                }
                onClicked: root.sendClicked()
            }

            Button {
                text: "Отмена"
                visible: root.editingMessageId > 0
                padding: 10
                background: Rectangle {
                    radius: 12
                    color: "#f3f4f6"
                    border.color: "#e5e7eb"
                }
                onClicked: root.cancelEditClicked()
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.errorText
                color: "#dc2626"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Text {
                text: root.statusText
                color: "#059669"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.Wrap
            }
        }
    }
}
