# Структура базы данных - Seagull Messenger

![Схема базы данных](2026-04-15%2015.01.05(1).jpg)

## Users - Пользователи

### Model: User
| Поле | Тип | Описание |
|---|---|---|
| `user_id` | `int` (PK) | Уникальный ID пользователя (auto-increment) |
| `login` | `varchar(50)` (UNIQUE) | Уникальный логин |
| `password_hash` | `text` | Хеш пароля (SHA256) |
| `salt` | `text` | Соль для хеширования пароля |
| `name` | `varchar(100)` | Отображаемое имя пользователя |
| `bio` | `varchar(80)` | Описание профиля (по умолчанию пусто) |

**Схема:** `seagull_schema.users`

**Методы API:**

| Метод | Описание | Возвращает |
|---|---|---|
| `POST /api/register` | Регистрация нового пользователя | `{user_id, login, name}` |
| `POST /api/login` | Вход в систему | `{user_id, login, name}` |
| `GET /api/user/profile?user_id={id}` | Получить профиль пользователя | `{user_id, login, name, bio}` |
| `PATCH /api/user/profile` | Обновить профиль или пароль | `{user_id, login, name, bio}` |
| `GET /api/users/search?query={q}` | Поиск пользователей по имени | `{query, count, users[]}` |

**Примечания:**
- Пароль должен быть от 8 до 32 символов, содержать минимум 1 заглавную букву, 1 строчную букву, 1 цифру и не содержать пробелов
- При обновлении профиля можно изменить: `name`, `bio`, `login`, `new_password`
- При смене пароля требуется `current_password`

---

## Chats - Чаты

### Model: Chat
| Поле | Тип | Описание |
|---|---|---|
| `chat_id` | `int` (PK) | Уникальный ID чата (auto-increment) |
| `name` | `varchar(100)` | Название чата (для групп) или сгенерированное имя для приватов |
| `type` | `int` | Тип чата: `0` = Group, `1` = Private |

**Схема:** `seagull_schema.chats`

### Model: ChatUsers (Участники)
| Поле | Тип | Описание |
|---|---|---|
| `chat_id` | `int` (FK, PK part) | ID чата |
| `user_id` | `int` (FK, PK part) | ID пользователя |
| `joined_at` | `timestamptz` | Дата присоединения к чату |

**Схема:** `seagull_schema.chat_users`

**Методы API:**

| Метод | Описание | Возвращает |
|---|---|---|
| `GET /api/chats?user_id={id}&limit={l}&offset={o}` | Список чатов пользователя | `{chats: [{chat_id, name, type_name, participants_count}]}` |
| `POST /api/chats/group` | Создать групповой чат | `{chat_id, name, type_name, participants[]}` |
| `POST /api/chat/{chat_id}/users/add` | Добавить пользователя в чат | `{chat_id, name, participants[]}` |
| `POST /api/chat/{chat_id}/users/remove` | Удалить пользователя из чата | `{chat_id, name, participants[]}` |
| `POST /api/chat/{chat_id}/leave` | Выход пользователя из чата | `{}` (успех) |
| `GET /api/chat/{chat_id}?user_id={id}` | Получить информацию о чате | `{chat_id, name, type_name, participants[], participants_count}` |
| `PATCH /api/chat/{chat_id}` | Переименовать групповой чат | `{chat_id, name, participants[]}` |

**Примечания:**
- Приватные чаты имеют название формата: `private_{user1_id}_{user2_id}`
- Приватный чат создаётся автоматически при первом сообщении между двумя пользователями (если его ещё нет)
- Добавить человека в приватный чат невозможно
- Выйти из группового чата может любой участник
- `type_name` возвращается как `"group"` или `"private"`

---

## Messages - Сообщения

### Model: Message
| Поле | Тип | Описание |
|---|---|---|
| `message_id` | `int` (PK) | Уникальный ID сообщения (auto-increment) |
| `content` | `text` | Текст сообщения |
| `is_read` | `boolean` | Флаг прочитанного сообщения (по умолчанию `false`) |
| `sent_at` | `timestamptz` | Время отправки (по умолчанию текущее время в UTC) |

**Схема:** `seagull_schema.messages`

### Model: Action (История отправителя и чата)
| Поле | Тип | Описание |
|---|---|---|
| `action_id` | `int` (PK) | Уникальный ID действия |
| `sender_id` | `int` (FK) | ID отправителя (ссылка на `users`) |
| `message_id` | `int` (FK) | ID сообщения (ссылка на `messages`) |
| `chat_id` | `int` (FK) | ID чата (ссылка на `chats`) |

**Схема:** `seagull_schema.actions`

**Методы API:**

| Метод | Описание | Возвращает |
|---|---|---|
| `POST /api/messages/send` | Отправить сообщение | `{message_id, sender_id, chat_id, content, sent_at, receiver_id(?), is_new_chat(?)}` |
| `GET /api/messages?chat_id={id}&user_id={id}&limit={l}&offset={o}` | Получить сообщения чата | `{messages: [{message_id, content, sender_id, chat_id, sent_at}]}` |
| `PATCH /api/messages/{message_id}` | Редактировать сообщение | `{message_id, content, sender_id, chat_id, sent_at}` |

**Примечания:**
- При отправке сообщения в приватный чат указывается `chat_id = 0` и `receiver_id`
- Время возвращается в формате `DD.MM.YYYY HH24:MI:SS` в часовом поясе `Europe/Moscow`

---

## SQL Schema Definition

```sql
DROP SCHEMA IF EXISTS seagull_schema CASCADE;

CREATE SCHEMA IF NOT EXISTS seagull_schema;

CREATE TABLE IF NOT EXISTS seagull_schema.users (
    user_id SERIAL PRIMARY KEY,
    login VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    name VARCHAR(100) NOT NULL,
    bio VARCHAR(80) DEFAULT ''
);

CREATE TABLE IF NOT EXISTS seagull_schema.messages (
    message_id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS seagull_schema.chats (
    chat_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS seagull_schema.chat_users (
    chat_id INT REFERENCES seagull_schema.chats(chat_id) ON DELETE CASCADE,
    user_id INT REFERENCES seagull_schema.users(user_id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (chat_id, user_id)
);

CREATE TABLE IF NOT EXISTS seagull_schema.actions (
    action_id SERIAL PRIMARY KEY,
    sender_id INT REFERENCES seagull_schema.users(user_id) ON DELETE CASCADE,
    message_id INT REFERENCES seagull_schema.messages(message_id) ON DELETE CASCADE,
    chat_id INT REFERENCES seagull_schema.chats(chat_id) ON DELETE CASCADE
);
```

---

### Особенности
- **Приватные чаты**: Создаются автоматически при первом сообщении между двумя пользователями
- **Групповые чаты**: Создаются явно и могут содержать несколько участников
- **Каскадное удаление**: При удалении пользователя удаляются все его сообщения и записи о участии в чатах