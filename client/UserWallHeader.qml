import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string userName: ""
    property string userLogin: ""
    property string userBio: ""
    property string avatarUrl: ""
    property int postsCount: 0
    property bool isOwnProfile: false

    signal editProfileClicked()
    signal writeMessageClicked()

    Layout.fillWidth: true
    height: 140
    radius: 12
    color: "#ffffff"
    border.color: "#e5e7eb"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Rectangle {
            width: 70
            height: 70
            radius: 35
            color: "#f3f4f6"
            border.color: "#e5e7eb"

            Text {
                anchors.centerIn: parent
                text: root.userName ? root.userName.charAt(0).toUpperCase() : "?"
                font.pixelSize: 28
                font.bold: true
                color: "#6b7280"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                Text {
                    text: root.userName
                    font.pixelSize: 20
                    font.bold: true
                    color: "#111827"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "@" + root.userLogin
                    font.pixelSize: 13
                    color: "#6b7280"
                    visible: root.userLogin !== ""
                }
            }

            Text {
                text: root.userBio || "Нет описания"
                font.pixelSize: 13
                color: "#374151"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            Text {
                text: root.postsCount + " " + (root.postsCount === 1 ? "пост" : "постов")
                font.pixelSize: 12
                color: "#6b7280"
            }
        }

        Button {
            visible: root.isOwnProfile
            text: "Редактировать"
            implicitWidth: 110
            padding: 8
            background: Rectangle {
                radius: 20
                color: "#f3f4f6"
                border.color: "#e5e7eb"
            }
            contentItem: Text {
                text: parent.text
                color: "#374151"
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: root.editProfileClicked()
        }

        Button {
            visible: !root.isOwnProfile
            text: "Написать"
            implicitWidth: 110
            padding: 8
            background: Rectangle {
                radius: 20
                color: "#dbeafe"
                border.color: "#93c5fd"
            }
            contentItem: Text {
                text: parent.text
                color: "#1f2937"
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: root.writeMessageClicked()
        }
    }
}