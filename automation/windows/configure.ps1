# Tableau Workbook Scrubber - Configuration Script
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

# Import shared UI functions
. "$PSScriptRoot\lib\ui-helpers.ps1"

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
    Write-Good "Configuration saved"
}

# Note: Using Show-FolderList from ui-helpers.ps1

function Add-Folder {
    param($Config)

    Write-SubHeader "Add New Folder"

    # Get folder path
    Write-Step "Select the folder containing Tableau workbooks..."
    $path = Show-FolderBrowserDialog -Description "Select folder with Tableau workbooks"

    if (-not $path) {
        Write-Bad "Cancelled"
        return $Config
    }

    Write-Good "Selected: $path"

    # Get friendly name
    $defaultName = Split-Path $path -Leaf
    $name = Get-UserChoice -Prompt "Enter a friendly name:" -Default $defaultName

    # Get schedule time
    $schedule = Get-UserChoice -Prompt "Enter daily schedule time (HH:MM):" -Default "17:00"

    # Validate time format
    if ($schedule -notmatch '^\d{1,2}:\d{2}$') {
        Write-Bad "Invalid time format. Using 17:00"
        $schedule = "17:00"
    }

    # Ask about backup folder
    if (Get-UserConfirmation -Prompt "Use custom backup folder?") {
        $backupFolder = Show-FolderBrowserDialog -Description "Select backup folder"
    } else {
        $backupFolder = $null
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
    Write-Good "Folder added"
    Write-Status "Name:     $name"
    Write-Status "Path:     $path"
    Write-Status "Schedule: $schedule"

    return $Config
}

function Edit-Folder {
    param($Config)

    if ($Config.folders.Count -eq 0) {
        Write-Bad "No folders configured"
        return $Config
    }

    Write-SubHeader "Configured Folders"
    Show-FolderList -Config $Config

    $selection = Get-UserChoice -Prompt "Enter folder number to edit:"
    $index = [int]$selection - 1

    if ($index -lt 0 -or $index -ge $Config.folders.Count) {
        Write-Fail "Invalid selection"
        return $Config
    }

    $folder = $Config.folders[$index]

    Write-SubHeader "Editing: $($folder.name)"
    Write-Status "Press Enter to keep current value"

    # Edit name
    $newName = Get-UserChoice -Prompt "Name:" -Default $folder.name
    $folder.name = $newName

    # Edit schedule
    $newSchedule = Get-UserChoice -Prompt "Schedule (HH:MM):" -Default $folder.schedule
    if ($newSchedule -match '^\d{1,2}:\d{2}$') {
        $folder.schedule = $newSchedule
    } else {
        Write-Bad "Invalid time format, keeping current"
    }

    # Toggle enabled - use clear language
    if ($folder.enabled) {
        if (Get-UserConfirmation -Prompt "Disable this folder?") {
            $folder.enabled = $false
            Write-Good "Folder disabled"
        }
    } else {
        if (Get-UserConfirmation -Prompt "Enable this folder?" -DefaultYes $true) {
            $folder.enabled = $true
            Write-Good "Folder enabled"
        }
    }

    # Edit path
    if (Get-UserConfirmation -Prompt "Change folder path?") {
        $newPath = Show-FolderBrowserDialog -Description "Select new folder path"
        if ($newPath) {
            $folder.path = $newPath
            Write-Good "Path updated: $newPath"
        }
    }

    $Config.folders[$index] = $folder
    Write-Good "Folder updated"

    return $Config
}

function Remove-Folder {
    param($Config)

    if ($Config.folders.Count -eq 0) {
        Write-Bad "No folders configured"
        return $Config
    }

    Write-SubHeader "Configured Folders"
    Show-FolderList -Config $Config

    $selection = Get-UserChoice -Prompt "Enter folder number to remove:"
    $index = [int]$selection - 1

    if ($index -lt 0 -or $index -ge $Config.folders.Count) {
        Write-Fail "Invalid selection"
        return $Config
    }

    $folder = $Config.folders[$index]

    if (Get-UserConfirmation -Prompt "Remove '$($folder.name)'?") {
        $Config.folders = @($Config.folders | Where-Object { $_ -ne $folder })
        Write-Good "Folder removed"
    } else {
        Write-Bad "Cancelled"
    }

    return $Config
}

function Show-Menu {
    param($Config)

    Clear-Host
    Show-Banner -Compact

    Write-Header "Folder Configuration"
    Show-FolderList -Config $Config

    Show-MenuBox -Title "Actions" -Options @(
        @{ Key = "1"; Label = "Add folder"; Desc = "Add a new watch folder" }
        @{ Key = "2"; Label = "Edit folder"; Desc = "Modify an existing folder" }
        @{ Key = "3"; Label = "Remove folder"; Desc = "Delete a folder" }
        @{ Key = "4"; Label = "Save and exit"; Desc = "Save changes and return" }
        @{ Key = "5"; Label = "Exit"; Desc = "Discard changes" }
    )

    return Get-UserChoice -Prompt "Select [1-5]:"
}

# Main flow
$config = Get-Configuration

# Handle silent/scripted mode
if ($Silent -or $Action) {
    switch ($Action) {
        "add" {
            if (-not $FolderPath -or -not (Test-Path $FolderPath)) {
                Write-Fail "Error: Valid -FolderPath required"
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
            Write-Good "Folder added: $($newFolder.name)"
        }
        "list" {
            Show-Banner -Compact
            Write-Header "Configured Folders"
            Show-FolderList -Config $config
        }
        "remove" {
            if (-not $FolderName) {
                Write-Fail "Error: -FolderName required"
                exit 1
            }
            $config.folders = @($config.folders | Where-Object { $_.name -ne $FolderName })
            Save-Configuration -Config $config
            Write-Good "Folder removed: $FolderName"
        }
        default {
            Write-Fail "Unknown action. Use: add, list, remove"
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
            Start-Sleep -Seconds 1
        }
        "2" {
            $config = Edit-Folder -Config $config
            $modified = $true
            Start-Sleep -Seconds 1
        }
        "3" {
            $config = Remove-Folder -Config $config
            $modified = $true
            Start-Sleep -Seconds 1
        }
        "4" {
            Save-Configuration -Config $config
            Show-Success -Title "Configuration Saved" -Stats @{
                "Folders" = $config.folders.Count
            }
            Write-Host ""
            Write-Info "Next: Run 'tableau-scrubber' to clean workbooks"
            Write-Info "Or select 'Manage Schedules' to automate"
            Write-Host ""
            exit 0
        }
        "5" {
            if ($modified) {
                if (-not (Get-UserConfirmation -Prompt "Discard changes?")) {
                    continue
                }
            }
            Write-Bad "Exiting without saving"
            exit 0
        }
        default {
            Write-Fail "Invalid selection"
            Start-Sleep -Seconds 1
        }
    }
}
