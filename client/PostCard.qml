import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int postId: -1
    property int authorId: -1
    property string authorName: ""
    property string authorLogin: ""
    property string content: ""
    property string createdAt: ""
    property bool isOwnPost: false
    property bool isWallOwner: false

    signal deleteClicked()
    signal authorClicked()

    Layout.fillWidth: true
    height: column.implicitHeight + 24
    radius: 12
    color: "#ffffff"
    border.color: "#e5e7eb"

    property bool pendingDelete: false

    Timer {
        id: resetTimer
        interval: 2000
        onTriggered: {
            pendingDelete = false
            deleteButton.color = "#9ca3af"
            deleteButton.scale = 1.0
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#f8fafc"
        opacity: cardMouseArea.containsMouse ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            spacing: 10
            Layout.fillWidth: true

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: "#f3f4f6"

                Text {
                    anchors.centerIn: parent
                    text: root.authorName ? root.authorName.charAt(0).toUpperCase() : "?"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#6b7280"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.authorClicked()
                }
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: root.authorName
                    font.bold: true
                    font.pixelSize: 15
                    color: "#111827"
                    elide: Text.ElideRight
                    Layout.fillWidth: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.authorClicked()
                    }
                }

                RowLayout {
                    spacing: 8
                    visible: root.authorLogin !== ""

                    Text {
                        text: "@" + root.authorLogin
                        font.pixelSize: 12
                        color: "#6b7280"
                    }

                    Text {
                        text: "•"
                        font.pixelSize: 12
                        color: "#9ca3af"
                    }

                    Text {
                        text: formatDate(root.createdAt)
                        font.pixelSize: 12
                        color: "#9ca3af"
                    }
                }

                Text {
                    text: formatDate(root.createdAt)
                    font.pixelSize: 12
                    color: "#9ca3af"
                    visible: root.authorLogin === ""
                }
            }

            Rectangle {
                id: deleteButton
                width: 36
                height: 36
                radius: 18
                visible: root.isOwnPost || root.isWallOwner

                color: (deleteArea.containsMouse || pendingDelete) ? "#ef4444" : "#9ca3af"

                scale: pendingDelete ? 1.15 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: pendingDelete ? 24 : 22
                    font.bold: true
                    color: "white"
                    Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
                }

                Text {
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 4
                    text: "Нажмите ещё раз"
                    font.pixelSize: 10
                    color: "#ef4444"
                    visible: pendingDelete
                }

                MouseArea {
                    id: deleteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (!root.pendingDelete) {
                            root.pendingDelete = true
                            resetTimer.restart()
                        } else {                           
                            resetTimer.stop()
                            root.pendingDelete = false
                            root.deleteClicked()
                        }
                    }
                }
            }
        }

        Text {
            text: root.content
            wrapMode: Text.WordWrap
            font.pixelSize: 14
            color: "#1f2937"
            Layout.fillWidth: true
            lineHeight: 1.4
        }
    }

    function formatDate(dateValue) {
        if (!dateValue) return ""

        var dateStr = String(dateValue)

        if (dateStr.match(/^\d{4}-\d{2}-\d{2}/)) {
            var parts = dateStr.split(" ")
            var dateParts = parts[0].split("-")
            var timeParts = parts[1] ? parts[1].split(":") : []

            var formatted = dateParts[2] + "." + dateParts[1] + "." + dateParts[0]
            if (timeParts.length >= 2) {
                formatted += " " + timeParts[0] + ":" + timeParts[1]
            }
            return formatted
        }

        if (dateStr.includes("��")) {
            var now = new Date()
            return now.getDate() + "." + (now.getMonth() + 1) + "." + now.getFullYear()
        }

        return dateStr
    }
}