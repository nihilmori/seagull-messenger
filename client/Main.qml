import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "ApiClient.js" as WebApi

Window {
    id: window
    width: 1200
    height: 760
    visible: true
    title: qsTr("Seagull Client")
    color: "#f5f7fb"

    QtObject {
        id: appState
        property bool isLoggedIn: false
        property int currentUserId: -1
        property string currentLogin: ""
        property string currentName: ""
        property int currentChatId: -1
        property string currentChatName: ""
        property string currentChatType: ""
    }

    property var chatsModel: []
    property var messagesModel: []
    property var participantsModel: []
    property var searchUsersModel: []
    property var userNamesById: ({})
    property string statusText: ""
    property string errorText: ""
    property int editingMessageId: -1
    property var searchMessagesModel: []
    property string searchQuery: ""

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
            if (!appState.isLoggedIn) {
                return
            }
            if (window.editingMessageId > 0) {
                cancelEditingMessage()
                return
            }
            if (appState.currentChatId > 0) {
                clearStatus()
                appState.currentChatId = -1
            }
        }
    }

    function startEditingMessage(messageId, content) {
        if (!messageId || messageId <= 0) {
            return
        }
        clearStatus()
        window.editingMessageId = messageId
        composer.messageText = String(content || "")
    }

    function cancelEditingMessage() {
        window.editingMessageId = -1
        clearStatus()
        composer.messageText = ""
    }

    function cacheUserName(userId, name) {
        if (!userId || userId <= 0 || !name) {
            return
        }
        userNamesById[userId] = name
        userNamesById = userNamesById
    }

    function clearStatus() {
        statusText = ""
        errorText = ""
    }

    function setError(text) {
        errorText = text
        statusText = ""
    }

    function setStatus(text) {
        statusText = text
        errorText = ""
    }

    function loadChats() {
        if (!appState.isLoggedIn) {
            return
        }
        WebApi.ApiClient.getChats(appState.currentUserId, 50, 0, function(status, response) {
            if (status === 200) {
                chatsModel = response.chats || []

                for (let i = 0; i < chatsModel.length; i++) {
                    const chat = chatsModel[i]
                    if (chat.peer_user_id && chat.display_name) {
                        cacheUserName(chat.peer_user_id, chat.display_name)
                    }
                }
            } else {
                setError(response.error || "Не удалось загрузить чаты")
            }
        })
    }

    function loadChatInfo() {
        if (!appState.isLoggedIn || appState.currentChatId <= 0) {
            appState.currentChatName = ""
            participantsModel = []
            appState.currentChatType = ""
            return
        }
        WebApi.ApiClient.getChatInfo(appState.currentChatId, appState.currentUserId, function(status, response) {
            if (status === 200) {
                appState.currentChatName = response.display_name || response.name || ("Чат #" + appState.currentChatId)
                participantsModel = response.participants || []
                appState.currentChatType = response.type_name || ""

                cacheUserName(appState.currentUserId, appState.currentName)
                for (let i = 0; i < participantsModel.length; i++) {
                    const participant = participantsModel[i]
                    cacheUserName(participant.user_id, participant.name)
                }
            } else {
                setError(response.error || "Не удалось загрузить чат")
            }
        })
    }

    function loadMessages() {
        if (!appState.isLoggedIn || appState.currentChatId <= 0) {
            messagesModel = []
            return
        }
        WebApi.ApiClient.getMessages(appState.currentChatId, appState.currentUserId, 50, 0, function(status, response) {
            if (status === 200) {
                messagesModel = response.messages || []
            } else {
                setError(response.error || "Не удалось загрузить сообщения")
            }
        })
    }

    function loadSearchUsers(query) {
        if (!query || query.length < 2) {
            searchUsersModel = []
            return
        }
        WebApi.ApiClient.searchUsers(query, function(status, response) {
            if (status === 200) {
                searchUsersModel = response.users || []

                for (let i = 0; i < searchUsersModel.length; i++) {
                    const user = searchUsersModel[i]
                    cacheUserName(user.user_id, user.name)
                }
            } else {
                setError(response.error || "Не удалось выполнить поиск пользователей")
            }
        })
    }

    function loadSearchMessages(query) {
        searchQuery = query || ""
        if (!query || query.length < 2) {
            searchMessagesModel = []
            return
        }

        const chatId = appState.currentChatId > 0 ? appState.currentChatId : undefined
        WebApi.ApiClient.searchMessages(query, appState.currentUserId, chatId, 50, 0, function(status, response) {
            if (status === 200) {
                searchMessagesModel = response.messages || []
            } else {
                setError(response.error || "Не удалось выполнить поиск сообщений")
            }
        })
    }

    function chatTitle(chatId) {
        if (!chatId || chatId <= 0) {
            return "Чат"
        }
        const chat = (chatsModel || []).find(function(item) {
            return item && Number(item.chat_id) === Number(chatId)
        })
        if (chat) {
            return chat.display_name || chat.name || ("Чат #" + chatId)
        }
        return "Чат #" + chatId
    }

    function selectChat(chatId) {
        if (appState.currentChatId === chatId) {
            return
        }
        appState.currentChatId = chatId
    }

    function sendCurrentMessage() {
        clearStatus()
        if (!composer.messageText || composer.messageText.trim().length === 0) {
            setError("Введите сообщение")
            return
        }

        if (window.editingMessageId > 0) {
            if (appState.currentChatId <= 0) {
                setError("Редактирование доступно только в чате")
                return
            }

            const messageId = window.editingMessageId
            WebApi.ApiClient.editMessage(messageId, appState.currentUserId, composer.messageText, function(status, response) {
                if (status === 200) {
                    cancelEditingMessage()
                    loadMessages()
                    loadChats()
                    setStatus("Сообщение обновлено")
                } else {
                    setError(response.error || "Не удалось отредактировать сообщение")
                }
            })
            return
        }

        if (appState.currentChatId > 0) {
            WebApi.ApiClient.sendMessage(appState.currentUserId, composer.messageText, appState.currentChatId, null, function(status, response) {
                if (status === 201) {
                    composer.messageText = ""
                    loadMessages()
                    loadChats()
                } else {
                    setError(response.error || "Не удалось отправить сообщение")
                }
            })
            return
        }

        const receiverId = Number.parseInt(composer.receiverText, 10)
        if (!receiverId || receiverId <= 0) {
            setError("Укажите user_id получателя для личного чата")
            return
        }

        WebApi.ApiClient.sendMessage(appState.currentUserId, composer.messageText, 0, receiverId, function(status, response) {
            if (status === 201) {
                composer.messageText = ""
                if (response.chat_id) {
                    appState.currentChatId = response.chat_id
                }
                loadChats()
                loadChatInfo()
                loadMessages()
            } else {
                setError(response.error || "Не удалось отправить личное сообщение")
            }
        })
    }

    function logout() {
        appState.isLoggedIn = false
        appState.currentUserId = -1
        appState.currentLogin = ""
        appState.currentName = ""
        appState.currentChatId = -1
        appState.currentChatName = ""
        chatsModel = []
        messagesModel = []
        participantsModel = []
        searchUsersModel = []
        sidebar.searchText = ""
        composer.receiverText = ""
        composer.messageText = ""
        window.editingMessageId = -1
        clearStatus()
    }

    Connections {
        target: appState
        function onIsLoggedInChanged() {
            if (appState.isLoggedIn) {
                chatsModel = []
                messagesModel = []
                participantsModel = []
                appState.currentChatId = -1
                appState.currentChatName = ""

                cacheUserName(appState.currentUserId, appState.currentName)
                loadChats()
            } else {
                chatsModel = []
                messagesModel = []
                participantsModel = []
                searchUsersModel = []
            }
        }

        function onCurrentChatIdChanged() {
            if (window.editingMessageId > 0) {
                cancelEditingMessage()
            }
            if (appState.currentChatId > 0) {
                loadChatInfo()
                loadMessages()
            } else {
                appState.currentChatName = ""
                participantsModel = []
                messagesModel = []
            }
        }
    }

    Timer {
        interval: 2500
        running: appState.isLoggedIn
        repeat: true
        onTriggered: {
            loadChats()
            if (appState.currentChatId > 0) {
                loadChatInfo()
                loadMessages()
            }
        }
    }

    LoginScreen {
        anchors.fill: parent
        visible: !appState.isLoggedIn
        appStateRef: appState
    }

    Item {
        anchors.fill: parent
        visible: appState.isLoggedIn

        Rectangle {
            anchors.fill: parent
            color: "#f5f7fb"
        }

        TopBar {
            id: topBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            userLabel: appState.currentName + " @" + appState.currentLogin
            onLogoutClicked: logout()
            onSearchTextChanged: loadSearchMessages(text)
        }

        Popup {
            id: searchPopup
            x: (window.width - 600) / 2
            y: topBar.height
            width: 600
            height: 320
            visible: searchQuery.length > 1 && searchMessagesModel && searchMessagesModel.length > 0
            modal: false

            Rectangle {
                anchors.fill: parent
                color: "#ffffff"
                border.color: "#e5e7eb"

                ListView {
                    anchors.fill: parent
                    model: searchMessagesModel
                    delegate: Rectangle {
                        width: parent.width
                        height: 56
                        color: "#f9fafb"
                        border.color: "#e5e7eb"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8

                            Text {
                                text: chatTitle(modelData.chat_id) + ": " + (modelData.content || "")
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.chat_id && modelData.chat_id > 0) {
                                    selectChat(modelData.chat_id)
                                    loadMessages()
                                }
                                searchPopup.visible = false
                            }
                        }
                    }
                }
            }
        }

        ChatSidebar {
            id: sidebar
            anchors.left: parent.left
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            chatsModel: window.chatsModel
            searchUsersModel: window.searchUsersModel
            currentChatId: appState.currentChatId
            onSearchTextChanged: loadSearchUsers(sidebar.searchText)
            onRefreshChatsClicked: loadChats()
            onChatSelected: selectChat(chatId)
            onUserSelected: (userId, name) =>{
                                if (!userId || userId <= 0) {
                                    return
                                }

                                clearStatus()
                                const targetUserId = Number(userId)
                                const existing = (window.chatsModel || []).find(function(chat) {
                                    return chat && Number(chat.peer_user_id) === targetUserId && chat.chat_id
                                })

                                if (existing && existing.chat_id) {
                                    composer.receiverText = ""
                                    selectChat(existing.chat_id)
                                } else {
                                    if (appState.currentChatId > 0) {
                                        appState.currentChatId = -1
                                    }
                                    composer.receiverText = String(userId)
                                }
                                sidebar.searchText = ""
                                loadSearchUsers("")
                            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: sidebar.width
            anchors.right: parent.right
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            color: "#f5f7fb"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                ChatHeaderCard {
                    titleText: appState.currentChatId > 0 ? appState.currentChatName : "Выберите чат или начните личный чат"
                    subtitleText: appState.currentChatId > 0
                                  ? (appState.currentChatType === 'private' ? "" : ("Участников: " + participantsModel.length))
                                  : "Чтобы начать личный чат, введите user_id получателя"
                }

                MessageList {
                    id: messagesList
                    messagesModel: window.messagesModel
                    currentUserId: appState.currentUserId
                    userNamesById: window.userNamesById
                    onEditMessageRequested: function(messageId, content) {
                        startEditingMessage(messageId, content)
                    }
                    onDeleteMessageRequested: function(messageId) {
                        if (!messageId || messageId <= 0) {
                            return
                        }
                        clearStatus()
                        WebApi.ApiClient.deleteMessage(messageId, appState.currentUserId, function(status, response) {
                            if (status === 200) {
                                if (window.editingMessageId === messageId) {
                                    cancelEditingMessage()
                                }
                                loadMessages()
                                loadChats()
                                setStatus("Сообщение удалено")
                            } else {
                                setError(response.error || "Не удалось удалить сообщение")
                            }
                        })
                    }
                }

                MessageComposer {
                    id: composer
                    currentChatId: appState.currentChatId
                    editingMessageId: window.editingMessageId
                    errorText: window.errorText
                    statusText: window.statusText
                    onSendClicked: sendCurrentMessage()
                    onCancelEditClicked: cancelEditingMessage()
                }
            }
        }
    }
}
