import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string userLabel: ""
    signal logoutClicked()

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

        Text {
            text: root.userLabel
            color: "#6b7280"
            Layout.alignment: Qt.AlignVCenter
        }

        Button {
            text: "Выйти"
            onClicked: root.logoutClicked()
        }
    }
}
