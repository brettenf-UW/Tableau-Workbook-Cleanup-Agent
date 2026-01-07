# Tableau Cleanup Agent - Configuration Script
# Manage multiple folders with individual schedules

param(
    [switch]$Silent,
    [string]$Action,
    [string]$FolderPath,
    [string]$FolderName,
    [string]$Schedule,
    [string]$BackupFolder
)

$ErrorActionPreference = "Stop"

# Configuration file path
$ConfigDir = Join-Path $env:USERPROFILE ".iw-tableau-cleanup"
$ConfigFile = Join-Path $ConfigDir "config.json"

function Show-FolderBrowserDialog {
    param(
        [string]$Description = "Select a folder",
        [string]$InitialDirectory = [Environment]::GetFolderPath("MyDocuments")
    )

    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = $Description
    $folderBrowser.SelectedPath = $InitialDirectory
    $folderBrowser.ShowNewFolderButton = $true

    $result = $folderBrowser.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderBrowser.SelectedPath
    }
    return $null
}

function Get-Configuration {
    if (Test-Path $ConfigFile) {
        $content = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($content.version -eq 2) {
            return $content
        }
        # Migrate v1 to v2
        return @{
            version = 2
            default_backup_folder = "backups"
            log_folder = Join-Path $ConfigDir "logs"
            folders = @(
                @{
                    name = "Default"
                    path = $content.watchFolder
                    backup_folder = $content.backupFolder
                    schedule = $content.runTime
                    enabled = $true
                    last_run = $null
                }
            )
        }
    }
    return @{
        version = 2
        default_backup_folder = "backups"
        log_folder = Join-Path $ConfigDir "logs"
        folders = @()
    }
}

function Save-Configuration {
    param($Config)

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    # Ensure log folder exists
    if (-not (Test-Path $Config.log_folder)) {
        New-Item -ItemType Directory -Path $Config.log_folder -Force | Out-Null
    }

    $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile
    Write-Host "Configuration saved." -ForegroundColor Green
}

function Show-FolderList {
    param($Config)

    Write-Host ""
    Write-Host "Configured Folders:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan

    if ($Config.folders.Count -eq 0) {
        Write-Host "  (none configured)" -ForegroundColor Gray
        return
    }

    $i = 1
    foreach ($folder in $Config.folders) {
        $status = if ($folder.enabled) { "[ON]" } else { "[OFF]" }
        $statusColor = if ($folder.enabled) { "Green" } else { "DarkGray" }

        Write-Host ""
        Write-Host "  $i. $($folder.name)" -ForegroundColor White
        Write-Host "     Status:   " -NoNewline; Write-Host $status -ForegroundColor $statusColor
        Write-Host "     Path:     $($folder.path)" -ForegroundColor Gray
        Write-Host "     Schedule: $($folder.schedule)" -ForegroundColor Gray
        if ($folder.backup_folder) {
            Write-Host "     Backup:   $($folder.backup_folder)" -ForegroundColor Gray
        }
        if ($folder.last_run) {
            Write-Host "     Last Run: $($folder.last_run)" -ForegroundColor DarkGray
        }
        $i++
    }
    Write-Host ""
}

function Add-Folder {
    param($Config)

    Write-Host ""
    Write-Host "Add New Folder" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    Write-Host ""

    # Get folder path
    Write-Host "Select the folder containing Tableau workbooks..." -ForegroundColor Yellow
    $path = Show-FolderBrowserDialog -Description "Select folder with Tableau workbooks"

    if (-not $path) {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return $Config
    }

    Write-Host "  Path: $path" -ForegroundColor Green

    # Get friendly name
    $defaultName = Split-Path $path -Leaf
    $name = Read-Host "Enter a friendly name [$defaultName]"
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $defaultName
    }

    # Get schedule time
    $schedule = Read-Host "Enter daily schedule time (HH:MM) [17:00]"
    if ([string]::IsNullOrWhiteSpace($schedule)) {
        $schedule = "17:00"
    }

    # Validate time format
    if ($schedule -notmatch '^\d{1,2}:\d{2}$') {
        Write-Host "Invalid time format. Using 17:00" -ForegroundColor Yellow
        $schedule = "17:00"
    }

    # Ask about backup folder
    $useCustomBackup = Read-Host "Use custom backup folder? (y/N)"
    $backupFolder = $null
    if ($useCustomBackup -eq "y" -or $useCustomBackup -eq "Y") {
        $backupFolder = Show-FolderBrowserDialog -Description "Select backup folder"
    }

    # Create new folder entry
    $newFolder = @{
        name = $name
        path = $path
        backup_folder = $backupFolder
        schedule = $schedule
        enabled = $true
        last_run = $null
    }

    # Add to config
    $Config.folders += $newFolder

    Write-Host ""
    Write-Host "Folder added:" -ForegroundColor Green
    Write-Host "  Name:     $name"
    Write-Host "  Path:     $path"
    Write-Host "  Schedule: $schedule"

    return $Config
}

function Edit-Folder {
    param($Config)

    if ($Config.folders.Count -eq 0) {
        Write-Host "No folders configured." -ForegroundColor Yellow
        return $Config
    }

    Show-FolderList -Config $Config

    $selection = Read-Host "Enter folder number to edit"
    $index = [int]$selection - 1

    if ($index -lt 0 -or $index -ge $Config.folders.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        return $Config
    }

    $folder = $Config.folders[$index]

    Write-Host ""
    Write-Host "Editing: $($folder.name)" -ForegroundColor Cyan
    Write-Host "Press Enter to keep current value" -ForegroundColor Gray
    Write-Host ""

    # Edit name
    $newName = Read-Host "Name [$($folder.name)]"
    if (-not [string]::IsNullOrWhiteSpace($newName)) {
        $folder.name = $newName
    }

    # Edit schedule
    $newSchedule = Read-Host "Schedule [$($folder.schedule)]"
    if (-not [string]::IsNullOrWhiteSpace($newSchedule)) {
        if ($newSchedule -match '^\d{1,2}:\d{2}$') {
            $folder.schedule = $newSchedule
        } else {
            Write-Host "Invalid time format, keeping current." -ForegroundColor Yellow
        }
    }

    # Toggle enabled
    $currentStatus = if ($folder.enabled) { "enabled" } else { "disabled" }
    $toggleEnabled = Read-Host "Currently $currentStatus. Toggle? (y/N)"
    if ($toggleEnabled -eq "y" -or $toggleEnabled -eq "Y") {
        $folder.enabled = -not $folder.enabled
        $newStatus = if ($folder.enabled) { "enabled" } else { "disabled" }
        Write-Host "  Now $newStatus" -ForegroundColor Green
    }

    # Edit path
    $changePath = Read-Host "Change folder path? (y/N)"
    if ($changePath -eq "y" -or $changePath -eq "Y") {
        $newPath = Show-FolderBrowserDialog -Description "Select new folder path"
        if ($newPath) {
            $folder.path = $newPath
            Write-Host "  Path updated to: $newPath" -ForegroundColor Green
        }
    }

    $Config.folders[$index] = $folder
    Write-Host ""
    Write-Host "Folder updated." -ForegroundColor Green

    return $Config
}

function Remove-Folder {
    param($Config)

    if ($Config.folders.Count -eq 0) {
        Write-Host "No folders configured." -ForegroundColor Yellow
        return $Config
    }

    Show-FolderList -Config $Config

    $selection = Read-Host "Enter folder number to remove"
    $index = [int]$selection - 1

    if ($index -lt 0 -or $index -ge $Config.folders.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        return $Config
    }

    $folder = $Config.folders[$index]
    $confirm = Read-Host "Remove '$($folder.name)'? (y/N)"

    if ($confirm -eq "y" -or $confirm -eq "Y") {
        $Config.folders = @($Config.folders | Where-Object { $_ -ne $folder })
        Write-Host "Folder removed." -ForegroundColor Green
    } else {
        Write-Host "Cancelled." -ForegroundColor Yellow
    }

    return $Config
}

function Show-Menu {
    param($Config)

    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  Tableau Cleanup Agent - Setup" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan

    Show-FolderList -Config $Config

    Write-Host "Actions:" -ForegroundColor Yellow
    Write-Host "  1. Add folder"
    Write-Host "  2. Edit folder"
    Write-Host "  3. Remove folder"
    Write-Host "  4. Save and exit"
    Write-Host "  5. Exit without saving"
    Write-Host ""

    return Read-Host "Select action"
}

# Main flow
$config = Get-Configuration

# Handle silent/scripted mode
if ($Silent -or $Action) {
    switch ($Action) {
        "add" {
            if (-not $FolderPath -or -not (Test-Path $FolderPath)) {
                Write-Host "Error: Valid -FolderPath required" -ForegroundColor Red
                exit 1
            }
            $newFolder = @{
                name = if ($FolderName) { $FolderName } else { Split-Path $FolderPath -Leaf }
                path = $FolderPath
                backup_folder = $BackupFolder
                schedule = if ($Schedule) { $Schedule } else { "17:00" }
                enabled = $true
                last_run = $null
            }
            $config.folders += $newFolder
            Save-Configuration -Config $config
            Write-Host "Folder added: $($newFolder.name)" -ForegroundColor Green
        }
        "list" {
            Show-FolderList -Config $config
        }
        "remove" {
            if (-not $FolderName) {
                Write-Host "Error: -FolderName required" -ForegroundColor Red
                exit 1
            }
            $config.folders = @($config.folders | Where-Object { $_.name -ne $FolderName })
            Save-Configuration -Config $config
            Write-Host "Folder removed: $FolderName" -ForegroundColor Green
        }
        default {
            Write-Host "Unknown action. Use: add, list, remove" -ForegroundColor Red
            exit 1
        }
    }
    exit 0
}

# Interactive menu loop
$modified = $false

while ($true) {
    $action = Show-Menu -Config $config

    switch ($action) {
        "1" {
            $config = Add-Folder -Config $config
            $modified = $true
        }
        "2" {
            $config = Edit-Folder -Config $config
            $modified = $true
        }
        "3" {
            $config = Remove-Folder -Config $config
            $modified = $true
        }
        "4" {
            Save-Configuration -Config $config
            Write-Host ""
            Write-Host "Configuration saved!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "  1. Run 'install-schedule.ps1' to create scheduled tasks"
            Write-Host "  2. Or run 'run-cleanup.ps1' to test manually"
            Write-Host ""
            exit 0
        }
        "5" {
            if ($modified) {
                $confirm = Read-Host "Discard changes? (y/N)"
                if ($confirm -ne "y" -and $confirm -ne "Y") {
                    continue
                }
            }
            Write-Host "Exiting without saving." -ForegroundColor Yellow
            exit 0
        }
        default {
            Write-Host "Invalid selection." -ForegroundColor Red
        }
    }
}
