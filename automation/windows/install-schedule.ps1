# Tableau Workbook Scrubber - Task Scheduler Installation
# Creates Windows Scheduled Tasks for each unique schedule time

param(
    [switch]$Uninstall,
    [switch]$Force,
    [switch]$List
)

$ErrorActionPreference = "Stop"

# Import shared UI functions
. "$PSScriptRoot\lib\ui-helpers.ps1"

# Configuration
$TaskNamePrefix = "TableauWorkbookScrubber"
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
            Write-Good "Removed: $($task.TaskName)"
        }
        Show-Success -Title "Tasks Removed" -Stats @{
            "Removed" = $tasks.Count
        }
    } else {
        Write-Bad "No scheduled tasks found"
    }
}

function Show-TaskList {
    $tasks = Get-ExistingTasks

    Write-Header "Scheduled Tasks"

    if (-not $tasks) {
        Write-Status "(no scheduled tasks)"
        return
    }

    Write-Host ""
    Write-Host "    +-------------------------------+-------+----------+" -ForegroundColor $Colors.Dim
    Write-Host "    | Task Name                     | Time  | Status   |" -ForegroundColor $Colors.Body
    Write-Host "    +-------------------------------+-------+----------+" -ForegroundColor $Colors.Dim

    foreach ($task in $tasks) {
        $trigger = $task.Triggers | Select-Object -First 1
        $time = if ($trigger.StartBoundary) {
            [datetime]::Parse($trigger.StartBoundary).ToString("HH:mm")
        } else {
            "??:??"
        }

        $status = switch ($task.State) {
            "Ready" { "Ready" }
            "Running" { "Running" }
            "Disabled" { "Disabled" }
            default { $task.State }
        }
        $statusColor = switch ($task.State) {
            "Ready" { $Colors.Success }
            "Running" { $Colors.LightBlue }
            "Disabled" { $Colors.Dim }
            default { $Colors.Warning }
        }

        $taskName = if ($task.TaskName.Length -gt 29) { $task.TaskName.Substring(0, 26) + "..." } else { $task.TaskName }
        Write-Host "    | $($taskName.PadRight(29)) | $time | " -NoNewline -ForegroundColor $Colors.Dim
        Write-Host $status.PadRight(8) -NoNewline -ForegroundColor $statusColor
        Write-Host " |" -ForegroundColor $Colors.Dim
    }

    Write-Host "    +-------------------------------+-------+----------+" -ForegroundColor $Colors.Dim
    Write-Host ""
}

# Banner
Show-Banner -Compact

# Handle list command (direct arg)
if ($List) {
    Show-TaskList
    exit 0
}

# Handle uninstall (direct arg)
if ($Uninstall) {
    Uninstall-AllTasks
    exit 0
}

# Load configuration first
$config = Get-Configuration

if (-not $config) {
    Write-Fail "No configuration found. Run 'tableau-scrubber' and select Configure first."
    exit 1
}

# Interactive menu
function Show-ScheduleMenu {
    $existingTasks = Get-ExistingTasks
    $schedules = Get-UniqueSchedules -Config $config

    Write-Header "Schedule Management"

    # Show current status
    if ($existingTasks -and $existingTasks.Count -gt 0) {
        Write-Step "Current scheduled tasks:"
        Write-Host ""
        Write-Host "    +---------------------------+-------+----------+" -ForegroundColor $Colors.Dim
        Write-Host "    | Task                      | Time  | Status   |" -ForegroundColor $Colors.Body
        Write-Host "    +---------------------------+-------+----------+" -ForegroundColor $Colors.Dim

        foreach ($task in $existingTasks) {
            $trigger = $task.Triggers | Select-Object -First 1
            $time = if ($trigger.StartBoundary) {
                [datetime]::Parse($trigger.StartBoundary).ToString("HH:mm")
            } else { "??:??" }

            $status = switch ($task.State) {
                "Ready" { "Ready" }
                "Running" { "Running" }
                "Disabled" { "Off" }
                default { $task.State }
            }
            $statusColor = switch ($task.State) {
                "Ready" { $Colors.Success }
                "Running" { $Colors.LightBlue }
                default { $Colors.Dim }
            }

            $taskName = if ($task.TaskName.Length -gt 25) { $task.TaskName.Substring(0, 22) + "..." } else { $task.TaskName }
            Write-Host "    | $($taskName.PadRight(25)) | $time | " -NoNewline -ForegroundColor $Colors.Dim
            Write-Host $status.PadRight(8) -NoNewline -ForegroundColor $statusColor
            Write-Host " |" -ForegroundColor $Colors.Dim
        }
        Write-Host "    +---------------------------+-------+----------+" -ForegroundColor $Colors.Dim
    } else {
        Write-Status "No scheduled tasks configured yet."
    }

    Write-Host ""

    # Show configured folder schedules
    if ($schedules.Count -gt 0) {
        Write-Step "Folder schedules (from config):"
        foreach ($time in $schedules.Keys) {
            $folders = $schedules[$time] -join ", "
            Write-Status "$time - $folders"
        }
    }

    Show-MenuBox -Title "Schedule Options" -Options @(
        @{ Key = "1"; Label = "Create/Update"; Desc = "Apply folder schedules" }
        @{ Key = "2"; Label = "Remove All"; Desc = "Delete all tasks" }
        @{ Key = "3"; Label = "Back"; Desc = "Return to main menu" }
    )

    return Get-UserChoice -Prompt "Select [1-3]:"
}

# Run interactive menu
$menuChoice = Show-ScheduleMenu

switch ($menuChoice) {
    "1" {
        # Create/Update schedules
    }
    "2" {
        Uninstall-AllTasks
        exit 0
    }
    "3" {
        exit 0
    }
    default {
        Write-Bad "Invalid selection"
        exit 0
    }
}

# Continue with schedule creation (option 1)
if ($config.folders.Count -eq 0) {
    Write-Fail "No folders configured. Run 'tableau-scrubber' and select Configure first."
    exit 1
}

# Check for admin privileges
if (-not (Test-AdminPrivileges)) {
    Write-Bad "Running without admin privileges"
    Write-Status "Tasks will run only when you are logged in"
    Write-Host ""
}

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Fail "run-cleanup.ps1 not found at: $ScriptPath"
    exit 1
}

# Get unique schedules
$schedules = Get-UniqueSchedules -Config $config

if ($schedules.Count -eq 0) {
    Write-Bad "No enabled folders found"
    exit 0
}

Write-Header "Creating Schedules"
foreach ($time in $schedules.Keys) {
    $folders = $schedules[$time] -join ", "
    Write-Status "$time daily - $folders"
}
Write-Host ""

# Check for existing tasks - remove silently if updating
$existingTasks = Get-ExistingTasks

if ($existingTasks -and -not $Force) {
    Write-Step "Updating existing tasks..."
    foreach ($task in $existingTasks) {
        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
    }
    Write-Good "Old tasks removed"
    Write-Host ""
}

# Create tasks for each unique schedule
Write-Step "Creating scheduled tasks..."
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

        Write-Good "Created: $taskName ($time)"
        $createdCount++

    } catch {
        Write-Fail "Error creating task for $time`: $_"
    }
}

Show-Success -Title "Scheduled Tasks Created" -Stats @{
    "Tasks Created" = $createdCount
    "Run Time" = ($schedules.Keys | Sort-Object) -join ", "
}

Write-Host ""
Write-Info "View:    tableau-scrubber -Action schedule -List"
Write-Info "Remove:  tableau-scrubber -Action schedule -Uninstall"
Write-Host ""
