import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient

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
    color: Theme.bgSecondary
    border.color: Theme.border

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Rectangle {
            width: 70
            height: 70
            radius: 35
            color: Theme.hoverSubtle
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: root.userName ? root.userName.charAt(0).toUpperCase() : "?"
                font.pixelSize: 28
                font.bold: true
                color: Theme.textMuted
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
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "@" + root.userLogin
                    font.pixelSize: 13
                    color: Theme.textMuted
                    visible: root.userLogin !== ""
                }
            }

            Text {
                text: root.userBio || "Нет описания"
                font.pixelSize: 13
                color: Theme.textBody
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            Text {
                text: root.postsCount + " " + (root.postsCount === 1 ? "пост" : "постов")
                font.pixelSize: 12
                color: Theme.textMuted
            }
        }

        Button {
            visible: root.isOwnProfile
            text: "Редактировать"
            implicitWidth: 110
            padding: 8
            background: Rectangle {
                radius: 20
                color: Theme.hoverSubtle
                border.color: Theme.border
            }
            contentItem: Text {
                text: parent.text
                color: Theme.textBody
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
                color: Theme.bubbleOut
                border.color: Theme.bubbleOutBorder
            }
            contentItem: Text {
                text: parent.text
                color: Theme.bubbleOutText
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: root.writeMessageClicked()
        }
    }
}
