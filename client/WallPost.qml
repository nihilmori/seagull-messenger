import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property int postId: 0
    property int authorId: 0
    property string authorName: ""
    property string content: ""
    property string createdAt: ""
    property int currentUserId: 0
    property int wallOwnerId: 0
    
    signal deleteRequested(int postId)
    
    width: parent.width
    color: "#ffffff"
    radius: 8
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: "#4CAF50"
                
                Text {
                    anchors.centerIn: parent
                    text: authorName ? authorName.charAt(0).toUpperCase() : "?"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 18
                }
            }
            
            ColumnLayout {
                spacing: 2
                
                Text {
                    text: authorName
                    font.bold: true
                    font.pixelSize: 14
                }
                
                Text {
                    text: formatDate(createdAt)
                    color: "#999999"
                    font.pixelSize: 11
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                visible: (authorId === currentUserId) || (wallOwnerId === currentUserId)
                width: 30
                height: 30
                background: Rectangle {
                    color: parent.pressed ? "#ffebee" : "transparent"
                    radius: 15
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "Удалить"
                    font.pixelSize: 16
                }
                
                onClicked: deleteRequested(postId)
            }
        }
        
        Text {
            text: content
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            font.pixelSize: 14
            color: "#333333"
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#eeeeee"
        }
    }
    
    function formatDate(dateString) {
        if (!dateString) return ""     
        var date = new Date(dateString)
        return date.toLocaleDateString() + " " + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }
}
