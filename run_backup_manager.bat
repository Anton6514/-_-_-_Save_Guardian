@echo off
setlocal

:: Путь к PowerShell-скрипту. Предполагается, что он находится в той же папке, что и .bat файл.
set "PS_SCRIPT=start_game_and_backup.ps1"

echo Launching PowerShell backup manager...
:: Запускаем PowerShell, указывая ему выполнить наш скрипт.
:: -ExecutionPolicy Bypass позволяет обойти политику выполнения скриптов (если она мешает).
:: -File указывает путь к скрипту.
powershell -ExecutionPolicy Bypass -File "%~dp0%PS_SCRIPT%"

:: Проверим, завершился ли PowerShell успешно (необязательно)
if %errorlevel% neq 0 (
    echo An error occurred in the PowerShell script (ERRORLEVEL: %errorlevel%).
    pause
)

echo Script execution finished.
pause