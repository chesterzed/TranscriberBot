# Статус бота: запущен или нет.
. "$PSScriptRoot\_common.ps1"

$proc = Get-BotProcess
if ($proc) {
    Write-Host "Бот РАБОТАЕТ (PID $($proc.Id))." -ForegroundColor Green
    Write-Host "Логи: $LogFile"
} else {
    Write-Host "Бот ОСТАНОВЛЕН." -ForegroundColor Yellow
}
