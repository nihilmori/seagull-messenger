import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int currentChatId: -1
    property int editingMessageId: -1
    property string errorText: ""
    property string statusText: ""

    property alias receiverText: privateReceiverField.text
    property alias messageText: messageField.text

    signal sendClicked()
    signal cancelEditClicked()

    Layout.fillWidth: true
    implicitHeight: composerContent.implicitHeight + 24
    Layout.minimumHeight: implicitHeight
    radius: 10
    color: "#ffffff"
    border.color: "#e5e7eb"

    ColumnLayout {
        id: composerContent
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: privateReceiverField
                placeholderText: "user_id для личного чата"
                visible: root.currentChatId <= 0 && root.editingMessageId <= 0
                Layout.preferredWidth: 200
            }

            TextField {
                id: messageField
                placeholderText: root.editingMessageId > 0
                                 ? "Редактирование сообщения"
                                 : (root.currentChatId > 0 ? "Введите сообщение в чат" : "Введите сообщение для личного чата")
                Layout.fillWidth: true
                onAccepted: root.sendClicked()
            }

            Button {
                text: root.editingMessageId > 0 ? "Сохранить" : "Отправить"
                onClicked: root.sendClicked()
            }

            Button {
                text: "Отмена"
                visible: root.editingMessageId > 0
                onClicked: root.cancelEditClicked()
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.errorText
                color: "#dc2626"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Text {
                text: root.statusText
                color: "#059669"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.Wrap
            }
        }
    }
}
