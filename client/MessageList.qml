import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient

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
            id: avatarCircle
            width: 32
            height: 32
            radius: 16
            color: Theme.hoverSubtle
            border.color: Theme.border
            visible: !delegateRoot.isOutgoing
            
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.bottom: bubble.bottom

            Text {
                anchors.centerIn: parent
                text: root.senderName(modelData.sender_id) ? root.senderName(modelData.sender_id).charAt(0).toUpperCase() : "?"
                font.pixelSize: 14
                font.bold: true
                color: Theme.textMuted
            }
        }

        Rectangle {
            id: bubble
            radius: 10
            color: delegateRoot.isOutgoing ? Theme.bubbleOut : Theme.bubbleIn
            border.color: delegateRoot.isOutgoing ? Theme.bubbleOutBorder : Theme.bubbleInBorder

            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.right: delegateRoot.isOutgoing ? parent.right : undefined
            anchors.rightMargin: 4
            anchors.left: delegateRoot.isOutgoing ? undefined : avatarCircle.right
            anchors.leftMargin: 8

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
                    color: Theme.textBody
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
                    color: delegateRoot.isOutgoing ? Theme.bubbleOutText : Theme.textPrimary
                    width: parent.width
                }

                Text {
                    id: timeText
                    text: root.formatSentAt(modelData.sent_at)
                    color: Theme.textMuted
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
                    color: Theme.bgSecondary
                    border.color: Theme.border
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
                        color: Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: 12
                        color: editMessageItem.hovered ? Theme.hover : "transparent"
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
                        color: Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: 12
                        color: deleteMessageItem.hovered ? Theme.hover : "transparent"
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
