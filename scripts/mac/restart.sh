#!/usr/bin/env bash
# Перезапуск бота: остановка + запуск.
set -euo pipefail
DIR="$(dirname "${BASH_SOURCE[0]}")"
"$DIR/stop.sh"
sleep 1
"$DIR/start.sh"
