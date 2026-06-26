# start_game_and_backup.ps1
# Основной скрипт для запуска игры и автоматического резервного копирования сохранений.
# Версия: 1.01

param(
    # Путь к исполняемому файлу игры (.exe). Укажите полный путь к вашему файлу .exe.
    [Parameter(Mandatory=$false)]
    [string]$GameExePath = "C:\Program Files (x86)\Steam\steamapps\common\YourGame\YourGame.exe",

    # Путь к папке, где игра хранит сохранения.
    # Обычно находится в C:\Users\[Ваше_Имя_Пользователя]\AppData\Local или LocalLow.
    # Для игр на Unreal Engine часто бывает в AppData\Local\Имя_Игры.
    # Замените 'YourUserName' и 'GameSaveFolderName' на свои.
    [Parameter(Mandatory=$false)]
    [string]$GameSaveDir = "C:\Users\YourUserName\AppData\Local\GameSaveFolderName",

    # Папка, куда будут сохраняться резервные копии.
    # Убедитесь, что на диске достаточно места.
    # Пример: D:\Backups\MyGameSaves
    [Parameter(Mandatory=$false)]
    [string]$BackupBaseDir = "D:\Backups\YourGameName",

    # Интервал между бэкапами в секундах.
    # 3600 = 1 час, 1800 = 30 минут, 7200 = 2 часа.
    [int]$IntervalSeconds = 3600, # Изменено на 1 час

    # Максимальное количество папок с бэкапами. Старые будут удаляться.
    # Рекомендуется оставить значение по умолчанию или установить по своему усмотрению.
    [int]$MaxSlots = 12 # Изменено на 12 слотов
)

# Проверим, существует ли исполняемый файл игры
if (-not (Test-Path -Path $GameExePath -PathType Leaf)) {
    Write-Host "ERROR: Game executable not found at path: $GameExePath"
    Read-Host "Press Enter to exit"
    exit 1
}

# Проверим, существует ли папка сохранений
if (-not (Test-Path -Path $GameSaveDir -PathType Container)) {
    Write-Host "WARNING: Game save directory not found at path: $GameSaveDir"
    # Можно спросить пользователя, хочет ли он продолжить или нет
    # $continue = Read-Host "Save directory does not exist. Continue anyway? (y/N)"
    # if ($continue -ne 'y' -and $continue -ne 'Y') { exit 1 }
}

# Проверим, существует ли папка бекапа, создадим, если нет
if (-not (Test-Path -Path $BackupBaseDir -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $BackupBaseDir -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "ERROR: Failed to create backup directory: $($_.Exception.Message)"
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# --- ЗАПУСК ФОНОВОГО СКРИПТА БЭКАПА ---
$BackupScriptPath = ".\backup_loop.ps1" # Убедитесь, что файл находится рядом с этим скриптом
if (Test-Path -Path $BackupScriptPath) {
    # ЗАПУСКАЕМ СКРИПТ ВИДИМЫМ (без -WindowStyle Hidden), чтобы видеть его вывод
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $BackupScriptPath, "-GameExecutablePath", $GameExePath, "-SaveDirPath", $GameSaveDir, "-BackupDirPath", $BackupBaseDir, "-IntervalSeconds", $IntervalSeconds, "-MaxSlots", $MaxSlots
} else {
    Write-Host "ERROR: Background backup script not found: $BackupScriptPath"
    Read-Host "Press Enter to exit"
    exit 1
}

# Дадим немного времени фоновому скрипту на старт
Start-Sleep -Seconds 2

# --- ЗАПУСК ИГРЫ ---
Start-Process -FilePath $GameExePath

# --- НАЧАЛЬНЫЙ БЭКАП ---
$InitialBackupScriptPath = ".\initial_backup.ps1" # Убедитесь, что файл находится рядом с этим скриптом
if (Test-Path -Path $InitialBackupScriptPath) {
    # Вызовем скрипт и дождёмся его завершения, сохраним результат
    $BackupResult = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $InitialBackupScriptPath, "-SourcePath", $GameSaveDir, "-TargetBasePath", $BackupBaseDir, "-MaxSlots", $MaxSlots -Wait -PassThru
    # Проверим результат выполнения initial_backup.ps1
    if ($BackupResult.ExitCode -ne 0) {
        Write-Host "WARNING: Initial backup script exited with code: $($BackupResult.ExitCode)"
        # Можно добавить Read-Host "Press Enter to continue anyway..." или просто продолжить
    }
    # Если ExitCode == 0, просто продолжаем
} else {
    Write-Host "ERROR: Initial backup script not found: $InitialBackupScriptPath"
    Read-Host "Press Enter to exit"
    exit 1
}

# --- ОЖИДАНИЕ ЗАКРЫТИЯ ИГРЫ ---
$GameProcessName = [System.IO.Path]::GetFileNameWithoutExtension($GameExePath)

# Ожидаем закрытия игры без подробного лога
do {
    Start-Sleep -Seconds 5
    $GameProcess = Get-Process -Name $GameProcessName -ErrorAction SilentlyContinue
} while ($null -ne $GameProcess)

# Закрытие игры обнаружено, завершаем работу