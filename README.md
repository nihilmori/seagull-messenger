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

