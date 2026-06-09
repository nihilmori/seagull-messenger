# Клиент - Seagull Messenger Desktop

Desktop-клиент на Qt6/QML, общается с сервером по HTTP (`/api/*`), без сокетов — обновления подтягиваются опросом через таймеры.

## Стек

- Qt 6 (Quick, Controls, Layouts, Window)
- QML + JavaScript (XMLHttpRequest)
- CMake (Qt's `qt_add_qml_module`)

## Сборка и запуск

```bash
cd client
cmake -S . -B build-debug -G Ninja
cmake --build build-debug
./build-debug/appSeagullClient
```

Сервер по умолчанию `http://127.0.0.1:8080` (см. `ApiClient.js`, можно переопределить через `ApiClient.setBaseUrl(...)`).

## Структура файлов

| Файл | Назначение |
|---|---|
| [`main.cpp`](../client/main.cpp) | bootstrap QGuiApplication + QQmlApplicationEngine |
| [`Main.qml`](../client/Main.qml) | главное окно, состояние, диалоги, координация подсистем |
| [`Theme.qml`](../client/Theme.qml) | singleton-палитра (light/dark) с `toggle()` |
| [`TopBar.qml`](../client/TopBar.qml) | верхняя панель: название, поиск сообщений, hamburger-меню |
| [`ChatSidebar.qml`](../client/ChatSidebar.qml) | левая колонка: поиск пользователей + список чатов |
| [`ChatHeaderCard.qml`](../client/ChatHeaderCard.qml) | шапка активного чата с typing-индикатором и меню группы |
| [`MessageList.qml`](../client/MessageList.qml) | пузырьки сообщений + контекстное меню редактирования/удаления |
| [`MessageComposer.qml`](../client/MessageComposer.qml) | поле ввода, кнопка эмодзи и отправки, typing-героячик |
| [`EmojiPicker.qml`](../client/EmojiPicker.qml) | палитра эмодзи с TabBar по категориям |
| [`LoginScreen.qml`](../client/LoginScreen.qml) | вход и регистрация |
| [`UserWall.qml`](../client/UserWall.qml) | стена пользователя + диалог редактирования профиля |
| [`UserWallHeader.qml`](../client/UserWallHeader.qml) | шапка стены (аватар, имя, кнопки «Редактировать»/«Написать») |
| [`CreatePostPanel.qml`](../client/CreatePostPanel.qml) | форма создания поста |
| [`PostCard.qml`](../client/PostCard.qml) | карточка поста с двухкликовым удалением |
| [`ApiClient.js`](../client/ApiClient.js) | обёртка над `XMLHttpRequest`, callbacks + Promises |

## Состояние

Источник истины — корневое `Window` в [`Main.qml`](../client/Main.qml). Локальные `QtObject id: appState` и набор `property var ...` хранят:

| Поле | Где живёт | Назначение |
|---|---|---|
| `appState.isLoggedIn`, `currentUserId`, `currentLogin`, `currentName` | `appState` | сессия |
| `appState.currentChatId`, `currentChatName`, `currentChatType` | `appState` | текущий открытый чат |
| `chatsModel`, `messagesModel`, `participantsModel`, `userNamesById` | `window` | данные с сервера |
| `searchUsersModel`, `searchMessagesModel`, `searchQuery` | `window` | поиск |
| `editingMessageId` | `window` | id редактируемого сообщения (-1 = нет) |
| `typingUsersModel` | `window` | «X печатает…» |
| `currentMode` | `window` | `"chat" \| "myWall" \| "wall"` |

Идиоматичный паттерн обновления `var`-моделей:

```qml
userNamesById[userId] = name
userNamesById = userNamesById   // принудительный property-change
```

## Тема

Singleton [`Theme.qml`](../client/Theme.qml) — `pragma Singleton`, зарегистрирован в `CMakeLists.txt` через `qt_add_qml_module(... SINGLETON Theme.qml)`. Все цвета компонентов привязаны к свойствам типа `Theme.bgPrimary`, `Theme.textMuted` и т.п. Переключение света/тьмы — `Theme.toggle()` из пункта меню в [`TopBar.qml`](../client/TopBar.qml).

В нескольких местах остались хардкоды `#ffffff` — это белый текст на цветном фоне (бейдж непрочитанного, активная кнопка «Удалить»), и `palette.highlightedText`, где белый корректен в обеих темах.

## Опрос сервера

Поскольку сервер не поддерживает push, клиент опрашивает:

| Таймер | Интервал | Что делает |
|---|---|---|
| Главный поллер ([`Main.qml`](../client/Main.qml)) | 2500 мс | `loadChats()`, при открытом чате — `loadChatInfo()` и `loadMessages()` |
| `typingPollTimer` | 3000 мс | `getTyping(...)` пока открыт чат |
| `typingHeartbeat` в [`MessageComposer.qml`](../client/MessageComposer.qml) | 3000 мс | `setTyping(true)`, пока пользователь продолжает печатать |
| `typingIdle` | 4000 мс | по тишине — `setTyping(false)` |

`getTyping` отдаёт «свежими» только записи последних 5 секунд (серверная фильтрация по `updated_at`), поэтому даже если клиент перестал слать heartbeat (закрыл вкладку), на собеседнике индикатор сам погаснет.

## ApiClient.js

Единственное место, где идут HTTP-вызовы. Контракт:

- `ApiClient.setBaseUrl(url)` — переопределить базовый адрес
- любой метод принимает опциональный `cb(status, jsonResponse)`; без `cb` возвращает `Promise`
- транспортные ошибки (`onerror`/`ontimeout`/`onabort`) приходят как `status === 0` с `{error: "..."}`
- JSON парсится в `safeParseJson`, при сбое — `{error: "Failed to parse JSON response"}`

Соответствие методов JS ↔ эндпоинтов сервера:

| `ApiClient` метод | HTTP |
|---|---|
| `register / login` | `POST /api/register`, `POST /api/login` |
| `getUserProfile / updateUserProfile` | `GET / PATCH /api/user/profile` |
| `searchUsers` | `GET /api/users/search` |
| `getChats` | `GET /api/chats` |
| `createGroupChat` | `POST /api/chats/group` |
| `getChatInfo / renameChat` | `GET / PATCH /api/chat/{id}` |
| `addUserToChat / removeUserFromChat / leaveChat` | `POST /api/chat/{id}/users/add`, `.../users/remove`, `.../leave` |
| `sendMessage / getMessages / searchMessages` | `POST /api/messages/send`, `GET /api/messages`, `GET /api/messages/search` |
| `editMessage / deleteMessage` | `PATCH / DELETE /api/messages/{id}` |
| `setTyping / getTyping` | `POST / GET /api/chat/{id}/typing` |
| `getUserWall / createPost / deletePost` | `GET /api/wall/{id}/posts`, `POST /api/wall/{id}/post`, `DELETE /api/wall/post/{id}` |

Полный список эндпоинтов и параметров — в [api.md](api.md).

## Потоки навигации

- **Chat**: левая колонка — список чатов. Клик → выбран `currentChatId`. В шапке чата — клик по заголовку приватного чата открывает стену собеседника; для группового — список участников. ПКМ по сообщению (только своему) → меню «Изменить/Удалить».
- **Wall**: кнопка «Моя стена» в верхней панели или клик по имени из участников/поиска/собеседника. На чужой стене — кнопка «Написать» возвращает в чат с этим пользователем (или открывает новый личный чат при первом сообщении).
- **Search**: поле в `TopBar` — поиск сообщений (показывает popup со списком). Поле в `ChatSidebar` — поиск пользователей. Поле в `Wall mode` — клиентский фильтр постов по подстроке.

## Известные ограничения

- Любая операция помечается «локальным» только после успешного ответа сервера; оптимистичных апдейтов нет — заметна задержка при медленной сети.
- Опрос каждые 2.5 c заметно нагружает сервер при большом числе чатов.
- Локальный кэш `userNamesById` сбрасывается при логауте.
- Стена использует SQL-формат таймстампа (`YYYY-MM-DD HH:MM:SS`), форматируется в QML; чат использует уже отформатированный сервером `DD.MM.YYYY HH24:MI:SS`.
- На Parallels ARM VM с Qt RHI Vulkan/Metal иногда виден зелёный треугольный артефакт. Обходится `QSG_RHI_BACKEND=software`.
