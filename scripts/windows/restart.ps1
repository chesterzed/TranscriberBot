# Перезапуск бота: остановка + запуск.
& "$PSScriptRoot\stop.ps1"
Start-Sleep -Seconds 1
& "$PSScriptRoot\start.ps1"
