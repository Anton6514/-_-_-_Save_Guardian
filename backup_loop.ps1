# backup_loop.ps1
# Фоновый скрипт для периодического резервного копирования папки сохранений.
# Запускается из start_game_and_backup.ps1. Не предназначен для самостоятельного запуска.

param(
    # Путь к исполняемому файлу игры (.exe). Передаётся из основного скрипта.
    [Parameter(Mandatory=$true)]
    [string]$GameExecutablePath,

    # Путь к папке с сохранениями игры. Передаётся из основного скрипта.
    [Parameter(Mandatory=$true)]
    [string]$SaveDirPath,

    # Папка, куда сохраняются резервные копии. Передаётся из основного скрипта.
    [Parameter(Mandatory=$true)]
    [string]$BackupDirPath,

    # Интервал между бэкапами в секундах. По умолчанию 3600 (1 час).
    # Изменяется в основном скрипте start_game_and_backup.ps1.
    [int]$IntervalSeconds = 3600,

    # Максимальное количество слотов (папок) с бэкапами. Старые удаляются.
    # По умолчанию 12. Изменяется в основном скрипте.
    [int]$MaxSlots = 12
)

# --- ЛОГГИРОВАНИЕ (только в консоль) ---
# Функция Write-Log теперь только выводит в Host
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry -ForegroundColor $(if($Level -eq "ERROR"){ "Red" } elseif($Level -eq "WARN"){ "Yellow" } else { "Gray" })
    # Запись в файл УДАЛЕНА
}

Write-Host "[PS-BACKUP-LOOP] Starting backup loop for '$([System.IO.Path]::GetFileNameWithoutExtension($GameExecutablePath))'."
Write-Host "Interval: $IntervalSeconds s, Max Slots: $MaxSlots"

# Получаем имя исполняемого файла игры для проверки процесса
$GameProcessName = [System.IO.Path]::GetFileNameWithoutExtension($GameExecutablePath)

# --- ФАЗА ОЖИДАНИЯ ПРОЦЕССА ИГРЫ ---
Write-Host "[PS-BACKUP-LOOP] Waiting for game process '$GameProcessName' to appear..."
do {
    Start-Sleep -Seconds 1 # Ждём 1 секунду перед следующей проверкой
    $GameProcess = Get-Process -Name $GameProcessName -ErrorAction SilentlyContinue
    if ($null -ne $GameProcess) {
        Write-Host "[PS-BACKUP-LOOP] Game process '$GameProcessName' found (PID: $($GameProcess.Id)). Starting backup loop."
    } else {
        # Убираем подробный лог ожидания
    }
} while ($null -eq $GameProcess)

# --- ЦИКЛ РЕЗЕРВНОГО КОПИРОВАНИЯ ---
Write-Host "[PS-BACKUP-LOOP] Backup loop started. Press Ctrl+C if needed (though script handles game closure)."
while ($true) {
    # Проверяем, запущена ли игра (делаем это в начале каждой итерации)
    try {
        $GameProcess = Get-Process -Name $GameProcessName -ErrorAction Stop
        # Не выводим постоянно, что процесс запущен
    } catch {
        # Если процесс не найден, выходим из цикла и завершаем скрипт
        Write-Host "[PS-BACKUP-LOOP] Game process '$GameProcessName' not found. Exiting backup loop." -ForegroundColor Yellow
        break # Это прерывает цикл while ($true)
    }

    # --- СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ ---
    Write-Host "$(Get-Date -Format 'HH:mm:ss') Backup started." -ForegroundColor Green

    # Проверяем существование папки сохранений
    if (Test-Path -Path $SaveDirPath -PathType Container) {
        # Генерируем имя целевой папки с временной меткой
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $TargetSlotName = "Save_Backup_$Timestamp"
        $TargetPath = Join-Path -Path $BackupDirPath -ChildPath $TargetSlotName

        try {
            # Создаём целевую папку
            New-Item -ItemType Directory -Path $TargetPath -Force -ErrorVariable CreateDirError -ErrorAction SilentlyContinue | Out-Null
            if ($CreateDirError) {
                throw $CreateDirError[0].Exception
            }

            # Используем Copy-Item для копирования содержимого
            Copy-Item -Path "$SaveDirPath\*" -Destination $TargetPath -Recurse -Force -ErrorVariable CopyError -ErrorAction Stop

            Write-Host "$(Get-Date -Format 'HH:mm:ss') Backup completed to $TargetPath" -ForegroundColor Green
        } catch {
            Write-Host "$(Get-Date -Format 'HH:mm:ss') ERROR: Failed to copy files. $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') WARNING: Source save directory '$SaveDirPath' does not exist or is empty. Skipping backup." -ForegroundColor Yellow
    }

    # --- УПРАВЛЕНИЕ КОЛИЧЕСТВОМ СЛОТОВ ---
    $AllBackupSlots = Get-ChildItem -Path $BackupDirPath -Directory -Name "Save_Backup_*" -ErrorAction SilentlyContinue | Sort-Object

    if ($null -ne $AllBackupSlots) {
        $TotalSlots = $AllBackupSlots.Count
        if ($TotalSlots -gt $MaxSlots) {
            $SlotsToDelete = $TotalSlots - $MaxSlots
            $AllBackupSlots | Select-Object -First $SlotsToDelete | ForEach-Object {
                $SlotToDelete = Join-Path -Path $BackupDirPath -ChildPath $_
                try {
                    Remove-Item -Path $SlotToDelete -Recurse -Force -ErrorVariable DeleteError -ErrorAction Stop
                    Write-Host "$(Get-Date -Format 'HH:mm:ss') Old slot deleted: $_" -ForegroundColor Yellow
                } catch {
                    Write-Host "$(Get-Date -Format 'HH:mm:ss') ERROR: Failed to delete old slot $SlotToDelete. $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }

    # --- ОЖИДАНИЕ ---
    # Выводим короткое сообщение перед ожиданием
    Write-Host "$(Get-Date -Format 'HH:mm:ss') Next backup in $IntervalSeconds seconds..." -ForegroundColor Gray
    Start-Sleep -Seconds $IntervalSeconds
    # Цикл продолжается с начала: проверка процесса -> бэкап -> управление слотами -> ожидание
}

Write-Host "[PS-BACKUP-LOOP] Backup loop ended." -ForegroundColor Cyan

# Конец скрипта backup_loop.ps1