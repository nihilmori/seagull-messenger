# How to Run

Ниже описан локальный запуск сервиса из корня репозитория.

## Сборка

```bash
make build-debug
```

Что делает команда:

- запускает CMake-конфигурацию для `debug`
- генерирует файлы сборки в `build-debug/`
- компилирует бинарник сервиса `myservice`

## Запуск

```bash
make run-debug
```

Что делает команда:

- запускает `./build-debug/myservice`
- передаёт конфиги `configs/static_config.yaml` и `configs/config_vars.yaml`
- поднимает HTTP-сервер на порту `8080`

## Проверка

```bash
curl -i http://127.0.0.1:8080/ping
```

Команда отправляет healthcheck-запрос и показывает, что сервер отвечает.

## Тесты

```bash
make test-debug
```

Что делает команда:

- собирает проект в `debug`
- запускает тесты через `ctest`