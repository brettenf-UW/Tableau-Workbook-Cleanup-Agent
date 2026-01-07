# Tableau Cleanup Agent - Task Scheduler Installation
# Creates Windows Scheduled Tasks for each unique schedule time

param(
    [switch]$Uninstall,
    [switch]$Force,
    [switch]$List
)

$ErrorActionPreference = "Stop"

# Configuration
$TaskNamePrefix = "TableauCleanupAgent"
$TaskDescription = "Tableau workbook cleanup using Claude Code"
$ConfigDir = Join-Path $env:USERPROFILE ".iw-tableau-cleanup"
$ConfigFile = Join-Path $ConfigDir "config.json"
$ScriptPath = Join-Path $PSScriptRoot "run-cleanup.ps1"

function Get-Configuration {
    if (Test-Path $ConfigFile) {
        $content = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($content.version -eq 2) {
            return $content
        }
        # Convert v1 to v2
        return @{
            version = 2
            folders = @(
                @{
                    name = "Default"
                    path = $content.watchFolder
                    schedule = $content.runTime
                    enabled = $true
                }
            )
        }
    }
    return $null
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-UniqueSchedules {
    param($Config)

    $schedules = @{}
    foreach ($folder in $Config.folders) {
        if ($folder.enabled) {
            $time = $folder.schedule
            if (-not $schedules.ContainsKey($time)) {
                $schedules[$time] = @()
            }
            $schedules[$time] += $folder.name
        }
    }
    return $schedules
}

function Get-TaskName {
    param([string]$Time)
    # Convert 17:00 to 1700 for task name
    $safeName = $Time -replace ':', ''
    return "${TaskNamePrefix}_${safeName}"
}

function Get-ExistingTasks {
    return Get-ScheduledTask -TaskName "${TaskNamePrefix}*" -ErrorAction SilentlyContinue
}

function Uninstall-AllTasks {
    $tasks = Get-ExistingTasks

    if ($tasks) {
        foreach ($task in $tasks) {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
            Write-Host "Removed: $($task.TaskName)" -ForegroundColor Green
        }
        Write-Host ""
        Write-Host "All scheduled tasks removed." -ForegroundColor Green
    } else {
        Write-Host "No scheduled tasks found." -ForegroundColor Yellow
    }
}

function Show-TaskList {
    $tasks = Get-ExistingTasks

    Write-Host ""
    Write-Host "Existing Scheduled Tasks:" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan

    if (-not $tasks) {
        Write-Host "  (none)" -ForegroundColor Gray
        return
    }

    foreach ($task in $tasks) {
        $trigger = $task.Triggers | Select-Object -First 1
        $time = if ($trigger.StartBoundary) {
            [datetime]::Parse($trigger.StartBoundary).ToString("HH:mm")
        } else {
            "unknown"
        }

        $status = switch ($task.State) {
            "Ready" { "Ready" }
            "Running" { "Running" }
            "Disabled" { "Disabled" }
            default { $task.State }
        }
        $statusColor = switch ($task.State) {
            "Ready" { "Green" }
            "Running" { "Cyan" }
            "Disabled" { "DarkGray" }
            default { "Yellow" }
        }

        Write-Host ""
        Write-Host "  $($task.TaskName)" -ForegroundColor White
        Write-Host "    Time:   $time daily" -ForegroundColor Gray
        Write-Host "    Status: " -NoNewline; Write-Host $status -ForegroundColor $statusColor
    }
    Write-Host ""
}

# Banner
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Tableau Cleanup Agent - Scheduler" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Handle list command
if ($List) {
    Show-TaskList
    exit 0
}

# Handle uninstall
if ($Uninstall) {
    Uninstall-AllTasks
    exit 0
}

# Check for admin privileges
if (-not (Test-AdminPrivileges)) {
    Write-Host "Warning: Running without admin privileges." -ForegroundColor Yellow
    Write-Host "Tasks will run only when you are logged in." -ForegroundColor Yellow
    Write-Host ""
}

# Load configuration
$config = Get-Configuration

if (-not $config) {
    Write-Host "Error: No configuration found. Run configure.ps1 first." -ForegroundColor Red
    exit 1
}

if ($config.folders.Count -eq 0) {
    Write-Host "Error: No folders configured. Run configure.ps1 first." -ForegroundColor Red
    exit 1
}

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "Error: run-cleanup.ps1 not found at: $ScriptPath" -ForegroundColor Red
    exit 1
}

# Get unique schedules
$schedules = Get-UniqueSchedules -Config $config

if ($schedules.Count -eq 0) {
    Write-Host "No enabled folders found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Schedule Summary:" -ForegroundColor White
foreach ($time in $schedules.Keys) {
    $folders = $schedules[$time] -join ", "
    Write-Host "  $time - $folders" -ForegroundColor Gray
}
Write-Host ""

# Check for existing tasks
$existingTasks = Get-ExistingTasks

if ($existingTasks -and -not $Force) {
    Write-Host "Existing scheduled tasks found:" -ForegroundColor Yellow
    foreach ($task in $existingTasks) {
        Write-Host "  - $($task.TaskName)" -ForegroundColor Gray
    }
    Write-Host ""
    $overwrite = Read-Host "Remove and recreate all tasks? (y/N)"

    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }

    # Remove existing tasks
    foreach ($task in $existingTasks) {
        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
    }
    Write-Host "Existing tasks removed." -ForegroundColor Green
    Write-Host ""
}

# Create tasks for each unique schedule
Write-Host "Creating scheduled tasks..." -ForegroundColor White
$createdCount = 0

foreach ($time in $schedules.Keys) {
    $taskName = Get-TaskName -Time $time
    $folders = $schedules[$time]

    try {
        # Parse time
        $timeParts = $time.Split(":")
        $hour = [int]$timeParts[0]
        $minute = [int]$timeParts[1]

        # Task action - run PowerShell with the cleanup script
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -ScheduleTime `"$time`""

        # Trigger - daily at specified time
        $trigger = New-ScheduledTaskTrigger -Daily -At "$($hour):$($minute.ToString('D2'))"

        # Settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false

        # Principal - run as current user
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

        # Description with folder names
        $desc = "$TaskDescription at $time for: $($folders -join ', ')"

        # Register the task
        Register-ScheduledTask -TaskName $taskName -Description $desc -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

        Write-Host "  Created: $taskName ($time)" -ForegroundColor Green
        $createdCount++

    } catch {
        Write-Host "  Error creating task for $time`: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  $createdCount Scheduled Task(s) Created!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "  View tasks:   .\install-schedule.ps1 -List" -ForegroundColor Gray
Write-Host "  Uninstall:    .\install-schedule.ps1 -Uninstall" -ForegroundColor Gray
Write-Host "  Run now:      .\run-cleanup.ps1" -ForegroundColor Gray
Write-Host ""

# Offer to run now
$runNow = Read-Host "Run cleanup now to test? (y/N)"

if ($runNow -eq "y" -or $runNow -eq "Y") {
    Write-Host ""
    Write-Host "Starting cleanup..." -ForegroundColor Cyan
    & $ScriptPath
}

Write-Host ""
