import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string userLabel: ""
    signal logoutClicked()
    signal createChatClicked()
    signal searchTextChanged(string text)

    height: 64
    color: "#ffffff"
    border.color: "#e5e7eb"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
            text: "Seagull Messenger"
            font.pixelSize: 20
            font.bold: true
            color: "#111827"
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        TextField {
            id: messageSearchField
            placeholderText: "Поиск сообщений"
            Layout.preferredWidth: 320
            padding: 10
            background: Rectangle {
                radius: 12
                color: "#f9fafb"
                border.color: "#e5e7eb"
            }
            onTextChanged: root.searchTextChanged(text)
        }

        Text {
            text: root.userLabel
            color: "#6b7280"
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
                color: menuButton.hovered ? "#f3f4f6" : "transparent"
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
                            color: "#111827"
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
            color: "#ffffff"
            border.color: "#e5e7eb"
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
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: createChatMenuItem.hovered ? "#e5e7eb" : "transparent"
            }
            onTriggered: root.createChatClicked()
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
                color: "#111827"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 12
                color: logoutMenuItem.hovered ? "#e5e7eb" : "transparent"
            }
            onTriggered: root.logoutClicked()
        }
    }
}
