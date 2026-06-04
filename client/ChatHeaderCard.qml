import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient

Rectangle {
    id: root

    property string titleText: ""
    property string subtitleText: ""
    property bool showMenu: false
    property int peerUserId: 0
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
    signal openUserWall()

    Layout.fillWidth: true
    height: 72
    radius: 10
    color: Theme.bgSecondary
    border.color: Theme.border
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
                    color: Theme.textPrimary
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
                    color: chatMenuButton.hovered ? Theme.hoverSubtle : "transparent"
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
                                color: Theme.textPrimary
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
            color: (root.typingUsers && root.typingUsers.length > 0) ? Theme.accent : Theme.textMuted
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
            color: Theme.bgSecondary
            border.color: Theme.border
        }

        MenuItem { text: "Переименовать чат"; onTriggered: root.renameChatClicked() }
        MenuItem { text: "Добавить участника"; onTriggered: root.addUserClicked() }
        MenuItem { text: "Удалить участника"; onTriggered: root.removeUserClicked() }
        MenuItem { text: "Выйти из чата"; onTriggered: root.leaveChatClicked() }
    }
}