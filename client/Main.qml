import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import SeagullClient
import "ApiClient.js" as WebApi

Window {
    id: window
    width: 1200
    height: 760
    visible: true
    title: qsTr("Seagull Client")
    color: Theme.bgPrimary

    palette.text: Theme.textPrimary
    palette.windowText: Theme.textPrimary
    palette.buttonText: Theme.textPrimary
    palette.placeholderText: Theme.textFaint
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
    onCurrentModeChanged: clearStatus()
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
            clearStatus()
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
            setError("Сначала выберите чат")
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
        interval: 5000
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
            color: Theme.bgPrimary
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
            property var selectedParticipants: []
            property var dialogSearchResults: []
            onRejected: createChatDialog.close()
            onClosed: {
                chatNameField.text = ""
                participantSearchField.text = ""
                createChatDialog.selectedParticipants = []
                createChatDialog.dialogSearchResults = []
                createChatDialog.errorText = ""
            }

            function isParticipantSelected(userId) {
                const list = createChatDialog.selectedParticipants || []
                for (let i = 0; i < list.length; i++) {
                    if (Number(list[i].user_id) === Number(userId)) return true
                }
                return false
            }

            function toggleParticipant(userId, name) {
                const id = Number(userId)
                if (!id || id <= 0 || id === appState.currentUserId) return
                const list = (createChatDialog.selectedParticipants || []).slice()
                const idx = list.findIndex(function(u) { return Number(u.user_id) === id })
                if (idx >= 0) {
                    list.splice(idx, 1)
                } else {
                    list.push({ user_id: id, name: String(name || "") })
                }
                createChatDialog.selectedParticipants = list
            }

            function runDialogSearch(query) {
                const q = (query || "").trim()
                if (q.length < 2) {
                    createChatDialog.dialogSearchResults = []
                    return
                }
                WebApi.ApiClient.searchUsers(q, function(status, response) {
                    if (status === 200 && response && response.users) {
                        createChatDialog.dialogSearchResults = response.users.filter(function(u) {
                            return Number(u.user_id) !== appState.currentUserId
                        })
                    } else {
                        createChatDialog.dialogSearchResults = []
                    }
                })
            }

            function submitCreateChat() {
                createChatDialog.errorText = ""
                const name = chatNameField.text ? chatNameField.text.trim() : ""
                if (!name) {
                    createChatDialog.errorText = "Введите название чата"
                    return
                }

                const list = createChatDialog.selectedParticipants || []
                if (list.length === 0) {
                    createChatDialog.errorText = "Выберите хотя бы одного участника"
                    return
                }
                const participants = list.map(function(u) { return Number(u.user_id) })

                WebApi.ApiClient.createGroupChat(name, appState.currentUserId, participants, function(status, response) {
                    if (status === 201) {
                        createChatDialog.close()
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
                color: Theme.bgSecondary
                border.color: Theme.border
                clip: true

                ColumnLayout {
                    id: createChatLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Создать групповой чат"
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: chatNameField
                        placeholderText: "Название чата"
                        Layout.fillWidth: true
                        padding: 10
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textFaint
                        background: Rectangle {
                            radius: 12
                            color: Theme.inputBg
                            border.color: Theme.border
                        }
                    }

                    TextField {
                        id: participantSearchField
                        placeholderText: "Поиск пользователей по имени"
                        Layout.fillWidth: true
                        padding: 10
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textFaint
                        background: Rectangle {
                            radius: 12
                            color: Theme.inputBg
                            border.color: Theme.border
                        }
                        onTextChanged: createChatDialog.runDialogSearch(text)
                    }

                    ListView {
                        id: dialogSearchList
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        clip: true
                        model: createChatDialog.dialogSearchResults
                        visible: model && model.length > 0
                        spacing: 4

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isSelected: createChatDialog.isParticipantSelected(modelData.user_id)

                            width: ListView.view.width
                            height: 36
                            radius: 8
                            color: isSelected ? Theme.bubbleOut : (rowMouseArea.containsMouse ? Theme.hoverSubtle : Theme.inputBg)
                            border.color: isSelected ? Theme.bubbleOutBorder : Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: parent.parent.isSelected ? "✓" : "+"
                                    color: parent.parent.isSelected ? Theme.accent : Theme.textFaint
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.preferredWidth: 14
                                }

                                Text {
                                    text: modelData.name + " (#" + modelData.user_id + ")"
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: rowMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: createChatDialog.toggleParticipant(modelData.user_id, modelData.name)
                            }
                        }
                    }

                    Text {
                        visible: participantSearchField.text.length >= 2
                                 && (!createChatDialog.dialogSearchResults || createChatDialog.dialogSearchResults.length === 0)
                        text: "Никого не найдено"
                        color: Theme.textMuted
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: createChatDialog.selectedParticipants && createChatDialog.selectedParticipants.length > 0

                        Repeater {
                            model: createChatDialog.selectedParticipants

                            Rectangle {
                                required property var modelData
                                radius: 14
                                color: Theme.bubbleOut
                                border.color: Theme.bubbleOutBorder
                                implicitWidth: chipRow.implicitWidth + 16
                                implicitHeight: 28

                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: parent.parent.modelData.name
                                        color: Theme.bubbleOutText
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: "✕"
                                        color: Theme.accent
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: createChatDialog.toggleParticipant(parent.modelData.user_id, parent.modelData.name)
                                }
                            }
                        }
                    }

                    Text {
                        text: createChatDialog.errorText
                        color: Theme.error
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        visible: createChatDialog.errorText.length > 0
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Button {
                            text: "Отмена"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: Theme.hoverSubtle
                                border.color: Theme.border
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                            }
                            onClicked: createChatDialog.close()
                        }

                        Button {
                            text: "Создать"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: Theme.bubbleOut
                                border.color: Theme.bubbleOutBorder
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.bubbleOutText
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
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
                color: Theme.bgSecondary
                border.color: Theme.border
                clip: true

                ColumnLayout {
                    id: renameChatLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Переименовать чат"
                        font.bold: true
                        color: Theme.textPrimary
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
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textFaint
                        background: Rectangle {
                            radius: 12
                            color: Theme.inputBg
                            border.color: Theme.border
                        }
                    }

                    Text {
                        text: renameChatDialog.errorText
                        color: Theme.error
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
                                color: Theme.bubbleOut
                                border.color: Theme.bubbleOutBorder
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.bubbleOutText
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            onClicked: renameChatDialog.submitRenameChat()
                        }

                        Button {
                            text: "Отмена"
                            padding: 10
                            background: Rectangle {
                                radius: 12
                                color: Theme.hoverSubtle
                                border.color: Theme.border
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
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
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 420
            height: 480
            background: Rectangle {
                radius: 12
                color: Theme.bgSecondary
                border.color: Theme.border
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            property string errorText: ""
            property var searchResults: []

            function isAlreadyParticipant(userId) {
                for (var i = 0; i < participantsModel.length; i++) {
                    if (participantsModel[i].user_id === userId) return true
                }
                return false
            }

            function refreshSearch(query) {
                addUserDialog.errorText = ""
                const q = (query || "").trim()
                if (q.length < 2) {
                    addUserDialog.searchResults = []
                    return
                }
                WebApi.ApiClient.searchUsers(q, function(status, response) {
                    if (status === 200) {
                        const users = response.users || []
                        addUserDialog.searchResults = users.filter(function(u) {
                            return u.user_id !== appState.currentUserId
                                   && !addUserDialog.isAlreadyParticipant(u.user_id)
                        })
                    } else {
                        addUserDialog.errorText = response.error || "Не удалось выполнить поиск"
                    }
                })
            }

            function addUser(userId) {
                addUserDialog.errorText = ""
                WebApi.ApiClient.addUserToChat(appState.currentChatId, appState.currentUserId, userId, function(status, response) {
                    if (status === 200) {
                        addUserDialog.close()
                        addUserSearchField.text = ""
                        addUserDialog.searchResults = []
                        loadChatInfo()
                        setStatus("Участник добавлен")
                    } else {
                        addUserDialog.errorText = response.error || "Не удалось добавить участника"
                    }
                })
            }

            onOpened: {
                addUserSearchField.text = ""
                addUserDialog.searchResults = []
                addUserDialog.errorText = ""
                addUserSearchField.forceActiveFocus()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "Добавить участника"
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                TextField {
                    id: addUserSearchField
                    placeholderText: "Поиск пользователей"
                    Layout.fillWidth: true
                    padding: 10
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textFaint
                    background: Rectangle {
                        radius: 12
                        color: Theme.inputBg
                        border.color: Theme.border
                    }
                    onTextChanged: addUserDialog.refreshSearch(text)
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: addUserDialog.searchResults
                    spacing: 6

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 44
                        radius: 8
                        color: addUserMouseArea.containsMouse ? Theme.hover : Theme.inputBg
                        border.color: Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name || "Без имени"
                                    color: Theme.textPrimary
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "#" + modelData.user_id
                                    color: Theme.textMuted
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                text: "Добавить"
                                color: Theme.accent
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: addUserMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: addUserDialog.addUser(modelData.user_id)
                        }
                    }
                }

                Text {
                    visible: addUserSearchField.text.trim().length >= 2
                             && addUserDialog.searchResults.length === 0
                             && addUserDialog.errorText === ""
                    text: "Ничего не найдено"
                    color: Theme.textFaint
                    Layout.fillWidth: true
                }

                Text {
                    visible: addUserSearchField.text.trim().length < 2
                    text: "Введите минимум 2 символа"
                    color: Theme.textFaint
                    Layout.fillWidth: true
                }

                Text {
                    text: addUserDialog.errorText
                    color: Theme.error
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    visible: addUserDialog.errorText !== ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight

                    Button {
                        text: "Закрыть"
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: Theme.hoverSubtle
                            border.color: Theme.border
                        }
                        contentItem: Text {
                            text: parent.text
                            color: Theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: addUserDialog.close()
                    }
                }
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
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 420
            height: 460
            background: Rectangle {
                radius: 12
                color: Theme.bgSecondary
                border.color: Theme.border
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            property string errorText: ""

            readonly property var removableParticipants: {
                const list = []
                for (var i = 0; i < participantsModel.length; i++) {
                    const p = participantsModel[i]
                    if (p && p.user_id !== appState.currentUserId) list.push(p)
                }
                return list
            }

            function removeUser(userId) {
                removeUserDialog.errorText = ""
                WebApi.ApiClient.removeUserFromChat(appState.currentChatId, appState.currentUserId, userId, function(status, response) {
                    if (status === 200) {
                        loadChatInfo()
                        setStatus("Участник удалён")
                    } else {
                        removeUserDialog.errorText = response.error || "Не удалось удалить участника"
                    }
                })
            }

            onOpened: {
                removeUserDialog.errorText = ""
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "Удалить участника"
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                Text {
                    text: "Выберите участника, которого хотите удалить"
                    color: Theme.textMuted
                    Layout.fillWidth: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: removeUserDialog.removableParticipants
                    spacing: 6

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 44
                        radius: 8
                        color: Theme.inputBg
                        border.color: Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name || "Без имени"
                                    color: Theme.textPrimary
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "#" + modelData.user_id
                                    color: Theme.textMuted
                                    font.pixelSize: 11
                                }
                            }

                            Button {
                                text: "Удалить"
                                padding: 6
                                background: Rectangle {
                                    radius: 8
                                    color: parent.hovered ? Theme.error : "transparent"
                                    border.color: Theme.error
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.hovered ? "#ffffff" : Theme.error
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: removeUserDialog.removeUser(modelData.user_id)
                            }
                        }
                    }
                }

                Text {
                    visible: removeUserDialog.removableParticipants.length === 0
                    text: "Нет других участников"
                    color: Theme.textFaint
                    Layout.fillWidth: true
                }

                Text {
                    text: removeUserDialog.errorText
                    color: Theme.error
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    visible: removeUserDialog.errorText !== ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight

                    Button {
                        text: "Закрыть"
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: Theme.hoverSubtle
                            border.color: Theme.border
                        }
                        contentItem: Text {
                            text: parent.text
                            color: Theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: removeUserDialog.close()
                    }
                }
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
            modal: true
            focus: true
            clip: true
            x: (window.width - width) / 2
            y: (window.height - height) / 2
            width: 420
            height: 420
            background: Rectangle {
                radius: 12
                color: Theme.bgSecondary
                border.color: Theme.border
            }
            header: Item {
                implicitHeight: 0
                visible: false
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "Участники чата"
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                Text {
                    text: appState.currentChatName
                    color: Theme.textMuted
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
                        color: Theme.inputBg
                        border.color: Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Text {
                                text: modelData.name || "Без имени"
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "#" + modelData.user_id
                                color: Theme.textMuted
                            }
                        }

                        Menu {
                            id: participantMenu
                            implicitWidth: 220
                            padding: 6
                            clip: true
                            background: Rectangle {
                                radius: 12
                                color: Theme.bgSecondary
                                border.color: Theme.border
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
                                    color: Theme.textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    radius: 12
                                    color: removeFromChatItem.hovered ? Theme.hover : "transparent"
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
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    participantMenu.popup()
                                    return
                                }
                                if (mouse.button === Qt.LeftButton && modelData && modelData.user_id) {
                                    participantsDialog.close()
                                    window.openUserWall(modelData.user_id)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !participantsModel || participantsModel.length === 0
                    text: "Участники не найдены"
                    color: Theme.textMuted
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
                            color: Theme.hoverSubtle
                            border.color: Theme.border
                        }
                        contentItem: Text {
                            text: parent.text
                            color: Theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter
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
                color: Theme.bgSecondary
                border.color: Theme.border
                clip: true

                ColumnLayout {
                    id: leaveChatLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Выйти из чата"
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Вы уверены, что хотите выйти из чата?"
                        wrapMode: Text.Wrap
                        color: Theme.textBody
                        Layout.fillWidth: true
                    }

                    Text {
                        text: leaveChatDialog.errorText
                        color: Theme.error
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
                                color: Theme.bubbleOut
                                border.color: Theme.bubbleOutBorder
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.bubbleOutText
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
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
                                color: Theme.hoverSubtle
                                border.color: Theme.border
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
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
                color: Theme.bgSecondary
                border.color: Theme.border
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bgSecondary
                border.color: Theme.border

                ListView {
                    anchors.fill: parent
                    model: searchMessagesModel
                    delegate: Rectangle {
                        width: parent.width
                        height: 56
                        color: Theme.inputBg
                        border.color: Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8

                            Text {
                                text: chatTitle(modelData.chat_id) + ": " + (modelData.content || "")
                                color: Theme.textPrimary
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
                                    currentMode = "chat"
                                    composer.receiverText = ""
                                    selectChat(existing.chat_id)
                                } else {
                                    window.openUserWall(targetUserId)
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
            color: Theme.bgPrimary

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
                        color: parent.checked ? Theme.bubbleOut : Theme.hoverSubtle
                        border.color: parent.checked ? Theme.bubbleOutBorder : Theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? Theme.accent : Theme.textMuted
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
                        color: parent.checked ? Theme.bubbleOut : Theme.hoverSubtle
                        border.color: parent.checked ? Theme.bubbleOutBorder : Theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? Theme.accent : Theme.textMuted
                    }
                }

                Item { Layout.fillWidth: true }

                TextField {
                    id: wallSearchField
                    placeholderText: "Поиск по стене..."
                    visible: currentMode !== "chat"
                    Layout.preferredWidth: 200
                    padding: 8
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textFaint
                    background: Rectangle {
                        radius: 20
                        color: Theme.inputBg
                        border.color: Theme.border
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
                                      : ""
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
                        currentUserId: appState.currentUserId
                        editingMessageId: window.editingMessageId
                        errorText: window.errorText
                        statusText: window.statusText
                        visible: appState.currentChatId > 0 || receiverText !== ""
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
                                wallSearchField.text = ""
                                userWall.searchQuery = ""
                                setStatus("Пост опубликован на стене пользователя")
                                userWall.refresh()
                            } else {
                                setError(response.error || "Не удалось создать пост")
                            }
                        })
                    }

                    onPostDeleted: function(postId) {
                        console.log("Post deleted:", postId)
                        userWall.refresh()
                    }

                    onWriteToUser: function(userId) {
                        if (!userId || userId <= 0 || userId === appState.currentUserId) {
                            return
                        }
                        currentMode = "chat"
                        clearStatus()
                        let existingChatId = -1
                        const chats = chatsModel || []
                        for (let i = 0; i < chats.length; i++) {
                            const chat = chats[i]
                            if (chat && Number(chat.peer_user_id) === userId) {
                                existingChatId = Number(chat.chat_id)
                                break
                            }
                        }
                        if (existingChatId > 0) {
                            appState.currentChatId = existingChatId
                            composer.receiverText = ""
                        } else {
                            appState.currentChatId = -1
                            composer.receiverText = String(userId)
                        }
                    }
                }
            }
        }
    }
}