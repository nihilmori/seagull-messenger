DROP SCHEMA IF EXISTS seagull_schema CASCADE;

CREATE SCHEMA IF NOT EXISTS seagull_schema;

CREATE TABLE IF NOT EXISTS seagull_schema.users (
    user_id SERIAL PRIMARY KEY,
    login VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    name VARCHAR(100) NOT NULL,
    bio TEXT
);

CREATE TABLE IF NOT EXISTS seagull_schema.messages (
    message_id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    send_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS seagull_schema.actions (
    action_id SERIAL PRIMARY KEY,
    sender_id INT REFERENCES seagull_schema.users(user_id) ON DELETE CASCADE,
    message_id INT REFERENCES seagull_schema.messages(message_id) ON DELETE CASCADE,
    chat_id INT REFERENCES seagull_schema.chats(chat_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS seagull_schema.chats (
    chat_id SERIAL PRIMARY KEY,
    chat_name VARCHAR(100) NOT NULL,
    is_private BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS seagull_schema.users_chats (
    chat_id INT REFERENCES seagull_schema.chats(chat_id) ON DELETE CASCADE,
    user_id INT REFERENCES seagull_schema.users(user_id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (chat_id, user_id)
);