@echo off
:: Отключаем отображение команд в консоли для чистоты вывода.
setlocal EnableDelayedExpansion
:: Включаем возможность использовать переменные (!variable!) внутри циклов и условий.

:: --- НАСТРОЙКА ПАРАМЕТРОВ ---
:: Настройте пути здесь:
set "GAME_SAVE_DIR=C:\Users\Антон\AppData\Local\G1R"  REM Путь к папке, где игра хранит сохранения. Обычно C:\Users\[Имя_Пользователя]\AppData\Local\G1R\Saved\SaveGames\
set "BACKUP_BASE_DIR=C:\Users\Антон\AppData\Local\G1R\Gothic Backup"                           REM Базовая папка на вашем компьютере для хранения резервных копий.
set "GAME_EXE_PATH=D:\Games\Gothic.1.Remake-InsaneRamZes\Gothic.1.Remake-InsaneRamZes\G1R-Win64-Shipping.exe"                                 REM Полный путь к .exe файлу игры, который запускает саму игру.

REM --- ПРОВЕРКА И СОЗДАНИЕ ПАПКИ БЕКАПА ---
REM Проверяем, существует ли папка для бекапов. Если нет, создаём её.
if not exist "!BACKUP_BASE_DIR!" mkdir "!BACKUP_BASE_DIR!"

echo Запуск резервного скрипта...
REM Запускаем второй скрипт (backup_loop.bat) в свёрнутом виде (/min) в фоне.
REM Передаём ему пути к исполняемому файлу игры, папке сохранений и папке бекапа как аргументы.
start "" /min backup_loop.bat "!GAME_EXE_PATH!" "!GAME_SAVE_DIR!" "!BACKUP_BASE_DIR!"

REM Дадим немного времени фоновому скрипту на старт.
timeout /t 2 /nobreak >nul

echo Запуск игры Gothic Remake...
REM Запускаем саму игру.
start "" "!GAME_EXE_PATH!"

echo Ожидание закрытия игры...
:wait_for_game_close
:: Цикл ожидания закрытия игры.
:: tasklist показывает список запущенных процессов.
:: /FI "IMAGENAME eq %~nx1" фильтрует список, показывая только процессы с именем файла, как у GAME_EXE_PATH (%~nx1 берёт имя файла с расширением из %1).
:: find проверяет, есть ли вывод от tasklist (то есть, запущена ли игра).
tasklist /FI "IMAGENAME eq %~nx1" 2>NUL | find /I /N "%~nx1">NUL
if "%ERRORLEVEL%"=="0" (
    :: ERRORLEVEL 0 означает, что find нашёл совпадение -> игра всё ещё запущена.
    timeout /t 5 /nobreak >nul  REM Ждём 5 секунд перед следующей проверкой, чтобы не нагружать систему.
    goto :wait_for_game_close  REM Возвращаемся к началу цикла проверки.
)
:: Если мы дошли сюда, find не нашёл процесс игры (ERRORLEVEL != 0).
echo Игра закрыта. Завершаем резервное копирование...
:: Ищем и принудительно завершаем процесс backup_loop.bat по заголовку окна (он задаётся в том скрипте).
:: 2>nul >nul подавляет возможные ошибки, если процесс уже закрылся.
taskkill /f /fi "WINDOWTITLE eq GothicBackupLoop*" 2>nul >nul
echo Скрипт резервного копирования остановлен.
pause  REM Пауза, чтобы пользователь увидел сообщение перед закрытием окна.