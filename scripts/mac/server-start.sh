#!/usr/bin/env bash
# Запуск локального telegram-bot-api сервера в фоне.
# Параметры берутся из .env: TELEGRAM_API_ID/HASH/BIN/PORT/DIR.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

existing="$(tg_api_pid)"
if [ -n "$existing" ]; then
    echo "Сервер telegram-bot-api уже запущен (PID $existing)."
    exit 0
fi

API_ID="$(read_env TELEGRAM_API_ID)"
API_HASH="$(read_env TELEGRAM_API_HASH)"
BIN="$(read_env TELEGRAM_BOT_API_BIN)"
PORT="$(read_env TELEGRAM_BOT_API_PORT)"
DIR="$(read_env TELEGRAM_BOT_API_DIR)"

: "${PORT:=8081}"
: "${BIN:=./telegram-bot-api/bin/telegram-bot-api}"
: "${DIR:=./tg-bot-api-files}"

if [ -z "$API_ID" ] || [ -z "$API_HASH" ]; then
    echo "Ошибка: в .env не заданы TELEGRAM_API_ID и/или TELEGRAM_API_HASH."
    echo "Получите их на https://my.telegram.org (API development tools)."
    exit 1
fi

# Относительные пути — от корня проекта
case "$BIN" in /*) ;; *) BIN="$PROJECT_ROOT/$BIN" ;; esac
case "$DIR" in /*) ;; *) DIR="$PROJECT_ROOT/$DIR" ;; esac

if [ ! -x "$BIN" ]; then
    echo "Ошибка: бинарник сервера не найден или не исполняемый: $BIN"
    echo "Соберите telegram-bot-api из исходников (см. README) и/или укажите TELEGRAM_BOT_API_BIN."
    exit 1
fi

mkdir -p "$LOG_DIR" "$DIR"

echo "Запуск telegram-bot-api (порт $PORT, файлы в $DIR)..."
nohup "$BIN" --local \
    --api-id="$API_ID" \
    --api-hash="$API_HASH" \
    --http-port="$PORT" \
    --dir="$DIR" \
    >>"$TG_API_LOG_FILE" 2>>"$TG_API_ERR_FILE" &
echo $! > "$TG_API_PID_FILE"

sleep 2
running="$(tg_api_pid)"
if [ -z "$running" ]; then
    echo "Сервер завершился сразу после старта. Смотрите $TG_API_ERR_FILE"
    rm -f "$TG_API_PID_FILE"
    exit 1
fi

echo "Сервер запущен (PID $running). Логи: $TG_API_LOG_FILE"
echo "В .env бота укажите:"
echo "  TELEGRAM_API_BASE_URL=http://127.0.0.1:$PORT/bot"
echo "  TELEGRAM_API_BASE_FILE_URL=http://127.0.0.1:$PORT/file/bot"
echo "  TELEGRAM_LOCAL_MODE=true"
