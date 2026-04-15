# Seagull Messenger

Учебный проект мессенджера на C++20 с использованием userver и PostgreSQL.
Проект выполнен студентами НИУ ВШЭ СПб, факультет "Прикладная математика и информатика".

## Участники проекта

- [Габдрахманов Радмир](https://github.com/453254)
- [Михальченко Игорь](https://github.com/Kw1ft)
- [Пименов Арсений](https://github.com/nihilmori)

## Быстрый старт

```bash
make build-debug
make run-debug
make test-debug
```

Сервис поднимается на `8080`.

Проверка ответа:

```bash
curl -i http://127.0.0.1:8080/ping
```

## Документация

- [Как собирать и запускать](docs/run.md)
- [Подробное API](docs/api.md)
- [Структура БД](docs/database.md)

## Стек

- C++20
- userver
- PostgreSQL
- CMake + Ninja
- Python testsuite

## Структура проекта

- `src/` — хендлеры и вспомогательная логика
- `configs/` — конфигурация userver
- `postgresql/schemas/` — SQL-схемы
- `tests/` — тесты
- `docs/` — документация проекта

```
seagull-messenger/
├── .clang-format
├── .devcontainer/
│   ├── devcontainer.json
│   └── README.md
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── ci.yml
│       └── docker.yaml
├── .gitignore
├── cmake/
│   ├── DownloadUserver.cmake
│   └── get_cpm.cmake
├── CMakeLists.txt
├── CMakePresets.json
├── configs/
│   ├── config_vars.testing.yaml
│   ├── config_vars.yaml
│   └── static_config.yaml
├── docs/
│   ├── api.md
│   ├── database.md
│   ├── run.md
│   └── 2026-04-15 15.01.05(1).jpg
├── Makefile
├── postgresql/
│   ├── data/
│   │   └── initial_data.sql
│   └── schemas/
│       └── db_1.sql
├── README.md
├── requirements.txt
├── run_as_user.sh
├── src/
│   ├── add_user_to_chat_handler.cpp
│   ├── add_user_to_chat_handler.hpp
│   ├── create_group_chat_handler.cpp
│   ├── create_group_chat_handler.hpp
│   ├── edit_message_handler.cpp
│   ├── edit_message_handler.hpp
│   ├── get_chat_info_handler.cpp
│   ├── get_chat_info_handler.hpp
│   ├── get_chats_handler.cpp
│   ├── get_chats_handler.hpp
│   ├── get_messages_handler.cpp
│   ├── get_messages_handler.hpp
│   ├── get_user_profile_handler.cpp
│   ├── get_user_profile_handler.hpp
│   ├── leave_chat_handler.cpp
│   ├── leave_chat_handler.hpp
│   ├── login_handler.cpp
│   ├── login_handler.hpp
│   ├── main.cpp
│   ├── register_handler.cpp
│   ├── register_handler.hpp
│   ├── remove_user_from_chat_handler.cpp
│   ├── remove_user_from_chat_handler.hpp
│   ├── search_users_handler.cpp
│   ├── search_users_handler.hpp
│   ├── send_message_handler.cpp
│   ├── send_message_handler.hpp
│   ├── update_chat_handler.cpp
│   ├── update_chat_handler.hpp
│   ├── update_user_handler.cpp
│   ├── update_user_handler.hpp
│   ├── utils_handler.cpp
│   └── utils_handler.hpp
└── tests/
    ├── conftest.py
    ├── pytest.ini
    └── test_api.py
```