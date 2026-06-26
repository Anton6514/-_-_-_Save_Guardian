# backup_loop.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$GameExecutablePath,

    [Parameter(Mandatory=$true)]
    [string]$SaveDirPath,

    [Parameter(Mandatory=$true)]
    [string]$BackupDirPath,

    [int]$IntervalSeconds = 3600,
    [int]$MaxSlots = 12
)

Write-Host "[PS-BACKUP-LOOP] Starting backup loop." -ForegroundColor Cyan
Write-Host "[PS-BACKUP-LOOP] Game Executable: $GameExecutablePath"
Write-Host "[PS-BACKUP-LOOP] Save Directory: $SaveDirPath"
Write-Host "[PS-BACKUP-LOOP] Backup Directory: $BackupDirPath"
Write-Host "[PS-BACKUP-LOOP] Interval (seconds): $IntervalSeconds"
Write-Host "[PS-BACKUP-LOOP] Max Slots: $MaxSlots"

# Получаем имя исполняемого файла игры для проверки процесса
$GameProcessName = [System.IO.Path]::GetFileNameWithoutExtension($GameExecutablePath)
Write-Host "[PS-BACKUP-LOOP] Game Process Name to Monitor: $GameProcessName"

while ($true) {
    # Проверяем, запущена ли игра
    $GameProcess = Get-Process -Name $GameProcessName -ErrorAction SilentlyContinue

    if ($null -eq $GameProcess) {
        Write-Host "[PS-BACKUP-LOOP] Game process '$GameProcessName' not found. Exiting backup loop." -ForegroundColor Yellow
        break
    }

    Write-Host "[PS-BACKUP-LOOP] Game process '$GameProcessName' is running." -ForegroundColor Green

    # --- СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ ---
    Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') Backup attempt initiated." -ForegroundColor DarkGreen

    # Проверяем существование папки сохранений
    if (Test-Path -Path $SaveDirPath -PathType Container) {
        Write-Host "[PS-BACKUP-LOOP] Source directory confirmed to exist: $SaveDirPath"

        # Генерируем имя целевой папки с временной меткой
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $TargetSlotName = "Save_Backup_$Timestamp"
        $TargetPath = Join-Path -Path $BackupDirPath -ChildPath $TargetSlotName

        Write-Host "[PS-BACKUP-LOOP] Generated backup slot directory: $TargetPath"

        try {
            # Создаём целевую папку
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null

            Write-Host "[PS-BACKUP-LOOP] Copying files from '$SaveDirPath' to '$TargetPath'..."
            # Используем Copy-Item для копирования содержимого
            # -Recurse - рекурсивно
            # -Force - копирует скрытые и системные файлы
            # -ErrorAction Stop - прерывает try при ошибке
            Copy-Item -Path "$SaveDirPath\*" -Destination $TargetPath -Recurse -Force -ErrorAction Stop

            Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') SUCCESS: Backup completed to $TargetPath" -ForegroundColor Green
        } catch {
            Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') ERROR: Failed to copy files. $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') WARNING: Source save directory '$SaveDirPath' does not exist or is empty. Skipping backup." -ForegroundColor Yellow
    }

    # --- УПРАВЛЕНИЕ КОЛИЧЕСТВОМ СЛОТОВ ---
    Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') Checking for old backup slots to manage rotation (Max Slots: $MaxSlots)." -ForegroundColor Magenta

    $AllBackupSlots = Get-ChildItem -Path $BackupDirPath -Directory -Name "Save_Backup_*" -ErrorAction SilentlyContinue | Sort-Object

    if ($null -ne $AllBackupSlots) {
        $TotalSlots = $AllBackupSlots.Count
        Write-Host "[PS-BACKUP-LOOP] Found $TotalSlots backup slot(s) matching pattern." -ForegroundColor Magenta

        if ($TotalSlots -gt $MaxSlots) {
            $SlotsToDelete = $TotalSlots - $MaxSlots
            Write-Host "[PS-BACKUP-LOOP] Found $TotalSlots slots, maximum allowed is $MaxSlots. Need to delete $SlotsToDelete oldest slot(s)." -ForegroundColor Magenta

            $AllBackupSlots | Select-Object -First $SlotsToDelete | ForEach-Object {
                $SlotToDelete = Join-Path -Path $BackupDirPath -ChildPath $_
                Write-Host "[PS-BACKUP-LOOP] Marked old slot for deletion: $SlotToDelete" -ForegroundColor Magenta

                try {
                    Write-Host "[PS-BACKUP-LOOP] Attempting to delete: $SlotToDelete"
                    Remove-Item -Path $SlotToDelete -Recurse -Force -ErrorAction Stop
                    Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') SUCCESS: Old slot deleted: $_" -ForegroundColor Green
                } catch {
                    Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') ERROR: Failed to delete old slot $SlotToDelete. $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "[PS-BACKUP-LOOP] Number of slots ($TotalSlots) is within limit ($MaxSlots). No deletion needed." -ForegroundColor Magenta
        }
    } else {
        Write-Host "[PS-BACKUP-LOOP] No backup slots found matching pattern 'Save_Backup_*'." -ForegroundColor Magenta
    }

    # --- ОЖИДАНИЕ ---
    Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') Starting wait cycle for $IntervalSeconds seconds." -ForegroundColor Blue
    Start-Sleep -Seconds $IntervalSeconds
    Write-Host "[PS-BACKUP-LOOP] $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss,ff') Wait cycle finished." -ForegroundColor Blue
}

Write-Host "[PS-BACKUP-LOOP] Backup loop ended." -ForegroundColor Cyan