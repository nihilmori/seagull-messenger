import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: root

    property var messagesModel: []
    property int currentUserId: -1
    property var userNamesById: ({})
    property var participantsModel: []
    property string currentChatType: ""

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

    function senderName(senderId) {
        if (senderId === undefined || senderId === null) {
            return ""
        }
        const id = Number(senderId)
        const list = root.participantsModel || []
        for (let i = 0; i < list.length; i++) {
            const participant = list[i]
            if (participant && Number(participant.user_id) === id) {
                return participant.name || ""
            }
        }
        return root.userNamesById[id]
            || root.userNamesById[String(senderId)]
            || ""
    }

    delegate: Rectangle {
        id: delegateRoot
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
            color: delegateRoot.isOutgoing ? "#dbeafe" : "#f3f4f6"
            border.color: "#e5e7eb"

            anchors.top: parent.top
            anchors.margins: 4
            anchors.right: delegateRoot.isOutgoing ? parent.right : undefined
            anchors.left: delegateRoot.isOutgoing ? undefined : parent.left

            implicitWidth: Math.min(parent.width * 0.78, Math.max(messageText.implicitWidth, timeText.implicitWidth) + 24)
            implicitHeight: messageColumn.implicitHeight + 16

            Column {
                id: messageColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text {
                    id: senderNameText
                    text: root.senderName(modelData.sender_id)
                    color: "#374151"
                    font.pixelSize: 12
                    font.bold: true
                    visible: !delegateRoot.isOutgoing
                        && root.currentChatType.toLowerCase() === "group"
                        && Boolean(root.senderName(modelData.sender_id))
                    elide: Text.ElideRight
                    width: parent.width
                }

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
                    horizontalAlignment: delegateRoot.isOutgoing ? Text.AlignRight : Text.AlignLeft
                    width: parent.width
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }

            Menu {
                id: messageActionsMenu
                implicitWidth: 200
                padding: 6
                clip: true
                background: Rectangle {
                    radius: 12
                    color: "#ffffff"
                    border.color: "#e5e7eb"
                }
                MenuItem {
                    id: editMessageItem
                    text: "Изменить"
                    implicitHeight: 32
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 6
                    bottomPadding: 6
                    contentItem: Text {
                        text: editMessageItem.text
                        color: "#111827"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: 12
                        color: editMessageItem.hovered ? "#e5e7eb" : "transparent"
                    }
                    onTriggered: root.editMessageRequested(modelData.message_id, modelData.content)
                }

                MenuItem {
                    id: deleteMessageItem
                    text: "Удалить"
                    implicitHeight: 32
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 6
                    bottomPadding: 6
                    contentItem: Text {
                        text: deleteMessageItem.text
                        color: "#111827"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: 12
                        color: deleteMessageItem.hovered ? "#e5e7eb" : "transparent"
                    }
                    onTriggered: root.deleteMessageRequested(modelData.message_id)
                }
            }

            MouseArea {
                id: bubbleMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (!delegateRoot.isOutgoing || mouse.button !== Qt.RightButton) {
                        return
                    }
                    messageActionsMenu.popup()
                }
            }
        }
    }
}
