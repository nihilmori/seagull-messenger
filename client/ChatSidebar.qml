import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient

Rectangle {
    id: root

    property var chatsModel: []
    property var searchUsersModel: []
    property int currentChatId: -1
    property alias searchText: userSearchField.text

    signal refreshChatsClicked()
    signal chatSelected(int chatId)
    signal userSelected(int userId, string name)

    width: 340
    color: Theme.bgSecondary
    border.color: Theme.border

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        TextField {
            id: userSearchField
            placeholderText: "Поиск пользователей"
            Layout.fillWidth: true
            padding: 10
            color: Theme.textPrimary
            placeholderTextColor: Theme.textFaint
            background: Rectangle {
                radius: 12
                color: Theme.inputBg
                border.color: Theme.border
            }
        }

        ListView {
            id: chatsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.chatsModel
            spacing: 8

            delegate: Rectangle {
                required property var modelData

                width: chatsList.width
                height: 64
                radius: 10
                color: root.currentChatId === modelData.chat_id ? Theme.bubbleOut : Theme.inputBg
                border.color: Theme.border

                property int peerUserId: modelData.peer_user_id || 0

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        width: parent.width

                        Text {
                            text: modelData.display_name || modelData.name || ("Чат #" + modelData.chat_id)
                            color: Theme.textPrimary
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: modelData.unread_count > 0
                            radius: 9
                            color: Theme.accent
                            Layout.minimumWidth: 18
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: modelData.unread_count
                                color: "#ffffff"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Text {
                        text: modelData.last_message_at || "Нет сообщений"
                        color: Theme.textMuted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            root.chatSelected(modelData.chat_id)
                        }
                    }
                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            if (peerUserId > 0) {
                                chatContextMenu.peerUserId = peerUserId
                                chatContextMenu.peerName = modelData.display_name || modelData.name
                                chatContextMenu.popup()
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: userSearchField.text.length > 0

            Text {
                text: "Результаты поиска пользователей"
                font.bold: true
                color: Theme.textPrimary
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                clip: true
                model: root.searchUsersModel

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 38
                    radius: 8
                    color: Theme.inputBg
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text {
                            text: modelData.name + " (" + modelData.user_id + ")"
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                root.userSelected(modelData.user_id, modelData.name)
                            }
                        }
                        onPressed: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                searchContextMenu.userId = modelData.user_id
                                searchContextMenu.userName = modelData.name
                                searchContextMenu.popup()
                            }
                        }
                    }
                }
            }
        }
    }

    Menu {
        id: searchContextMenu
        property int userId: -1
        property string userName: ""

        implicitWidth: 225
        padding: 6
        background: Rectangle {
            radius: 12
            color: Theme.bgSecondary
            border.color: Theme.border
        }

        MenuItem {
            text: "Открыть стену пользователя"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: parent.text
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onTriggered: {
                if (searchContextMenu.userId > 0) {
                    window.openUserWall(searchContextMenu.userId)
                }
            }
            background: Rectangle {
                color: parent.hovered ? "#f3f4f6" : "transparent"
                radius: 8
            }
        }
    }

    Menu {
        id: chatContextMenu
        property int peerUserId: -1
        property string peerName: ""

        implicitWidth: 220
        padding: 6
        background: Rectangle {
            radius: 12
            color: Theme.bgSecondary
            border.color: Theme.border
        }

        MenuItem {
            text: "Открыть стену собеседника"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: parent.text
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            onTriggered: {
                if (chatContextMenu.peerUserId > 0) {
                    window.openUserWall(chatContextMenu.peerUserId)
                }
            }
            background: Rectangle {
                color: parent.hovered ? "#f3f4f6" : "transparent"
                radius: 8
            }
        }
    }
}
