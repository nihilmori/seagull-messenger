import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property int userId: 0
    property int currentUserId: 0

    signal postDeleted()

    property var postsModel: []

    ListView {
        id: listView
        anchors.fill: parent
        spacing: 12
        clip: true
        model: postsModel

        header: Item {
            width: parent.width
            height: postsModel.length === 0 && !loadingIndicator.visible ? 100 : 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: "📝"
                    font.pixelSize: 48
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Нет записей на стене"
                    color: "#999999"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        delegate: WallPost {
            width: parent.width
            postId: modelData.postId
            authorId: modelData.authorId
            authorName: modelData.authorName
            content: modelData.content
            createdAt: modelData.createdAt
            currentUserId: root.currentUserId
            wallOwnerId: root.userId

            onDeleteRequested: function(postId) {
                deletePost(postId)
            }
        }

        ScrollBar.vertical: ScrollBar {}
    }

    BusyIndicator {
        id: loadingIndicator
        anchors.centerIn: parent
        running: false
    }

    function loadPosts() {
        if (userId <= 0) return

        loadingIndicator.running = true

        ApiClient.getWallPosts(userId, 50, 0, function(status, response) {
            loadingIndicator.running = false

            if (status === 200) {
                postsModel = response.posts || []
            } else {
                console.error("Failed to load wall posts:", response.error)
            }
        })
    }

    function refresh() {
        loadPosts()
    }

    function deletePost(postId) {
        ApiClient.deleteWallPost(postId, currentUserId, function(status, response) {
            if (status === 200) {
                loadPosts()
                root.postDeleted()
            } else {
                console.error("Failed to delete post:", response.error)
            }
        })
    }

    onUserIdChanged: {
        if (userId > 0) {
            loadPosts()
        }
    }

    Component.onCompleted: {
        if (userId > 0) {
            loadPosts()
        }
    }
}
