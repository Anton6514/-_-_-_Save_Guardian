# start_game_and_backup.ps1

param(
    [Parameter(Mandatory=$false)] # Теперь не обязательно указывать при вызове
    [string]$GameExePath = "D:\Games\Gothic.1.Remake-InsaneRamZes\Gothic.1.Remake-InsaneRamZes\G1R-Win64-Shipping.exe",

    [Parameter(Mandatory=$false)] # Теперь не обязательно указывать при вызове
    [string]$GameSaveDir = "C:\Users\Антон\AppData\Local\G1R",

    [Parameter(Mandatory=$false)] # Теперь не обязательно указывать при вызове
    [string]$BackupBaseDir = "D:\Games\Gothic.1.Remake-InsaneRamZes\Gothic.1.Remake-InsaneRamZes\Gothic_Save_Backup",

    [int]$IntervalSeconds = 3600, # Значение по умолчанию
    [int]$MaxSlots = 12          # Значение по умолчанию
)

Write-Host "[PS-MANAGER] === Starting Game and Backup Manager ===" -ForegroundColor Cyan

Write-Host "[PS-MANAGER] Game Executable Path: $GameExePath"
Write-Host "[PS-MANAGER] Game Save Directory: $GameSaveDir"
Write-Host "[PS-MANAGER] Backup Base Directory: $BackupBaseDir"
Write-Host "[PS-MANAGER] Backup Interval (seconds): $IntervalSeconds"
Write-Host "[PS-MANAGER] Max Backup Slots: $MaxSlots"

# Проверим, существует ли исполняемый файл игры
if (-not (Test-Path -Path $GameExePath -PathType Leaf)) {
    Write-Host "[PS-MANAGER] ERROR: Game executable not found at path: $GameExePath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Проверим, существует ли папка сохранений
if (-not (Test-Path -Path $GameSaveDir -PathType Container)) {
    Write-Host "[PS-MANAGER] WARNING: Game save directory not found at path: $GameSaveDir" -ForegroundColor Yellow
    # Можно спросить пользователя, хочет ли он продолжить или нет
    # $continue = Read-Host "Save directory does not exist. Continue anyway? (y/N)"
    # if ($continue -ne 'y' -and $continue -ne 'Y') { exit 1 }
}

# Проверим, существует ли папка бекапа, создадим, если нет
if (-not (Test-Path -Path $BackupBaseDir -PathType Container)) {
    Write-Host "[PS-MANAGER] Backup directory does not exist. Creating: $BackupBaseDir" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $BackupBaseDir -Force -ErrorAction Stop | Out-Null
        Write-Host "[PS-MANAGER] Backup directory created successfully." -ForegroundColor Green
    } catch {
        Write-Host "[PS-MANAGER] ERROR: Failed to create backup directory: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# --- ЗАПУСК ФОНОВОГО СКРИПТА БЭКАПА ---
Write-Host "[PS-MANAGER] Launching background backup script..." -ForegroundColor Green
$BackupScriptPath = ".\backup_loop.ps1" # Предполагаем, что файл рядом
if (Test-Path -Path $BackupScriptPath) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", $BackupScriptPath, "-GameExecutablePath", $GameExePath, "-SaveDirPath", $GameSaveDir, "-BackupDirPath", $BackupBaseDir, "-IntervalSeconds", $IntervalSeconds, "-MaxSlots", $MaxSlots
    Write-Host "[PS-MANAGER] Background backup script launched." -ForegroundColor Green
} else {
    Write-Host "[PS-MANAGER] ERROR: Background backup script not found: $BackupScriptPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Дадим немного времени фоновому скрипту на старт
Start-Sleep -Seconds 2

# --- ЗАПУСК ИГРЫ ---
Write-Host "[PS-MANAGER] Launching game: $GameExePath" -ForegroundColor Green
Start-Process -FilePath $GameExePath
Write-Host "[PS-MANAGER] Game launched." -ForegroundColor Green

# --- НАЧАЛЬНЫЙ БЭКАП ---
Write-Host "[PS-MANAGER] Executing initial backup..." -ForegroundColor Green
$InitialBackupScriptPath = ".\initial_backup.ps1" # Предполагаем, что файл рядом
if (Test-Path -Path $InitialBackupScriptPath) {
    # Вызовем скрипт и дождёмся его завершения
    $BackupResult = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $InitialBackupScriptPath, "-SourcePath", $GameSaveDir, "-TargetBasePath", $BackupBaseDir, "-MaxSlots", $MaxSlots -Wait -PassThru
    if ($BackupResult.ExitCode -eq 0) {
        Write-Host "[PS-MANAGER] Initial backup completed successfully." -ForegroundColor Green
    } else {
        Write-Host "[PS-MANAGER] Initial backup script exited with code: $($BackupResult.ExitCode)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[PS-MANAGER] ERROR: Initial backup script not found: $InitialBackupScriptPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# --- ОЖИДАНИЕ ЗАКРЫТИЯ ИГРЫ ---
$GameProcessName = [System.IO.Path]::GetFileNameWithoutExtension($GameExePath)
Write-Host "[PS-MANAGER] Waiting for game process '$GameProcessName' to close..." -ForegroundColor Yellow

do {
    Start-Sleep -Seconds 5
    $GameProcess = Get-Process -Name $GameProcessName -ErrorAction SilentlyContinue
    if ($null -ne $GameProcess) {
        Write-Host "[PS-MANAGER] Game process '$GameProcessName' is still running (PID: $($GameProcess.Id))." -ForegroundColor Gray
    } else {
        Write-Host "[PS-MANAGER] Game process '$GameProcessName' is no longer running." -ForegroundColor Yellow
    }
} while ($null -ne $GameProcess)

Write-Host "[PS-MANAGER] Game process '$GameProcessName' closed." -ForegroundColor Green

# --- ОСТАНОВКА ФОНОВОГО СКРИПТА БЭКАПА ---
Write-Host "[PS-MANAGER] Stopping background backup script..." -ForegroundColor Yellow
# Попробуем найти и завершить процесс PowerShell с backup_loop.ps1
$BackupProcesses = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*backup_loop.ps1*" -and $_.CommandLine -like "*$GameProcessName*" }
if ($BackupProcesses) {
    $BackupProcesses | ForEach-Object {
        Write-Host "[PS-MANAGER] Terminating backup process (PID: $($_.Id), CommandLine: $($_.CommandLine))" -ForegroundColor Red
        $_.Kill()
        $_.WaitForExit(1000) # Подождать до 1 секунды
        if (!$_.HasExited) {
            Write-Host "[PS-MANAGER] Forcefully terminating backup process (PID: $($_.Id))" -ForegroundColor Red
            $_.Kill($true)
        }
    }
    Write-Host "[PS-MANAGER] Background backup script terminated." -ForegroundColor Green
} else {
    Write-Host "[PS-MANAGER] No matching backup process found to terminate." -ForegroundColor Yellow
}

Write-Host "[PS-MANAGER] Manager script finished." -ForegroundColor Cyan
Read-Host "Press Enter to exit"