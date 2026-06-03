import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ApiClient.js" as WebApi

ScrollView {
    id: root

    property int userId: -1
    property bool isLoading: false

    signal postCreated(string content)
    signal postDeleted(int postId)

    property var postsModel: []
    property var userInfo: ({})

    function loadUserProfile() {
        if (root.userId <= 0) return

        root.isLoading = true
        console.log("=== loadUserProfile START ===")
        console.log("Loading profile for user:", root.userId)

        WebApi.ApiClient.getUserProfile(root.userId, function(status, response) {
            if (status === 200) {
                root.userInfo = response
                console.log("User profile loaded:", response.name)
            } else {
                console.error("Failed to load user profile, status:", status, "error:", response.error)
            }
        })

        WebApi.ApiClient.getUserWall(root.userId, 100, 0, function(status, response) {
            root.isLoading = false
            console.log("=== getUserWall RESPONSE ===")
            console.log("Status:", status)
            console.log("Response:", JSON.stringify(response))

            if (status === 200) {
                root.postsModel = response.posts || []
                console.log("Posts loaded count:", root.postsModel.length)
            } else {
                console.error("Failed to load wall posts, status:", status)
                root.postsModel = []
            }
            console.log("=== loadUserProfile END ===")
        })
    }

    function refresh() {
        console.log("Refreshing wall...")
        loadUserProfile()
    }

    function deletePost(postId) {
        WebApi.ApiClient.deletePost(postId, (typeof appState !== "undefined" ? appState.currentUserId : -1), function(status, response) {
            if (status === 200) {
                root.postDeleted(postId)
                refresh()
                if (typeof setStatus === "function") setStatus("Пост удалён")
            } else {
                if (typeof setError === "function") setError(response.error || "Не удалось удалить пост")
            }
        })
    }

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: root.availableWidth
        spacing: 16

        UserWallHeader {
            id: profileHeader
            Layout.fillWidth: true
            userName: root.userInfo.name || ""
            userLogin: root.userInfo.login || ""
            userBio: root.userInfo.bio || ""
            postsCount: root.postsModel.length
            isOwnProfile: root.userId === (typeof appState !== "undefined" ? appState.currentUserId : -1)
            onEditProfileClicked: editProfileDialog.open()
        }

        CreatePostPanel {
            Layout.fillWidth: true
            onPostCreated: function(content) {
                console.log("Post created signal received, content:", content)
                root.postCreated(content)
            }
        }

        Text {
            text: "Посты"
            font.pixelSize: 16
            font.bold: true
            color: "#111827"
            Layout.fillWidth: true
            Layout.topMargin: 8
        }

        Repeater {
            model: root.postsModel

            delegate: PostCard {
                required property var modelData

                width: parent ? parent.width : root.availableWidth
                Layout.fillWidth: true

                postId: modelData.post_id
                authorId: modelData.author_id
                authorName: modelData.author_name
                authorLogin: modelData.author_login || ""
                content: modelData.content
                createdAt: modelData.created_at
                isOwnPost: modelData.author_id === (typeof appState !== "undefined" ? appState.currentUserId : -1)
                isWallOwner: root.userId === (typeof appState !== "undefined" ? appState.currentUserId : -1)

                onAuthorClicked: {
                    if (modelData.author_id !== root.userId) {
                        root.userId = modelData.author_id
                        loadUserProfile()
                    }
                }
                onDeleteClicked: root.deletePost(modelData.post_id)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "transparent"
            visible: root.isLoading && root.postsModel.length === 0

            Text {
                anchors.centerIn: parent
                text: "Загрузка..."
                color: "#6b7280"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "transparent"
            visible: !root.isLoading && root.postsModel.length === 0

            Text {
                anchors.centerIn: parent
                text: "Нет постов. Будьте первым!"
                color: "#9ca3af"
                font.pixelSize: 14
            }
        }
    }

    Dialog {
        id: editProfileDialog
        title: "Редактировать профиль"
        modal: true
        width: 420
        height: 280
        x: (window.width - width) / 2 - width/2
        y: (window.height - height) / 2 - height/2
        parent: window.overlay

        background: Rectangle {
            radius: 16
            color: "#ffffff"
            border.color: "#e5e7eb"
        }

        header: Rectangle {
            height: 48
            width: parent.width
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "Редактировать профиль"
                font.pixelSize: 18
                font.bold: true
                color: "#111827"
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            TextField {
                id: editNameField
                placeholderText: "Имя"
                text: root.userInfo.name || ""
                Layout.fillWidth: true
                padding: 12
                background: Rectangle {
                    radius: 10
                    color: "#f9fafb"
                    border.color: "#e5e7eb"
                }
            }

            TextArea {
                id: editBioField
                placeholderText: "О себе"
                text: root.userInfo.bio || ""
                Layout.fillWidth: true
                Layout.minimumHeight: 80
                wrapMode: Text.WordWrap
                padding: 12
                background: Rectangle {
                    radius: 10
                    color: "#f9fafb"
                    border.color: "#e5e7eb"
                }
            }

            Text {
                text: editProfileDialog.errorText
                color: "#dc2626"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: editProfileDialog.errorText !== ""
            }
        }

        footer: Rectangle {
            height: 60
            width: parent.width
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: "Отмена"
                    padding: 10
                    background: Rectangle {
                        radius: 10
                        color: parent.hovered ? "#f3f4f6" : "#ffffff"
                        border.color: "#e5e7eb"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#6b7280"
                    }
                    onClicked: editProfileDialog.close()
                }

                Button {
                    text: "Сохранить"
                    padding: 10
                    background: Rectangle {
                        radius: 10
                        color: parent.hovered ? "#2563eb" : "#3b82f6"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                    }
                    onClicked: {
                        editProfileDialog.errorText = ""
                        const updates = {}
                        if (editNameField.text !== root.userInfo.name) updates.name = editNameField.text
                        if (editBioField.text !== (root.userInfo.bio || "")) updates.bio = editBioField.text

                        if (Object.keys(updates).length === 0) {
                            editProfileDialog.close()
                            return
                        }

                        WebApi.ApiClient.updateUserProfile(
                            typeof appState !== "undefined" ? appState.currentUserId : -1,
                            updates,
                            function(status, response) {
                                if (status === 200) {
                                    editProfileDialog.close()
                                    root.userInfo = response
                                    if (typeof setStatus === "function") setStatus("Профиль обновлён")
                                } else {
                                    editProfileDialog.errorText = response.error || "Ошибка обновления"
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    onUserIdChanged: {
        console.log("UserId changed to:", root.userId)
        loadUserProfile()
    }
}