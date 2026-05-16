import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: root

    property var messagesModel: []
    property int currentUserId: -1
    property var userNamesById: ({})
    signal deleteMessageRequested(int messageId)

    signal editMessageRequested(int messageId, string content)

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 10
    model: root.messagesModel

    function scrollToLatest() {
        if (count > 0) {
            positionViewAtEnd()
        }
    }

    onCountChanged: scrollToLatest()
    onModelChanged: scrollToLatest()

    function formatSentAt(value) {
        if (!value) {
            return ""
        }
        const text = String(value)
        const match = /^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}:\d{2}:\d{2})$/.exec(text)
        if (!match) {
            return text
        }
        const day = match[1]
        const month = match[2]
        const year = match[3]
        const time = match[4]
        return time + " " + day + "." + month + "." + year
    }

    delegate: Rectangle {
        required property var modelData

        width: root.width
        height: bubble.implicitHeight + 10
        radius: 0
        color: "transparent"
        border.width: 0

        readonly property bool isOutgoing: modelData.sender_id === root.currentUserId

        Rectangle {
            id: bubble

            radius: 10
            color: parent.isOutgoing ? "#dbeafe" : "#f3f4f6"
            border.color: "#e5e7eb"

            anchors.top: parent.top
            anchors.margins: 4
            anchors.right: parent.isOutgoing ? parent.right : undefined
            anchors.left: parent.isOutgoing ? undefined : parent.left

            implicitWidth: Math.min(parent.width * 0.78, Math.max(messageText.implicitWidth, timeText.implicitWidth) + 24)
            implicitHeight: messageColumn.implicitHeight + 16

            Column {
                id: messageColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text {
                    id: messageText
                    text: modelData.content
                    wrapMode: Text.Wrap
                    color: "#111827"
                    width: parent.width
                }

                Text {
                    id: timeText
                    text: root.formatSentAt(modelData.sent_at)
                    color: "#6b7280"
                    font.pixelSize: 12
                    horizontalAlignment: parent.isOutgoing ? Text.AlignRight : Text.AlignLeft
                    width: parent.width
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }

            Menu {
                id: messageActionsMenu
                MenuItem {
                    text: "Изменить"
                    onTriggered: root.editMessageRequested(modelData.message_id, modelData.content)
                }

                MenuItem {
                    text: "Удалить"
                    onTriggered: root.deleteMessageRequested(modelData.message_id)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (!parent.parent.isOutgoing || mouse.button !== Qt.RightButton) {
                        return
                    }
                    messageActionsMenu.popup()
                }
            }
        }
    }
}
