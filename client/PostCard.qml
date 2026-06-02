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

    function pad2(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function formatDate(dateValue) {
        if (!dateValue) return ""

        var dateStr = String(dateValue).trim()
        if (!dateStr) return ""

        if (dateStr.match(/^\d+$/)) {
            var ts = Number(dateStr)
            if (dateStr.length <= 10) {
                ts *= 1000
            }
            var dateFromTs = new Date(ts)
            if (!isNaN(dateFromTs.getTime())) {
                return pad2(dateFromTs.getDate()) + "." + pad2(dateFromTs.getMonth() + 1) + "." +
                    dateFromTs.getFullYear() + " " + pad2(dateFromTs.getHours()) + ":" + pad2(dateFromTs.getMinutes())
            }
        }

        var match = dateStr.match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::\d{2})?)?/)
        if (match) {
            var formatted = match[3] + "." + match[2] + "." + match[1]
            if (match[4] && match[5]) {
                formatted += " " + match[4] + ":" + match[5]
            }
            return formatted
        }

        var normalized = dateStr.replace(" ", "T")
        var parsed = Date.parse(normalized)
        if (!isNaN(parsed)) {
            var dateFromParsed = new Date(parsed)
            return pad2(dateFromParsed.getDate()) + "." + pad2(dateFromParsed.getMonth() + 1) + "." +
                dateFromParsed.getFullYear() + " " + pad2(dateFromParsed.getHours()) + ":" + pad2(dateFromParsed.getMinutes())
        }

        return ""
    }
}