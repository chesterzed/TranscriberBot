# Запуск бота в фоне. PID пишется в logs\bot.pid, вывод — в logs\bot.log.
. "$PSScriptRoot\_common.ps1"

$existing = Get-BotProcess
if ($existing) {
    Write-Host "Бот уже запущен (PID $($existing.Id))." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

Write-Host "Запуск бота ($Python bot.py)..." -ForegroundColor Cyan

$proc = Start-Process -FilePath $Python `
    -ArgumentList "bot.py" `
    -WorkingDirectory $ProjectRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError $ErrFile `
    -PassThru

$proc.Id | Out-File -FilePath $PidFile -Encoding ascii

Start-Sleep -Seconds 2
if ($proc.HasExited) {
    Write-Host "Бот завершился сразу после старта. Смотрите $ErrFile" -ForegroundColor Red
    Remove-Item $PidFile -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "Бот запущен (PID $($proc.Id)). Логи: $LogFile" -ForegroundColor Green
