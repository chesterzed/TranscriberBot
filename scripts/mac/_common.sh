#!/usr/bin/env bash
# Общие пути и хелперы для управления ботом на macOS.
# Подключается через: source "$(dirname "$0")/_common.sh"

# Корень проекта = на два уровня выше этого файла (scripts/mac/..)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LOG_DIR="$PROJECT_ROOT/logs"
PID_FILE="$LOG_DIR/bot.pid"
LOG_FILE="$LOG_DIR/bot.log"
ERR_FILE="$LOG_DIR/bot.err.log"

# Python из .venv, если есть; иначе системный python3.
if [ -x "$PROJECT_ROOT/.venv/bin/python" ]; then
    PYTHON="$PROJECT_ROOT/.venv/bin/python"
else
    PYTHON="python3"
fi

# Возвращает PID живого процесса бота (echo) или пусто.
bot_pid() {
    [ -f "$PID_FILE" ] || return 0
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$pid" ] || return 0
    if kill -0 "$pid" 2>/dev/null; then
        echo "$pid"
    fi
}
