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

# Локальный telegram-bot-api сервер
TG_API_PID_FILE="$LOG_DIR/tg-bot-api.pid"
TG_API_LOG_FILE="$LOG_DIR/tg-bot-api.log"
TG_API_ERR_FILE="$LOG_DIR/tg-bot-api.err.log"

# Достаёт одно значение из .env по ключу. Не используем `source`, т.к. в .env
# есть значения с пробелами (например, OLLAMA_SYSTEM_PROMPT).
read_env() {
    local key="$1"
    local envfile="$PROJECT_ROOT/.env"
    [ -f "$envfile" ] || return 0
    grep -E "^[[:space:]]*${key}=" "$envfile" | tail -1 | cut -d= -f2- \
        | sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Каталог виртуального окружения: .venv или venv (что найдётся первым).
if [ -d "$PROJECT_ROOT/.venv" ]; then
    VENV_DIR="$PROJECT_ROOT/.venv"
elif [ -d "$PROJECT_ROOT/venv" ]; then
    VENV_DIR="$PROJECT_ROOT/venv"
else
    VENV_DIR=""
fi

# Python из venv, если есть; иначе системный python3.
if [ -n "$VENV_DIR" ] && [ -x "$VENV_DIR/bin/python" ]; then
    PYTHON="$VENV_DIR/bin/python"
else
    PYTHON="python3"
fi

# Активирует venv перед запуском бота. source activate ссылается на unset-переменные
# (PS1 и т.п.), поэтому на время сорса снимаем `set -u`.
activate_venv() {
    if [ -n "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
        set +u
        # shellcheck disable=SC1091
        source "$VENV_DIR/bin/activate"
        set -u
        echo "Активировано окружение: $VENV_DIR"
    else
        echo "ВНИМАНИЕ: venv не найден (.venv или venv). Использую системный python3." >&2
    fi
}

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

# Возвращает PID живого процесса telegram-bot-api сервера или пусто.
tg_api_pid() {
    [ -f "$TG_API_PID_FILE" ] || return 0
    local pid
    pid="$(cat "$TG_API_PID_FILE" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$pid" ] || return 0
    if kill -0 "$pid" 2>/dev/null; then
        echo "$pid"
    fi
}
