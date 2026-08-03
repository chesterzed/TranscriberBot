#!/usr/bin/env bash
# Статус локального telegram-bot-api сервера.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

pid="$(tg_api_pid)"
if [ -n "$pid" ]; then
    echo "Сервер telegram-bot-api РАБОТАЕТ (PID $pid)."
    echo "Логи: $TG_API_LOG_FILE"
else
    echo "Сервер telegram-bot-api ОСТАНОВЛЕН."
fi
