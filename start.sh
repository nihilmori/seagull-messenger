
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_BIN="$ROOT/build-debug/myservice"
CLIENT_BIN="$ROOT/client/build-debug/appSeagullClient"
SERVER_LOG="${SEAGULL_SERVER_LOG:-/tmp/seagull-server.log}"
CLIENT_LOG="${SEAGULL_CLIENT_LOG:-/tmp/seagull-client.log}"
QML_PATH="${QML_IMPORT_PATH:-/usr/lib/aarch64-linux-gnu/qt6/qml}"

log()  { printf '\033[1;34m[start]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; exit 1; }

if ! ss -tln 2>/dev/null | grep -q '127.0.0.1:5432'; then
    die "PostgreSQL не слушает 127.0.0.1:5432. Запусти его и повтори."
fi

if [[ ! -x "$SERVER_BIN" ]]; then
    log "Сервер не собран, собираю (make build-debug)..."
    make -C "$ROOT" build-debug
fi

if ss -tln 2>/dev/null | grep -q '127.0.0.1:8080'; then
    warn "Порт 8080 уже занят — считаю, что сервер уже запущен."
    SERVER_PID=""
else
    log "Запускаю сервер, лог: $SERVER_LOG"
    "$SERVER_BIN" \
        --config "$ROOT/configs/static_config.yaml" \
        --config_vars "$ROOT/configs/config_vars.yaml" \
        >"$SERVER_LOG" 2>&1 &
    SERVER_PID=$!

    for _ in {1..30}; do
        if curl -fs -o /dev/null http://127.0.0.1:8080/ping; then
            log "Сервер готов (PID $SERVER_PID)."
            break
        fi
        sleep 0.5
    done
    if ! curl -fs -o /dev/null http://127.0.0.1:8080/ping; then
        die "Сервер не ответил на /ping. Смотри $SERVER_LOG"
    fi
fi

if [[ ! -x "$CLIENT_BIN" ]]; then
    log "Клиент не собран, собираю (make build-debug в client/)..."
    make -C "$ROOT/client" build-debug
fi

cleanup() {
    if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log "stop server (PID $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

log "client started, log: $CLIENT_LOG"
QML_IMPORT_PATH="$QML_PATH" "$CLIENT_BIN" >"$CLIENT_LOG" 2>&1
