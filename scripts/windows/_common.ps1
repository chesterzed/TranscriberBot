# Общие пути и хелперы для скриптов управления ботом.
# Подключается через: . "$PSScriptRoot\_common.ps1"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir      = Join-Path $ProjectRoot "logs"
$PidFile     = Join-Path $LogDir "bot.pid"
$LogFile     = Join-Path $LogDir "bot.log"
$ErrFile     = Join-Path $LogDir "bot.err.log"

# Python из виртуального окружения (.venv или venv), если есть; иначе системный python.
$VenvDotPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$VenvPython    = Join-Path $ProjectRoot "venv\Scripts\python.exe"
if (Test-Path $VenvDotPython) {
    $Python = $VenvDotPython
} elseif (Test-Path $VenvPython) {
    $Python = $VenvPython
} else {
    $Python = "python"
}

function Get-BotProcess {
    # Возвращает объект процесса бота, если он жив; иначе $null.
    if (-not (Test-Path $PidFile)) { return $null }
    $botPid = (Get-Content $PidFile -Raw).Trim()
    if (-not $botPid) { return $null }
    try {
        return Get-Process -Id ([int]$botPid) -ErrorAction Stop
    } catch {
        return $null  # PID-файл устарел (процесс уже мёртв)
    }
}
