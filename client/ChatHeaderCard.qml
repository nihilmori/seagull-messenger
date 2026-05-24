import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string titleText: ""
    property string subtitleText: ""
    property bool showMenu: false
    property var typingUsers: []

    function _typingText() {
        const list = typingUsers || []
        if (list.length === 0) {
            return ""
        }
        if (list.length === 1) {
            return (list[0].name || ("user_" + list[0].user_id)) + " печатает…"
        }
        if (list.length === 2) {
            const a = list[0].name || ("user_" + list[0].user_id)
            const b = list[1].name || ("user_" + list[1].user_id)
            return a + " и " + b + " печатают…"
        }
        const a = list[0].name || ("user_" + list[0].user_id)
        const b = list[1].name || ("user_" + list[1].user_id)
        return a + ", " + b + " и ещё " + (list.length - 2) + " печатают…"
    }

    signal renameChatClicked()
    signal addUserClicked()
    signal removeUserClicked()
    signal leaveChatClicked()
    signal titleClicked()

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
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.titleClicked()
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
            text: (root.typingUsers && root.typingUsers.length > 0) ? root._typingText() : root.subtitleText
            color: (root.typingUsers && root.typingUsers.length > 0) ? "#2563eb" : "#6b7280"
            font.pixelSize: 12
            font.italic: (root.typingUsers && root.typingUsers.length > 0)
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

        MenuItem {
            id: renameChatItem
            text: "Переименовать чат"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: renameChatItem.text
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: renameChatItem.hovered ? "#e5e7eb" : "transparent"
            }
            onTriggered: root.renameChatClicked()
        }

        MenuItem {
            id: addUserItem
            text: "Добавить участника"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: addUserItem.text
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: addUserItem.hovered ? "#e5e7eb" : "transparent"
            }
            onTriggered: root.addUserClicked()
        }

        MenuItem {
            id: removeUserItem
            text: "Удалить участника"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: removeUserItem.text
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: removeUserItem.hovered ? "#e5e7eb" : "transparent"
            }
            onTriggered: root.removeUserClicked()
        }

        MenuItem {
            id: leaveChatItem
            text: "Выйти из чата"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: leaveChatItem.text
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: leaveChatItem.hovered ? "#e5e7eb" : "transparent"
            }
            onTriggered: root.leaveChatClicked()
        }
    }
}
