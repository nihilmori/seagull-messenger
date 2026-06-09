import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SeagullClient

Rectangle {
    id: root

    signal postCreated(string content)

    function submitPost() {
        var trimmed = postInput.text.trim()
        if (trimmed !== "") {
            root.postCreated(trimmed)
            postInput.text = ""
        }
    }

    Layout.fillWidth: true
    implicitHeight: 110
    radius: 12
    color: Theme.bgSecondary
    border.color: Theme.border

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        TextArea {
            id: postInput
            placeholderText: "Что у вас нового?"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.fillHeight: true
            font.pixelSize: 14
            padding: 0
            color: Theme.textPrimary
            placeholderTextColor: Theme.textFaint
            background: Item {}

            Keys.onPressed: function(event) {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !event.modifiers) {
                    event.accepted = true
                    root.submitPost()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Нажмите Enter для отправки"
                font.pixelSize: 10
                color: Theme.textFaint
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Опубликовать"
                enabled: postInput.text.trim() !== ""
                padding: 8

                background: Rectangle {
                    radius: 20
                    color: parent.enabled ? Theme.bubbleOut : Theme.hoverSubtle
                    border.color: parent.enabled ? Theme.bubbleOutBorder : Theme.border
                }

                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? Theme.accent : Theme.textFaint
                }

                onClicked: {
                    root.submitPost()
                }
            }
        }
    }
}
