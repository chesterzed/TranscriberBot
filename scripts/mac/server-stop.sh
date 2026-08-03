#!/usr/bin/env bash
# Остановка локального telegram-bot-api сервера по PID из logs/tg-bot-api.pid.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

pid="$(tg_api_pid)"
if [ -z "$pid" ]; then
    echo "Сервер telegram-bot-api не запущен."
    rm -f "$TG_API_PID_FILE"
    exit 0
fi

echo "Останавливаю сервер (PID $pid)..."
kill "$pid" 2>/dev/null || true

for _ in $(seq 1 10); do
    [ -z "$(tg_api_pid)" ] && break
    sleep 1
done
if [ -n "$(tg_api_pid)" ]; then
    echo "Процесс не завершился, отправляю SIGKILL..."
    kill -9 "$pid" 2>/dev/null || true
fi

rm -f "$TG_API_PID_FILE"
echo "Сервер остановлен."
