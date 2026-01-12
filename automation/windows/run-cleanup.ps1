# Tableau Workbook Scrubber - Cleanup Runner
# Runs Claude Code in a loop until validation passes

param(
    [string]$WorkbookPath,
    [string]$FolderName,
    [string]$ScheduleTime,
    [int]$MaxIterations = 10,
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$Standalone  # Run with full banner (not from menu)
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Tableau Workbook Scrubber"

# Import shared UI functions
. "$PSScriptRoot\lib\ui-helpers.ps1"

# Configuration
$ConfigDir = Join-Path $env:USERPROFILE ".iw-tableau-cleanup"
$ConfigFile = Join-Path $ConfigDir "config.json"
$SkillDir = Join-Path $env:USERPROFILE ".claude\skills\tableau-cleanup"
$ValidateScript = Join-Path $SkillDir "scripts\validate_cleanup.py"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry
    }
}

function Write-StructuredLog {
    param(
        [string]$WorkbookName,
        [bool]$Success,
        [int]$Iterations,
        [int]$InitialErrors,
        [int]$FinalErrors,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$LogFolder
    )

    $jsonlFile = Join-Path $LogFolder "runs.jsonl"

    $logEntry = @{
        timestamp = $StartTime.ToString("yyyy-MM-ddTHH:mm:ss")
        workbook = $WorkbookName
        success = $Success
        iterations = $Iterations
        initial_errors = $InitialErrors
        final_errors = $FinalErrors
        duration_seconds = [math]::Round(($EndTime - $StartTime).TotalSeconds, 1)
    } | ConvertTo-Json -Compress

    Add-Content -Path $jsonlFile -Value $logEntry
}

function Get-ValidationErrors {
    param([string[]]$Output)

    $result = @{
        Caption = 0
        Comment = 0
        Folder = 0
        XML = 0
        Total = 0
    }

    foreach ($line in $Output) {
        if ($line -match '\[ERROR\]') {
            $result.Total++
            if ($line -match 'C[1-5]:') { $result.Caption++ }
            elseif ($line -match 'M[1-6]:') { $result.Comment++ }
            elseif ($line -match 'F[1-9]|F1[01]:') { $result.Folder++ }
            elseif ($line -match 'X[1-2]:') { $result.XML++ }
        }
    }

    return $result
}

# Note: Show-ErrorSummary replaced by Show-ErrorTable from ui-helpers.ps1

function Get-Configuration {
    if (Test-Path $ConfigFile) {
        $content = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        # Handle both v1 and v2 config formats
        if ($content.version -eq 2) {
            return $content
        } else {
            # Convert v1 to v2 format
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
    }
    return $null
}

function Find-LatestWorkbook {
    param(
        [string]$Directory,
        [string[]]$ExcludePatterns = @("_backup", "_cleaned", "Archive", "backups")
    )

    $workbooks = Get-ChildItem -Path $Directory -Recurse -Include "*.twb", "*.twbx" -File |
        Where-Object {
            $path = $_.FullName
            -not ($ExcludePatterns | Where-Object { $path -match $_ })
        } |
        Sort-Object LastWriteTime -Descending

    if ($workbooks.Count -gt 0) {
        return $workbooks[0]
    }
    return $null
}

function Get-FoldersToProcess {
    param($Config, $FolderName, $ScheduleTime)

    $folders = @()

    if ($FolderName) {
        # Process specific folder by name
        $folder = $Config.folders | Where-Object { $_.name -eq $FolderName -and $_.enabled }
        if ($folder) { $folders += $folder }
    }
    elseif ($ScheduleTime) {
        # Process all folders with matching schedule
        $folders = $Config.folders | Where-Object { $_.schedule -eq $ScheduleTime -and $_.enabled }
    }
    else {
        # Process all enabled folders
        $folders = $Config.folders | Where-Object { $_.enabled }
    }

    return $folders
}

function Run-CleanupLoop {
    param(
        [string]$WorkbookPath,
        [string]$BackupFolder,
        [string]$LogFile,
        [string]$LogFolder,
        [int]$MaxIterations
    )

    $iteration = 0
    $success = $false
    $workbookName = Split-Path $WorkbookPath -Leaf
    $backupCreated = $false
    $startTime = Get-Date
    $initialErrors = 0
    $finalErrors = 0

    # Calculate paths ONCE before the loop (so all passes use the same file)
    $twbPath = $WorkbookPath
    if ($WorkbookPath -match '\.twbx$') {
        $extractDir = $WorkbookPath -replace '\.twbx$', ''
        $twbFile = Get-ChildItem -Path $extractDir -Filter "*.twb" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($twbFile) { $twbPath = $twbFile.FullName }
    }
    $cleanedPath = $twbPath -replace '\.(twb)$', '_cleaned.$1'
    $checkPath = $cleanedPath  # ALL passes validate this same file

    while ($iteration -lt $MaxIterations) {
        $iteration++

        Show-PassHeader -Current $iteration -Max $MaxIterations
        Write-Log "=== Iteration $iteration of $MaxIterations ===" -LogFile $LogFile

        # AUTO-BACKUP and create _cleaned copy on first pass only
        if (-not $backupCreated) {
            Write-Step "PHASE: Creating backup and working copy..."

            # Ensure backup folder exists
            if (-not (Test-Path $BackupFolder)) {
                New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
            }

            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupName = "${timestamp}_${workbookName}"
            $backupPath = Join-Path $BackupFolder $backupName

            try {
                Copy-Item -Path $WorkbookPath -Destination $backupPath -Force
                Write-Good "Backup saved: $backupName"
                Write-Log "Backup created: $backupPath" -LogFile $LogFile
            } catch {
                Write-Fail "Could not create backup: $_"
                Write-Log "Backup failed: $_" -LogFile $LogFile
                return $false
            }

            # Create _cleaned copy BEFORE Claude starts (script-guaranteed)
            if (-not (Test-Path $cleanedPath)) {
                Copy-Item -Path $twbPath -Destination $cleanedPath -Force
                Write-Good "Created working copy: $(Split-Path $cleanedPath -Leaf)"
                Write-Log "Created _cleaned copy: $cleanedPath" -LogFile $LogFile
            } else {
                Write-Good "Using existing: $(Split-Path $cleanedPath -Leaf)"
            }

            $backupCreated = $true
        }

        # PHASE 1: Check current state
        Write-Step "PHASE: Checking current errors..."

        $previousErrors = $null
        if (Test-Path $ValidateScript) {
            try {
                $validateResult = & python $ValidateScript "$checkPath" 2>&1
                $validateResult | ForEach-Object { Write-Log "  $_" -LogFile $LogFile }
                $currentErrors = Get-ValidationErrors -Output $validateResult

                # Track initial errors on first pass
                if ($iteration -eq 1) {
                    $initialErrors = $currentErrors.Total
                }
                $finalErrors = $currentErrors.Total

                if ($currentErrors.Total -eq 0) {
                    if ($iteration -gt 1) {
                        # Pass 2+: 0 errors means we're done
                        Show-Success -Title "All Checks Passed!" -Stats @{
                            "Passes Required" = $iteration
                        }
                        Write-Log "Validation passed! Cleanup complete." -LogFile $LogFile
                        $success = $true
                        break
                    } else {
                        # Pass 1: Still run Claude for thorough review
                        Write-Good "Validation passed - running thorough review anyway (Pass 1)"
                    }
                }

                Show-ErrorTable -Errors $currentErrors
                $previousErrors = $currentErrors

            } catch {
                Write-Bad "Could not run validation: $_"
            }
        } else {
            Write-Bad "Validation script not found at: $ValidateScript"
            Write-Status "Install skill files first: run install.bat"
            break
        }

        # Build error summary for the prompt (now we have actual $currentErrors)
        $errorList = @()
        if ($currentErrors.Caption -gt 0) { $errorList += "$($currentErrors.Caption) caption errors (naming issues)" }
        if ($currentErrors.Comment -gt 0) { $errorList += "$($currentErrors.Comment) comment errors (missing/lazy comments)" }
        if ($currentErrors.Folder -gt 0) { $errorList += "$($currentErrors.Folder) folder errors (organization)" }
        if ($currentErrors.XML -gt 0) { $errorList += "$($currentErrors.XML) XML errors (syntax)" }
        $errorSummary = if ($errorList.Count -gt 0) { $errorList -join "`n- " } else { "Check validation output above" }

        # IMPORTANT: Prompt uses trigger words that MATCH the Skill description
        # This triggers the Skill AUTOMATICALLY - we don't tell Claude to read files
        $passInstruction = if ($iteration -eq 1) {
            "FIRST PASS - Be THOROUGH: Review ALL calculations regardless of error count. Fix missing folders, improve comments, standardize captions. This is your one chance to review everything."
        } else {
            "PASS $iteration - Be CONSERVATIVE: Only fix items that STILL have errors from validation. Do NOT touch passing items or reorganize folders."
        }

        $prompt = @"
Clean up this Tableau workbook by standardizing captions, adding comments, and organizing calculations into folders.

WORKBOOK PATH: $cleanedPath

PASS NUMBER: $iteration of $MaxIterations
$passInstruction

VALIDATION FOUND $($currentErrors.Total) ERRORS:
- $errorSummary

FOLDER RULES (CRITICAL):
- If a calc ALREADY has a valid folder and passes validation, DO NOT move it
- Calcs can legitimately fit multiple folders (e.g., "% change" calcs relate to both dates AND metrics)
- For ambiguous calcs: KEEP in current folder unless clearly wrong
- Only move a calc if it has NO folder or is in an obviously WRONG folder
- If 5+ similar unfiled calcs exist, you MAY create a new folder (e.g., "Period Comparisons")
- Max folders: 10 - do not exceed

TWO-LAYER VALIDATION:
1. SCRIPT validation catches obvious issues (too short, lazy patterns)
2. YOU must also validate - review comments for quality, even "passing" ones

Use batch processing (scripts/batch_comments.py) to process calculations in groups of 10.

FOR EACH CALCULATION:
1. READ the formula completely
2. UNDERSTAND its business purpose
3. CHECK existing comment (if any)
4. DECIDE: Add / Revise / Keep based on YOUR judgment + script rules

WHAT MAKES A GOOD COMMENT:
- Explains WHY this calc exists (not just what it does)
- Specific to this formula (not generic)
- 15+ characters, not lazy patterns

EXAMPLES:
BAD: "// This calculation is used for tracking"
GOOD: "// Identifies stale accounts needing follow-up for retention"

SAFETY RULES:
- NEVER change name attributes, only caption
- NEVER add formula to bin/group calculations
- Keep &#13;&#10; in formulas (valid XML newlines)
- Edit ONLY the _cleaned file at the path above

Run validation after fixes. Continue until 0 errors.
"@

        # PHASE 2: Ask Claude to fix
        Write-Step "PHASE: Asking Claude to fix errors..."
        Write-Status "This may take a few minutes"

        try {
            $startTime = Get-Date

            # Stream Claude's output in real-time AND capture it
            # --allowedTools pre-grants permissions:
            #   - Read/Edit/Write: unrestricted (path restrictions don't work with spaces)
            #   - Bash: Allow any Python script (Claude creates its own cleanup scripts)
            $allowedTools = @(
                "Read",
                "Edit",
                "Write",
                "Bash(python:*)"
            ) -join ","

            Write-Host ""
            Write-Host "    --- Claude Output ---" -ForegroundColor DarkCyan
            $result = & claude -p $prompt --allowedTools $allowedTools 2>&1 | ForEach-Object {
                Write-Host "    $_" -ForegroundColor DarkGray
                Write-Log "  $_" -LogFile $LogFile
                $_  # Pass through for capture
            }
            Write-Host "    --- End Output ---" -ForegroundColor DarkCyan
            Write-Host ""

            $endTime = Get-Date
            $duration = $endTime - $startTime

            Write-Good "Claude finished ($($duration.TotalMinutes.ToString('F1')) min)"

        } catch {
            Write-Fail "Error running Claude: $_"
            Write-Log "Error running Claude: $_" -LogFile $LogFile
            continue
        }

        # PHASE 3: Verify fixes
        Write-Step "PHASE: Verifying fixes..."

        if (Test-Path $ValidateScript) {
            try {
                $validateResult = & python $ValidateScript "$checkPath" 2>&1
                $validateResult | ForEach-Object { Write-Log "  $_" -LogFile $LogFile }
                $currentErrors = Get-ValidationErrors -Output $validateResult
                $finalErrors = $currentErrors.Total

                if ($currentErrors.Total -eq 0) {
                    Show-Success -Title "All Checks Passed!" -Stats @{
                        "Passes Required" = $iteration
                    }
                    Write-Log "Validation passed! Cleanup complete." -LogFile $LogFile
                    $success = $true
                    break
                }

                # Show what's left
                $fixed = $previousErrors.Total - $currentErrors.Total
                if ($fixed -gt 0) {
                    Write-Good "$fixed errors fixed this pass"
                }
                elseif ($fixed -lt 0) {
                    $increased = [Math]::Abs($fixed)
                    Write-Fail "REGRESSION: $increased MORE errors than before!"
                    Write-Status "Claude may have over-reorganized. Consider restoring backup."
                    Write-Log "ERROR REGRESSION: $increased more errors after Claude's changes" -LogFile $LogFile
                }
                Show-ErrorTable -Errors $currentErrors
                Write-Bad "$($currentErrors.Total) errors remaining - running another pass..."
                Write-Log "Validation found $($currentErrors.Total) errors, continuing..." -LogFile $LogFile

            } catch {
                Write-Fail "Error running validation: $_"
                Write-Log "Error running validation: $_" -LogFile $LogFile
            }
        }
    }

    if (-not $success) {
        Show-Failure -Title "Max Passes Reached" -Message "Some issues may remain after $MaxIterations passes"
        Write-Log "Max iterations ($MaxIterations) reached without passing validation" -LogFile $LogFile
    }

    # Write structured log entry
    if ($LogFolder) {
        Write-StructuredLog -WorkbookName $workbookName -Success $success -Iterations $iteration `
            -InitialErrors $initialErrors -FinalErrors $finalErrors `
            -StartTime $startTime -EndTime (Get-Date) -LogFolder $LogFolder
    }

    return $success
}

# Banner - show full banner if running standalone, compact otherwise
if ($Standalone) {
    Show-Banner
} else {
    Show-Banner -Compact
}
Write-Host "    Press Ctrl+C to cancel at any time" -ForegroundColor DarkGray
Write-Host ""

# Check if Claude is installed
Write-Step "Checking setup..."

$claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Fail "Claude Code not found"
    Write-Host ""
    Write-Host "  Please install Claude Code first:" -ForegroundColor Yellow
    Write-Host "  https://claude.com/code" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
Write-Good "Claude Code installed"

# Setup logging
$logFolder = Join-Path $ConfigDir "logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}
$logFile = Join-Path $logFolder "cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Write-Log "=== Tableau Cleanup Run Started ===" -LogFile $logFile

# Handle direct workbook path
if ($WorkbookPath) {
    if (-not (Test-Path $WorkbookPath)) {
        Write-Fail "Workbook not found: $WorkbookPath"
        exit 1
    }

    $workbookName = Split-Path $WorkbookPath -Leaf
    Write-Good "Found workbook: $workbookName"

    $backupFolder = Join-Path (Split-Path $WorkbookPath -Parent) "backups"

    if ($DryRun) {
        Write-Bad "DRY RUN - no changes will be made"
        exit 0
    }

    $success = Run-CleanupLoop -WorkbookPath $WorkbookPath -BackupFolder $backupFolder -LogFile $logFile -LogFolder $logFolder -MaxIterations $MaxIterations

    Write-Host ""
    Write-Host "  Log: $logFile" -ForegroundColor DarkGray
    Write-Host ""
    exit $(if ($success) { 0 } else { 1 })
}

# Load configuration
$config = Get-Configuration

if (-not $config) {
    Write-Fail "No folders configured"
    Write-Host ""
    Write-Host "  Run 'tableau-setup' to add a folder first" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
Write-Good "Configuration loaded"

# Get folders to process
$foldersToProcess = Get-FoldersToProcess -Config $config -FolderName $FolderName -ScheduleTime $ScheduleTime

if ($foldersToProcess.Count -eq 0) {
    Write-Bad "No enabled folders to process"
    exit 0
}

Write-Good "$($foldersToProcess.Count) folder(s) to process"
Write-Log "Processing $($foldersToProcess.Count) folder(s)" -LogFile $logFile

$successCount = 0
$failCount = 0
$skippedCount = 0

foreach ($folder in $foldersToProcess) {
    Write-Host ""
    Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
    Write-Step "Folder: $($folder.name)"
    Write-Status "Looking for workbooks in: $($folder.path)"
    Write-Log "=== Processing: $($folder.name) ===" -LogFile $logFile

    # Find latest workbook in folder
    $targetWorkbook = Find-LatestWorkbook -Directory $folder.path

    if (-not $targetWorkbook) {
        Write-Bad "No workbooks found in this folder"
        Write-Log "No workbooks found in: $($folder.path)" -LogFile $logFile
        $skippedCount++
        continue
    }

    Write-Good "Found: $($targetWorkbook.Name)"
    Write-Status "Last modified: $($targetWorkbook.LastWriteTime.ToString('MMM d, yyyy h:mm tt'))"
    Write-Log "Found: $($targetWorkbook.Name)" -LogFile $logFile

    # Check if already cleaned recently
    $cleanedPath = $targetWorkbook.FullName -replace '\.(twb|twbx)$', '_cleaned.$1'
    if (Test-Path $cleanedPath) {
        $cleanedFile = Get-Item $cleanedPath
        $timeSinceCleaned = (Get-Date) - $cleanedFile.LastWriteTime

        if ($timeSinceCleaned.TotalHours -lt 1) {
            Write-Bad "Already cleaned recently - skipping"
            Write-Log "Already cleaned within the last hour, skipping" -LogFile $logFile
            $skippedCount++
            continue
        }
    }

    # Determine backup folder
    $backupFolder = if ($folder.backup_folder) { $folder.backup_folder } else { Join-Path $folder.path "backups" }

    if ($DryRun) {
        Write-Bad "DRY RUN - would clean this workbook"
        Write-Log "DRY RUN: Would clean $($targetWorkbook.FullName)" -LogFile $logFile
        continue
    }

    # Run the cleanup loop
    $success = Run-CleanupLoop -WorkbookPath $targetWorkbook.FullName -BackupFolder $backupFolder -LogFile $logFile -LogFolder $logFolder -MaxIterations $MaxIterations

    if ($success) {
        $successCount++
    } else {
        $failCount++
    }
}

# Final summary
$stats = [ordered]@{}
if ($successCount -gt 0) { $stats["Cleaned"] = "$successCount workbook(s)" }
if ($failCount -gt 0) { $stats["Failed"] = "$failCount workbook(s)" }
if ($skippedCount -gt 0) { $stats["Skipped"] = "$skippedCount folder(s)" }

if ($failCount -eq 0 -and $successCount -gt 0) {
    Show-Success -Title "Cleanup Complete" -Stats $stats
} else {
    Write-Header "Cleanup Complete"
    foreach ($key in $stats.Keys) {
        $color = switch ($key) {
            "Cleaned" { $Colors.Success }
            "Failed" { $Colors.Error }
            "Skipped" { $Colors.Warning }
        }
        Write-Host "      $($key):".PadRight(12) -NoNewline -ForegroundColor $Colors.Dim
        Write-Host $stats[$key] -ForegroundColor $color
    }
}

Write-Host ""
Write-Status "Log: $logFile"
Write-Host ""

Write-Log "=== Completed: $successCount success, $failCount failed, $skippedCount skipped ===" -LogFile $logFile

exit $(if ($failCount -gt 0) { 1 } else { 0 })
