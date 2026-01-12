# Tableau Workbook Scrubber - Unified CLI Entry Point
# Run this script to access all cleanup features from one menu

param(
    [string]$Action,           # clean, configure, schedule, logs
    [string]$WorkbookPath,     # Direct path for automation
    [switch]$Help,
    [switch]$Version
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"

# Import shared UI functions
. "$PSScriptRoot\lib\ui-helpers.ps1"

# Configuration
$ConfigDir = Join-Path $env:USERPROFILE ".iw-tableau-cleanup"
$ConfigFile = Join-Path $ConfigDir "config.json"

function Get-Configuration {
    if (Test-Path $ConfigFile) {
        $content = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        return $content
    }
    return @{
        version = 2
        default_backup_folder = "backups"
        log_folder = Join-Path $ConfigDir "logs"
        folders = @()
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "    TABLEAU WORKBOOK SCRUBBER" -ForegroundColor $Colors.Gold
    Write-Host "    Usage: tableau-scrubber [options]" -ForegroundColor $Colors.Body
    Write-Host ""
    Write-Host "    Options:" -ForegroundColor $Colors.LightBlue
    Write-Host "      (no args)         Interactive menu" -ForegroundColor $Colors.Dim
    Write-Host "      -Action clean     Run cleanup on configured folders" -ForegroundColor $Colors.Dim
    Write-Host "      -Action configure Open folder configuration" -ForegroundColor $Colors.Dim
    Write-Host "      -Action schedule  Manage scheduled tasks" -ForegroundColor $Colors.Dim
    Write-Host "      -Action logs      View recent cleanup logs" -ForegroundColor $Colors.Dim
    Write-Host "      -WorkbookPath     Specify a workbook directly" -ForegroundColor $Colors.Dim
    Write-Host "      -Help             Show this help" -ForegroundColor $Colors.Dim
    Write-Host "      -Version          Show version" -ForegroundColor $Colors.Dim
    Write-Host ""
    Write-Host "    Examples:" -ForegroundColor $Colors.LightBlue
    Write-Host "      tableau-scrubber" -ForegroundColor $Colors.Dim
    Write-Host "      tableau-scrubber -Action clean" -ForegroundColor $Colors.Dim
    Write-Host "      tableau-scrubber -Action clean -WorkbookPath 'C:\path\to\workbook.twb'" -ForegroundColor $Colors.Dim
    Write-Host ""
}

function Show-MainMenu {
    Clear-Host
    Show-Banner

    $config = Get-Configuration
    # Handle both array and single-object cases from JSON deserialization
    $enabledFolders = @($config.folders | Where-Object { $_.enabled -eq $true })
    $folderCount = $enabledFolders.Count

    # Show quick status
    Write-Host "    Status: " -NoNewline -ForegroundColor $Colors.Dim
    if ($folderCount -gt 0) {
        Write-Host "$folderCount folder(s) configured" -ForegroundColor $Colors.Success
    } else {
        Write-Host "No folders configured" -ForegroundColor $Colors.Warning
    }

    Show-MenuBox -Title "What would you like to do?" -Options @(
        @{ Key = "1"; Label = "Clean Workbooks"; Desc = "Run cleanup on configured folders" }
        @{ Key = "2"; Label = "Configure Folders"; Desc = "Add, edit, remove watch folders" }
        @{ Key = "3"; Label = "View Logs"; Desc = "Check recent cleanup history" }
        @{ Key = "Q"; Label = "Quit"; Desc = "" }
    )

    return Get-UserChoice -Prompt "Select [1-3, Q]:"
}

function Invoke-Cleanup {
    param([string]$Path)

    if ($Path) {
        & "$PSScriptRoot\run-cleanup.ps1" -WorkbookPath $Path
    } else {
        & "$PSScriptRoot\run-cleanup.ps1"
    }
}

function Invoke-Configure {
    & "$PSScriptRoot\configure.ps1"
}

function Invoke-Schedule {
    & "$PSScriptRoot\install-schedule.ps1"
}

# Handle version flag
if ($Version) {
    Write-Host ""
    Write-Host "    Tableau Workbook Scrubber v$ScriptVersion" -ForegroundColor $Colors.Body
    Write-Host "    Powered by InterWorks" -ForegroundColor $Colors.Dim
    Write-Host ""
    exit 0
}

# Handle help flag
if ($Help) {
    Show-Help
    exit 0
}

# Non-interactive mode (for automation/scripting)
if ($Action) {
    switch ($Action.ToLower()) {
        "clean" {
            Invoke-Cleanup -Path $WorkbookPath
        }
        "configure" {
            Invoke-Configure
        }
        "schedule" {
            Invoke-Schedule
        }
        "logs" {
            Show-Banner -Compact
            Show-Logs
        }
        default {
            Write-Fail "Unknown action: $Action"
            Write-Host ""
            Write-Host "    Valid actions: clean, configure, schedule, logs" -ForegroundColor $Colors.Dim
            exit 1
        }
    }
    exit 0
}

# Interactive menu loop
while ($true) {
    $choice = Show-MainMenu

    switch ($choice.ToUpper()) {
        "1" {
            Clear-Host
            Show-Banner -Compact
            Invoke-Cleanup
            Write-Host ""
            Start-Sleep -Seconds 2
        }
        "2" {
            Clear-Host
            Invoke-Configure
        }
        "3" {
            Clear-Host
            Show-Banner -Compact
            Show-Logs -Interactive
        }
        "Q" {
            Write-Host ""
            Write-Host "    Goodbye!" -ForegroundColor $Colors.LightBlue
            Write-Host ""
            exit 0
        }
        default {
            Write-Bad "Invalid selection. Please enter 1-3 or Q."
            Start-Sleep -Seconds 1
        }
    }
}
