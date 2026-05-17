import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var chatsModel: []
    property var searchUsersModel: []
    property int currentChatId: -1

    property alias searchText: userSearchField.text

    signal refreshChatsClicked()
    signal chatSelected(int chatId)
    signal userSelected(int userId, string name)
    signal wallRequested(int userId, string name)

    width: 340
    color: "#ffffff"
    border.color: "#e5e7eb"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        TextField {
            id: userSearchField
            placeholderText: "Поиск пользователей"
            Layout.fillWidth: true
        }

        Button {
            text: "Обновить чаты"
            Layout.fillWidth: true
            onClicked: root.refreshChatsClicked()
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
                color: root.currentChatId === modelData.chat_id ? "#dbeafe" : "#f9fafb"
                border.color: "#e5e7eb"

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        width: parent.width

                        Text {
                            text: modelData.display_name || modelData.name || ("Чат #" + modelData.chat_id)
                            color: "#111827"
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: modelData.unread_count > 0
                            radius: 9
                            color: "#2563eb"
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
                        color: "#6b7280"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chatSelected(modelData.chat_id)
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
                color: "#111827"
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
                    color: "#f8fafc"
                    border.color: "#e5e7eb"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text {
                            text: modelData.name + " (" + modelData.user_id + ")"
                            color: "#111827"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.userSelected(modelData.user_id, modelData.name)
                    }
                }
            }
        }
    }
}
