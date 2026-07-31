#!/usr/bin/env bash
# Остановка бота по PID из logs/bot.pid.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

pid="$(bot_pid)"
if [ -z "$pid" ]; then
    echo "Бот не запущен."
    rm -f "$PID_FILE"
    exit 0
fi

echo "Останавливаю бота (PID $pid)..."
kill "$pid" 2>/dev/null || true

# Ждём мягкого завершения до 10 секунд, потом — принудительно.
for _ in $(seq 1 10); do
    [ -z "$(bot_pid)" ] && break
    sleep 1
done
if [ -n "$(bot_pid)" ]; then
    echo "Процесс не завершился, отправляю SIGKILL..."
    kill -9 "$pid" 2>/dev/null || true
fi

rm -f "$PID_FILE"
echo "Бот остановлен."
