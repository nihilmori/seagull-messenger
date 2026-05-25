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

    palette.text: "#111827"
    palette.windowText: "#111827"
    palette.buttonText: "#111827"
    palette.placeholderText: "#9ca3af"
    palette.highlightedText: "#ffffff"

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
    property string currentMode: "chat"
    property var typingUsersModel: []

    signal openUserWall(int userId)

    onOpenUserWall: function(userId) {
        if (userId > 0) {
            console.log("Opening wall for user:", userId)
            currentMode = "wall"
            userWall.userId = userId
            userWall.loadUserProfile()
        }
    }

    function refreshTyping() {
        if (!appState.isLoggedIn || appState.currentChatId <= 0) {
            typingUsersModel = []
            return
        }
        WebApi.ApiClient.getTyping(appState.currentChatId, appState.currentUserId, function(status, response) {
            if (status === 200 && response && response.typing_users) {
                typingUsersModel = response.typing_users
            } else if (status !== 0) {
                typingUsersModel = []
            }
        })
    }

    Timer {
        id: typingPollTimer
        interval: 3000
        repeat: true
        running: appState.isLoggedIn && appState.currentChatId > 0
        onTriggered: refreshTyping()
    }

    Connections {
        target: appState
        function onCurrentChatIdChanged() {
            typingUsersModel = []
            refreshTyping()
        }
    }

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

    function fetchUserName(userId) {
        if (!userId || userId <= 0) {
            return
        }
        if (userNamesById[userId] || userNamesById[String(userId)]) {
            return
        }
        WebApi.ApiClient.getUserProfile(userId, function(status, response) {
            if (status === 200 && response && response.user_id && response.name) {
                cacheUserName(response.user_id, response.name)
            }
        })
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
                for (let i = 0; i < messagesModel.length; i++) {
                    const msg = messagesModel[i]
                    if (msg && msg.sender_id && msg.sender_id !== appState.currentUserId) {
                        fetchUserName(msg.sender_id)
                    }
                }
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

    function ensureGroupChat(actionName) {
        if (appState.currentChatId <= 0) {
            setError("Сначала выберите чат")
            return false
        }
        if (appState.currentChatType.toLowerCase() !== "group") {
            setError(actionName + " доступно только для групповых чатов")
            return false
        }
        return true
    }

    function parseParticipants(text) {
        if (!text) {
            return []
        }
        const tokens = String(text).split(/[\s,]+/)
        const ids = []
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i]
            if (!token) {
                continue
            }
            const value = Number.parseInt(token, 10)
            if (!value || value <= 0) {
                return null
            }
            ids.push(value)
        }
        return ids
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
                    composer.notifyMessageSent()
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
                composer.notifyMessageSent()
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
            onCreateChatClicked: createChatDialog.open()
            onSearchTextChanged: loadSearchMessages(text)
        }

        Dialog {
            id: createChatDialog
            title: ""
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 420
            implicitHeight: createChatLayout.implicitHeight + 24
            height: implicitHeight
            background: Rectangle {
                color: "transparent"
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            property string errorText: ""
            onRejected: createChatDialog.close()

            function submitCreateChat() {
                createChatDialog.errorText = ""
                const name = chatNameField.text ? chatNameField.text.trim() : ""
                if (!name) {
                    createChatDialog.errorText = "Введите название чата"
                    return
                }

                const participants = parseParticipants(participantsField.text)
                if (participants === null || participants.length === 0) {
                    createChatDialog.errorText = "Введите корректные user_id участников"
                    return
                }

                WebApi.ApiClient.createGroupChat(name, appState.currentUserId, participants, function(status, response) {
                    if (status === 201) {
                        createChatDialog.close()
                        chatNameField.text = ""
                        participantsField.text = ""
                        if (response.chat_id) {
                            appState.currentChatId = response.chat_id
                        }
                        loadChats()
                        loadChatInfo()
                        loadMessages()
                        setStatus("Чат создан")
                    } else {
                        createChatDialog.errorText = response.error || "Не удалось создать чат"
                    }
                })
            }

            contentItem: Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
                clip: true

                ColumnLayout {
                    id: createChatLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Создать групповой чат"
                        font.bold: true
                        color: "#111827"
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: chatNameField
                        placeholderText: "Название чата"
                        Layout.fillWidth: true
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: "#f9fafb"
                            border.color: "#e5e7eb"
                        }
                    }

                    TextField {
                        id: participantsField
                        placeholderText: "user_id участников (через запятую)"
                        Layout.fillWidth: true
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: "#f9fafb"
                            border.color: "#e5e7eb"
                        }
                    }

                    Text {
                        text: createChatDialog.errorText
                        color: "#dc2626"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Button {
                            text: "Отмена"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#f3f4f6"
                                border.color: "#e5e7eb"
                            }
                            onClicked: createChatDialog.close()
                        }

                        Button {
                            text: "Создать"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#dbeafe"
                                border.color: "#93c5fd"
                            }
                            onClicked: createChatDialog.submitCreateChat()
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Return"
                context: Qt.WindowShortcut
                enabled: createChatDialog.visible
                onActivated: createChatDialog.submitCreateChat()
            }

            Shortcut {
                sequence: "Enter"
                context: Qt.WindowShortcut
                enabled: createChatDialog.visible
                onActivated: createChatDialog.submitCreateChat()
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                enabled: createChatDialog.visible
                onActivated: createChatDialog.close()
            }

        }

        Dialog {
            id: renameChatDialog
            title: ""
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 360
            implicitHeight: renameChatLayout.implicitHeight + 24
            height: implicitHeight
            background: Rectangle {
                color: "transparent"
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            property string errorText: ""

            function submitRenameChat() {
                renameChatDialog.errorText = ""
                const name = renameChatField.text ? renameChatField.text.trim() : ""
                if (!name) {
                    renameChatDialog.errorText = "Введите новое название"
                    return
                }

                WebApi.ApiClient.renameChat(appState.currentChatId, appState.currentUserId, name, function(status, response) {
                    if (status === 200) {
                        renameChatDialog.close()
                        renameChatField.text = ""
                        loadChats()
                        loadChatInfo()
                        setStatus("Чат переименован")
                    } else {
                        renameChatDialog.errorText = response.error || "Не удалось переименовать чат"
                    }
                })
            }

            contentItem: Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
                clip: true

                ColumnLayout {
                    id: renameChatLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Переименовать чат"
                        font.bold: true
                        color: "#111827"
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    TextField {
                        id: renameChatField
                        placeholderText: "Новое название"
                        Layout.fillWidth: true
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: "#f9fafb"
                            border.color: "#e5e7eb"
                        }
                    }

                    Text {
                        text: renameChatDialog.errorText
                        color: "#dc2626"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Button {
                            text: "Сохранить"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#dbeafe"
                                border.color: "#93c5fd"
                            }
                            onClicked: renameChatDialog.submitRenameChat()
                        }

                        Button {
                            text: "Отмена"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#f3f4f6"
                                border.color: "#e5e7eb"
                            }
                            onClicked: renameChatDialog.close()
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Return"
                context: Qt.WindowShortcut
                enabled: renameChatDialog.visible
                onActivated: renameChatDialog.submitRenameChat()
            }

            Shortcut {
                sequence: "Enter"
                context: Qt.WindowShortcut
                enabled: renameChatDialog.visible
                onActivated: renameChatDialog.submitRenameChat()
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                enabled: renameChatDialog.visible
                onActivated: renameChatDialog.close()
            }

        }

        Dialog {
            id: addUserDialog
            title: ""
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 360
            implicitHeight: addUserLayout.implicitHeight + 24
            height: implicitHeight
            background: Rectangle {
                color: "transparent"
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            property string errorText: ""

            function submitAddUser() {
                addUserDialog.errorText = ""
                const userId = Number.parseInt(addUserField.text, 10)
                if (!userId || userId <= 0) {
                    addUserDialog.errorText = "Введите корректный user_id"
                    return
                }

                WebApi.ApiClient.addUserToChat(appState.currentChatId, appState.currentUserId, userId, function(status, response) {
                    if (status === 200) {
                        addUserDialog.close()
                        addUserField.text = ""
                        loadChatInfo()
                        setStatus("Участник добавлен")
                    } else {
                        addUserDialog.errorText = response.error || "Не удалось добавить участника"
                    }
                })
            }

            contentItem: Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
                clip: true

                ColumnLayout {
                    id: addUserLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Добавить участника"
                        font.bold: true
                        color: "#111827"
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    TextField {
                        id: addUserField
                        placeholderText: "user_id участника"
                        Layout.fillWidth: true
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: "#f9fafb"
                            border.color: "#e5e7eb"
                        }
                    }

                    Text {
                        text: addUserDialog.errorText
                        color: "#dc2626"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Button {
                            text: "Добавить"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#dbeafe"
                                border.color: "#93c5fd"
                            }
                            onClicked: addUserDialog.submitAddUser()
                        }

                        Button {
                            text: "Отмена"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#f3f4f6"
                                border.color: "#e5e7eb"
                            }
                            onClicked: addUserDialog.close()
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Return"
                context: Qt.WindowShortcut
                enabled: addUserDialog.visible
                onActivated: addUserDialog.submitAddUser()
            }

            Shortcut {
                sequence: "Enter"
                context: Qt.WindowShortcut
                enabled: addUserDialog.visible
                onActivated: addUserDialog.submitAddUser()
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                enabled: addUserDialog.visible
                onActivated: addUserDialog.close()
            }

        }

        Dialog {
            id: removeUserDialog
            title: ""
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 360
            implicitHeight: removeUserLayout.implicitHeight + 24
            height: implicitHeight
            background: Rectangle {
                color: "transparent"
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            property string errorText: ""

            function submitRemoveUser() {
                removeUserDialog.errorText = ""
                const userId = Number.parseInt(removeUserField.text, 10)
                if (!userId || userId <= 0) {
                    removeUserDialog.errorText = "Введите корректный user_id"
                    return
                }

                WebApi.ApiClient.removeUserFromChat(appState.currentChatId, appState.currentUserId, userId, function(status, response) {
                    if (status === 200) {
                        removeUserDialog.close()
                        removeUserField.text = ""
                        loadChatInfo()
                        setStatus("Участник удалён")
                    } else {
                        removeUserDialog.errorText = response.error || "Не удалось удалить участника"
                    }
                })
            }

            contentItem: Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
                clip: true

                ColumnLayout {
                    id: removeUserLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Удалить участника"
                        font.bold: true
                        color: "#111827"
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    TextField {
                        id: removeUserField
                        placeholderText: "user_id участника"
                        Layout.fillWidth: true
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: "#f9fafb"
                            border.color: "#e5e7eb"
                        }
                    }

                    Text {
                        text: removeUserDialog.errorText
                        color: "#dc2626"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Button {
                            text: "Удалить"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#dbeafe"
                                border.color: "#93c5fd"
                            }
                            onClicked: removeUserDialog.submitRemoveUser()
                        }

                        Button {
                            text: "Отмена"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#f3f4f6"
                                border.color: "#e5e7eb"
                            }
                            onClicked: removeUserDialog.close()
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Return"
                context: Qt.WindowShortcut
                enabled: removeUserDialog.visible
                onActivated: removeUserDialog.submitRemoveUser()
            }

            Shortcut {
                sequence: "Enter"
                context: Qt.WindowShortcut
                enabled: removeUserDialog.visible
                onActivated: removeUserDialog.submitRemoveUser()
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                enabled: removeUserDialog.visible
                onActivated: removeUserDialog.close()
            }

        }

        Dialog {
            id: participantsDialog
            title: "Участники чата"
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 420
            height: 420
            background: Rectangle {
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: appState.currentChatName
                    font.bold: true
                    color: "#111827"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: participantsModel
                    spacing: 6

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 40
                        radius: 8
                        color: "#f9fafb"
                        border.color: "#e5e7eb"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Text {
                                text: modelData.name || "Без имени"
                                color: "#111827"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "#" + modelData.user_id
                                color: "#6b7280"
                            }
                        }

                        Menu {
                            id: participantMenu
                            implicitWidth: 220
                            padding: 6
                            clip: true
                            background: Rectangle {
                                radius: 12
                                color: "#ffffff"
                                border.color: "#e5e7eb"
                            }

                            MenuItem {
                                id: removeFromChatItem
                                text: "Удалить из чата"
                                implicitHeight: 32
                                leftPadding: 12
                                rightPadding: 12
                                topPadding: 6
                                bottomPadding: 6
                                contentItem: Text {
                                    text: removeFromChatItem.text
                                    color: "#111827"
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    radius: 12
                                    color: removeFromChatItem.hovered ? "#e5e7eb" : "transparent"
                                }
                                onTriggered: {
                                    if (appState.currentChatType.toLowerCase() !== "group") {
                                        setError("Удаление доступно только для групповых чатов")
                                        return
                                    }
                                    if (modelData.user_id === appState.currentUserId) {
                                        leaveChatDialog.open()
                                        return
                                    }
                                    WebApi.ApiClient.removeUserFromChat(appState.currentChatId, appState.currentUserId, modelData.user_id, function(status, response) {
                                        if (status === 200) {
                                            loadChatInfo()
                                            setStatus("Участник удалён")
                                        } else {
                                            setError(response.error || "Не удалось удалить участника")
                                        }
                                    })
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    participantMenu.popup()
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !participantsModel || participantsModel.length === 0
                    text: "Участники не найдены"
                    color: "#6b7280"
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight

                    Button {
                        text: "Закрыть"
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: "#f3f4f6"
                            border.color: "#e5e7eb"
                        }
                        onClicked: participantsDialog.close()
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                enabled: participantsDialog.visible
                onActivated: participantsDialog.close()
            }

        }

        Dialog {
            id: leaveChatDialog
            title: ""
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 360
            implicitHeight: leaveChatLayout.implicitHeight + 24
            height: implicitHeight
            background: Rectangle {
                color: "transparent"
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            property string errorText: ""

            contentItem: Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
                clip: true

                ColumnLayout {
                    id: leaveChatLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Выйти из чата"
                        font.bold: true
                        color: "#111827"
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Вы уверены, что хотите выйти из чата?"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: leaveChatDialog.errorText
                        color: "#dc2626"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Button {
                            text: "Выйти"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#dbeafe"
                                border.color: "#93c5fd"
                            }
                            onClicked: {
                                leaveChatDialog.errorText = ""
                                WebApi.ApiClient.leaveChat(appState.currentChatId, appState.currentUserId, function(status, response) {
                                    if (status === 200) {
                                        leaveChatDialog.close()
                                        appState.currentChatId = -1
                                        loadChats()
                                        loadChatInfo()
                                        loadMessages()
                                        setStatus("Вы вышли из чата")
                                    } else {
                                        leaveChatDialog.errorText = response.error || "Не удалось выйти из чата"
                                    }
                                })
                            }
                        }

                        Button {
                            text: "Отмена"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: "#f3f4f6"
                                border.color: "#e5e7eb"
                            }
                            onClicked: leaveChatDialog.close()
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                enabled: leaveChatDialog.visible
                onActivated: leaveChatDialog.close()
            }

        }

        Popup {
            id: searchPopup
            x: (window.width - width) / 2
            y: topBar.height
            width: 600
            height: 320
            visible: searchQuery.length > 1 && searchMessagesModel && searchMessagesModel.length > 0
            modal: false
            background: Rectangle {
                radius: 12
                color: "#ffffff"
                border.color: "#e5e7eb"
            }

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
            onChatSelected: function(chatId) {
                selectChat(chatId)
                if (currentMode !== "chat") {
                    currentMode = "chat"
                }
            }
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

            RowLayout {
                id: modeSwitcher
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                height: 40
                spacing: 8
                visible: appState.isLoggedIn

                Button {
                    text: "Чаты"
                    checkable: true
                    checked: currentMode === "chat"
                    onClicked: currentMode = "chat"
                    background: Rectangle {
                        radius: 20
                        color: parent.checked ? "#dbeafe" : "#f3f4f6"
                        border.color: parent.checked ? "#93c5fd" : "#e5e7eb"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "#2563eb" : "#6b7280"
                    }
                }

                Button {
                    text: "Моя стена"
                    checkable: true
                    checked: currentMode === "myWall"
                    onClicked: {
                        currentMode = "myWall"
                        userWall.userId = appState.currentUserId
                        userWall.loadUserProfile()
                    }
                    background: Rectangle {
                        radius: 20
                        color: parent.checked ? "#dbeafe" : "#f3f4f6"
                        border.color: parent.checked ? "#93c5fd" : "#e5e7eb"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "#2563eb" : "#6b7280"
                    }
                }

                Item { Layout.fillWidth: true }

                TextField {
                    id: wallSearchField
                    placeholderText: "Поиск по стене..."
                    visible: currentMode !== "chat"
                    Layout.preferredWidth: 200
                    padding: 8
                    background: Rectangle {
                        radius: 20
                        color: "#f9fafb"
                        border.color: "#e5e7eb"
                    }
                    onTextChanged: {
                        if (currentMode !== "chat") {
                            userWall.searchQuery = text
                        }
                    }
                }
            }

            StackLayout {
                anchors.top: modeSwitcher.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                currentIndex: currentMode === "chat" ? 0 : 1

                ColumnLayout {
                    spacing: 10

                    ChatHeaderCard {
                        id: chatHeader
                        Layout.fillWidth: true
                        titleText: appState.currentChatId > 0 ? appState.currentChatName : "Выберите чат или начните личный чат"
                        subtitleText: appState.currentChatId > 0
                                      ? (appState.currentChatType === 'private' ? "" : ("Участников: " + participantsModel.length))
                                      : "Чтобы начать личный чат, введите user_id получателя"
                        showMenu: appState.currentChatId > 0
                                  && appState.currentChatType.toLowerCase() === "group"
                        typingUsers: appState.currentChatId > 0 ? window.typingUsersModel : []
                        peerUserId: {
                            if (appState.currentChatId > 0 && appState.currentChatType === 'private') {
                                for (var i = 0; i < participantsModel.length; i++) {
                                    if (participantsModel[i].user_id !== appState.currentUserId) {
                                        return participantsModel[i].user_id
                                    }
                                }
                            }
                            return 0
                        }

                        onTitleClicked: {
                            if (appState.currentChatId > 0) {
                                participantsDialog.open()
                            } else {
                                setError("Сначала выберите чат")
                            }
                        }

                        onOpenUserWall: {
                            if (chatHeader.peerUserId > 0) {
                                console.log("Opening wall from chat header for user:", chatHeader.peerUserId)
                                currentMode = "wall"
                                userWall.userId = chatHeader.peerUserId
                                userWall.loadUserProfile()
                            }
                        }

                        onRenameChatClicked: {
                            if (ensureGroupChat("Переименование")) {
                                renameChatDialog.open()
                            }
                        }
                        onAddUserClicked: {
                            if (ensureGroupChat("Добавление участников")) {
                                addUserDialog.open()
                            }
                        }
                        onRemoveUserClicked: {
                            if (ensureGroupChat("Удаление участников")) {
                                removeUserDialog.open()
                            }
                        }
                        onLeaveChatClicked: {
                            if (appState.currentChatId > 0) {
                                leaveChatDialog.open()
                            } else {
                                setError("Сначала выберите чат")
                            }
                        }
                    }

                    MessageList {
                        id: messagesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        messagesModel: window.messagesModel
                        currentUserId: appState.currentUserId
                        userNamesById: window.userNamesById
                        participantsModel: window.participantsModel
                        currentChatType: appState.currentChatType
                        onEditMessageRequested: function(messageId, content) {
                            startEditingMessage(messageId, content)
                        }
                        onDeleteMessageRequested: function(messageId) {
                            if (!messageId || messageId <= 0) return
                            clearStatus()
                            WebApi.ApiClient.deleteMessage(messageId, appState.currentUserId, function(status, response) {
                                if (status === 200) {
                                    if (window.editingMessageId === messageId) cancelEditingMessage()
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
                        Layout.fillWidth: true
                        currentChatId: appState.currentChatId
                        editingMessageId: window.editingMessageId
                        errorText: window.errorText
                        statusText: window.statusText
                        onSendClicked: sendCurrentMessage()
                        onCancelEditClicked: cancelEditingMessage()
                    }
                }

                UserWall {
                    id: userWall
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    userId: appState.currentUserId

                    onPostCreated: function(content) {
                        var currentWallOwnerId = userWall.userId
                        console.log("Creating post for user:", currentWallOwnerId)

                        WebApi.ApiClient.createPost(currentWallOwnerId, appState.currentUserId, content, function(status, response) {
                            console.log("Create post response status:", status)
                            if (status === 201) {
                                setStatus("Пост опубликован на стене пользователя")
                                userWall.refresh()
                            } else {
                                setError(response.error || "Не удалось создать пост")
                            }
                        })
                    }

                    onPostDeleted: function(postId) {
                        console.log("Post deleted:", postId)
                        userWall.userId = -1
                        userWall.userId = appState.currentUserId
                    }
                }
            }
        }
    }
}