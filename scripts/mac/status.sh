#!/usr/bin/env bash
# Статус бота: запущен или нет.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

pid="$(bot_pid)"
if [ -n "$pid" ]; then
    echo "Бот РАБОТАЕТ (PID $pid)."
    echo "Логи: $LOG_FILE"
else
    echo "Бот ОСТАНОВЛЕН."
fi
