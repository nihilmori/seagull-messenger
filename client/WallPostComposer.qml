import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int authorId: 0
    property int wallOwnerId: 0

    signal postCreated()

    width: parent.width
    color: "#f5f5f5"
    radius: 8
    visible: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        TextArea {
            id: contentInput
            Layout.fillWidth: true
            Layout.minimumHeight: 80
            placeholderText: "Написать на стене..."
            wrapMode: TextArea.Wrap
            font.pixelSize: 14
            background: Rectangle {
                color: "white"
                radius: 4
                border.color: contentInput.activeFocus ? "#4CAF50" : "#e0e0e0"
                border.width: 1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            Button {
                text: "Отмена"
                onClicked: {
                    contentInput.text = ""
                    root.visible = false
                }
                background: Rectangle {
                    color: parent.pressed ? "#f0f0f0" : "transparent"
                    radius: 4
                    border.color: "#cccccc"
                    border.width: 1
                }
            }

            Button {
                text: "Опубликовать"
                enabled: contentInput.text.trim().length > 0

                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#45a049" : "#4CAF50") : "#cccccc"
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    var content = contentInput.text.trim()
                    if (content.length === 0) return

                    ApiClient.createWallPost(wallOwnerId, authorId, content, function(status, response) {
                        if (status === 201) {
                            contentInput.text = ""
                            root.visible = false
                            root.postCreated()
                        } else {
                            console.error("Failed to create post:", response.error)
                        }
                    })
                }
            }
        }
    }
}
