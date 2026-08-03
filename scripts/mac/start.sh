#!/usr/bin/env bash
# Запуск бота в фоне. PID -> logs/bot.pid, вывод -> logs/bot.log, ошибки -> logs/bot.err.log
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

existing="$(bot_pid)"
if [ -n "$existing" ]; then
    echo "Бот уже запущен (PID $existing)."
    exit 0
fi

mkdir -p "$LOG_DIR"

activate_venv

echo "Запуск бота ($PYTHON bot.py)..."
cd "$PROJECT_ROOT"
nohup "$PYTHON" bot.py >>"$LOG_FILE" 2>>"$ERR_FILE" &
echo $! > "$PID_FILE"

sleep 2
running="$(bot_pid)"
if [ -z "$running" ]; then
    echo "Бот завершился сразу после старта. Смотрите $ERR_FILE"
    rm -f "$PID_FILE"
    exit 1
fi

echo "Бот запущен (PID $running). Логи: $LOG_FILE"
