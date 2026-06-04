import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient

Rectangle {
    id: root

    property string userLabel: ""
    signal logoutClicked()
    signal createChatClicked()
    signal searchTextChanged(string text)

    height: 64
    color: Theme.bgSecondary
    border.color: Theme.border

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
            text: "Seagull Messenger"
            font.pixelSize: 20
            font.bold: true
            color: Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        TextField {
            id: messageSearchField
            placeholderText: "Поиск сообщений"
            Layout.preferredWidth: 320
            padding: 10
            color: Theme.textPrimary
            placeholderTextColor: Theme.textFaint
            background: Rectangle {
                radius: 12
                color: Theme.inputBg
                border.color: Theme.border
            }
            onTextChanged: root.searchTextChanged(text)
        }

        Text {
            text: root.userLabel
            color: Theme.textMuted
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            id: menuButton

            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignVCenter

            padding: 0
            background: Rectangle {
                color: menuButton.hovered ? Theme.hoverSubtle : "transparent"
                radius: 4
            }

            contentItem: Item {

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: 3

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18
                            height: 2
                            radius: 1
                            color: Theme.textPrimary
                        }
                    }
                }
            }
            onClicked: menu.popup(menuButton)
        }
    }

    Menu {
        id: menu
        implicitWidth: 220
        padding: 6
        clip: true
        background: Rectangle {
            radius: 12
            color: Theme.bgSecondary
            border.color: Theme.border
        }

        MenuItem {
            id: createChatMenuItem
            text: "Создать чат"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: createChatMenuItem.text
                color: Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: createChatMenuItem.hovered ? Theme.hover : "transparent"
            }
            onTriggered: root.createChatClicked()
        }

        MenuItem {
            id: darkThemeMenuItem
            text: Theme.isDark ? "Светлая тема" : "Тёмная тема"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: darkThemeMenuItem.text
                color: Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: darkThemeMenuItem.hovered ? Theme.hover : "transparent"
            }
            onTriggered: Theme.toggle()
        }

        MenuItem {
            id: logoutMenuItem
            text: "Выйти"
            implicitHeight: 32
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 6
            contentItem: Text {
                text: logoutMenuItem.text
                color: Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: logoutMenuItem.hovered ? Theme.hover : "transparent"
            }
            onTriggered: root.logoutClicked()
        }
    }
}
