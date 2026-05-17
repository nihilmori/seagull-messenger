import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: wallScreen

    property int userId: 0
    property int currentUserId: 0
    property string userName: ""

    signal backClicked()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "#ffffff"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Button {
                    width: 40
                    height: 40
                    background: Rectangle {
                        color: parent.pressed ? "#f0f0f0" : "transparent"
                        radius: 20
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        font.pixelSize: 24
                    }

                    onClicked: backClicked()
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: userName || "Стена пользователя"
                        font.bold: true
                        font.pixelSize: 18
                    }

                    Text {
                        text: userId === currentUserId ? "Моя стена" : "Стена пользователя"
                        color: "#999999"
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#e5e7eb"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#ffffff"
            visible: userId !== currentUserId && userId > 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    text: "+ Написать на стене"

                    background: Rectangle {
                        color: parent.pressed ? "#e8f5e9" : "#f5f5f5"
                        radius: 18
                        border.color: "#e0e0e0"
                        border.width: 1
                    }

                    onClicked: postComposer.visible = true
                }
            }
        }

        WallPostComposer {
            id: postComposer
            Layout.fillWidth: true
            authorId: currentUserId
            wallOwnerId: userId
            onPostCreated: wallPostList.refresh()
        }

        WallPostList {
            id: wallPostList
            userId: wallScreen.userId
            currentUserId: wallScreen.currentUserId
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
