# initial_backup.ps1
# Скрипт для создания начальной резервной копии папки сохранений.
# Запускается из start_game_and_backup.ps1. Не предназначен для самостоятельного запуска.

param(
    # Путь к папке с сохранениями игры. Передаётся из основного скрипта.
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    # Папка, куда сохраняется начальный бэкап. Передаётся из основного скрипта.
    [Parameter(Mandatory=$true)]
    [string]$TargetBasePath,

    # Максимальное количество слотов (папок) с бэкапами. Старые удаляются.
    # По умолчанию 12. Изменяется в основном скрипте start_game_and_backup.ps1.
    [int]$MaxSlots = 12
)

Write-Host "[PS-INIT-BACKUP] Starting initial backup process."
Write-Host "[PS-INIT-BACKUP] Source: $SourcePath"
Write-Host "[PS-INIT-BACKUP] Target Base: $TargetBasePath"
Write-Host "[PS-INIT-BACKUP] Max Slots: $MaxSlots"

# Проверяем существование исходной папки
if (-not (Test-Path -Path $SourcePath -PathType Container)) {
    Write-Host "[PS-INIT-BACKUP] ERROR: Source path does not exist or is not a directory: $SourcePath" -ForegroundColor Red
    exit 1
}

Write-Host "[PS-INIT-BACKUP] Source directory confirmed to exist."

# Генерируем имя целевой папки с временной меткой
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$TargetSlotName = "Save_Backup_Init_$Timestamp"  # Помечаем начальный бэкап префиксом Init
$TargetPath = Join-Path -Path $TargetBasePath -ChildPath $TargetSlotName

Write-Host "[PS-INIT-BACKUP] Target backup slot: $TargetPath"

try {
    # Создаём целевую папку
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null

    Write-Host "[PS-INIT-BACKUP] Copying files from '$SourcePath' to '$TargetPath'..."
    # Используем Copy-Item для копирования содержимого
    # -Recurse - рекурсивно
    # -Force - копирует скрытые и системные файлы
    # -ErrorAction Stop - прерывает try при ошибке
    Copy-Item -Path "$SourcePath\*" -Destination $TargetPath -Recurse -Force -ErrorAction Stop

    Write-Host "[PS-INIT-BACKUP] SUCCESS: Initial backup completed to $TargetPath" -ForegroundColor Green
} catch {
    Write-Host "[PS-INIT-BACKUP] ERROR: Failed to copy files. $_" -ForegroundColor Red
    exit 1
}

Write-Host "[PS-INIT-BACKUP] Backup creation finished."

# Управление количеством слотов (удаление старых)
# Проверяем ВСЕ бэкапы (включая начальные и обычные) в папке назначения
Write-Host "[PS-INIT-BACKUP] Managing backup slots (max $MaxSlots)..."
$AllSlots = Get-ChildItem -Path $TargetBasePath -Directory -Name "Save_Backup_*" | Sort-Object Name

$TotalSlots = $AllSlots.Count
Write-Host "[PS-INIT-BACKUP] Found $TotalSlots backup slot(s)."

if ($TotalSlots -gt $MaxSlots) {
    $SlotsToDelete = $TotalSlots - $MaxSlots
    Write-Host "[PS-INIT-BACKUP] Need to delete $SlotsToDelete oldest slot(s)."

    $AllSlots | Select-Object -First $SlotsToDelete | ForEach-Object {
        $SlotToDelete = Join-Path -Path $TargetBasePath -ChildPath $_
        Write-Host "[PS-INIT-BACKUP] Deleting old slot: $SlotToDelete"
        try {
            Remove-Item -Path $SlotToDelete -Recurse -Force -ErrorAction Stop
            Write-Host "[PS-INIT-BACKUP] SUCCESS: Deleted $SlotToDelete" -ForegroundColor Green
        } catch {
            Write-Host "[PS-INIT-BACKUP] ERROR: Could not delete $SlotToDelete. $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "[PS-INIT-BACKUP] Number of slots ($TotalSlots) is within limit ($MaxSlots). No deletion needed."
}

Write-Host "[PS-INIT-BACKUP] Slot management finished."