DROP SCHEMA IF EXISTS seagull_schema CASCADE;

CREATE SCHEMA IF NOT EXISTS seagull_schema;

CREATE TABLE IF NOT EXISTS seagull_schema.users (
    user_id SERIAL PRIMARY KEY,
    login VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name VARCHAR(100) NOT NULL CHECK (char_length(btrim(name)) > 0)
);

CREATE TABLE IF NOT EXISTS seagull_schema.messages (
    message_id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS seagull_schema.actions (
    action_id SERIAL PRIMARY KEY,
    sender_id INT REFERENCES seagull_schema.users(user_id) ON DELETE CASCADE,
    message_id INT REFERENCES seagull_schema.messages(message_id) ON DELETE CASCADE,
    chat_id INT DEFAULT 0
);