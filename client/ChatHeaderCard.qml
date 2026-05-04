import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string titleText: ""
    property string subtitleText: ""

    Layout.fillWidth: true
    height: 72
    radius: 10
    color: "#ffffff"
    border.color: "#e5e7eb"

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        Text {
            text: root.titleText
            font.pixelSize: 18
            font.bold: true
            color: "#111827"
            elide: Text.ElideRight
        }

        Text {
            text: root.subtitleText
            color: "#6b7280"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
