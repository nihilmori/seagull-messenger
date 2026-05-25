import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string titleText: ""
    property string subtitleText: ""
    property bool showMenu: false
    property int peerUserId: 0

    signal renameChatClicked()
    signal addUserClicked()
    signal removeUserClicked()
    signal leaveChatClicked()
    signal titleClicked()
    signal openUserWall()

    Layout.fillWidth: true
    height: 72
    radius: 10
    color: "#ffffff"
    border.color: "#e5e7eb"
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                Text {
                    id: titleLabel
                    anchors.fill: parent
                    text: root.titleText
                    font.pixelSize: 18
                    font.bold: true
                    color: "#111827"
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.peerUserId > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.peerUserId > 0 ? root.openUserWall() : root.titleClicked()
                }
            }

            Button {
                id: chatMenuButton
                visible: root.showMenu

                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.fillHeight: false
                Layout.alignment: Qt.AlignVCenter

                padding: 0
                flat: true

                background: Rectangle {
                    color: chatMenuButton.hovered ? "#f3f4f6" : "transparent"
                    radius: 16
                }
                contentItem: Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: 3
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: "#111827"
                            }
                        }
                    }
                }
                onClicked: chatMenu.popup(chatMenuButton)
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.subtitleText
            color: "#6b7280"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Menu {
        id: chatMenu
        implicitWidth: 240
        padding: 6
        clip: true
        background: Rectangle {
            radius: 12
            color: "#ffffff"
            border.color: "#e5e7eb"
        }

        MenuItem { text: "Переименовать чат"; onTriggered: root.renameChatClicked() }
        MenuItem { text: "Добавить участника"; onTriggered: root.addUserClicked() }
        MenuItem { text: "Удалить участника"; onTriggered: root.removeUserClicked() }
        MenuItem { text: "Выйти из чата"; onTriggered: root.leaveChatClicked() }
    }
}