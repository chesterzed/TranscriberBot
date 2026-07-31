# Остановка бота по PID из logs\bot.pid.
. "$PSScriptRoot\_common.ps1"

$proc = Get-BotProcess
if (-not $proc) {
    Write-Host "Бот не запущен." -ForegroundColor Yellow
    Remove-Item $PidFile -ErrorAction SilentlyContinue
    exit 0
}

Write-Host "Останавливаю бота (PID $($proc.Id))..." -ForegroundColor Cyan
Stop-Process -Id $proc.Id -Force

# Ждём завершения процесса (до 10 секунд)
for ($i = 0; $i -lt 10; $i++) {
    if (-not (Get-BotProcess)) { break }
    Start-Sleep -Seconds 1
}

Remove-Item $PidFile -ErrorAction SilentlyContinue
Write-Host "Бот остановлен." -ForegroundColor Green
