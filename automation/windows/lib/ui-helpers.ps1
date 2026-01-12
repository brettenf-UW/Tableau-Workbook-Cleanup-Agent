# Tableau Workbook Scrubber - Shared UI Helper Functions
# Provides consistent styling across all CLI scripts

$Script:Colors = @{
    Gold = "Yellow"
    LightBlue = "Cyan"
    MediumBlue = "DarkCyan"
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Dim = "DarkGray"
    Body = "White"
}

function Show-Banner {
    param([switch]$Compact)

    if ($Compact) {
        Write-Host ""
        Write-Host "    TABLEAU WORKBOOK SCRUBBER" -ForegroundColor $Colors.Gold
        Write-Host "    Automated cleanup powered by Claude" -ForegroundColor $Colors.Dim
        Write-Host ""
        return
    }

    $assetsPath = Join-Path $PSScriptRoot "..\assets\banner.png"
    $legacyPath = Join-Path $PSScriptRoot "..\..\..\Temp Documenation for CLI update\ChatGPT Image Jan 7, 2026, 01_31_56 PM.png"
    $imagePath = if (Test-Path $assetsPath) { $assetsPath } elseif (Test-Path $legacyPath) { $legacyPath } else { $null }

    $chafaCmd = Get-Command "chafa" -ErrorAction SilentlyContinue
    if ($chafaCmd -and $imagePath) {
        $resolvedPath = (Resolve-Path $imagePath).Path
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd"
        $psi.Arguments = "/c chafa --size=60x20 --symbols=block `"$resolvedPath`""
        $psi.UseShellExecute = $false
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
    }

    Write-Host ""
    Write-Host "                                           Powered by InterWorks" -ForegroundColor $Colors.Body
    Write-Host ""
}

function Show-MenuBox {
    param(
        [string]$Title,
        [array]$Options
    )

    Write-Host ""
    Write-Host "    +--------------------------------------------------------------+" -ForegroundColor $Colors.Dim
    $titleTrunc = if ($Title.Length -gt 60) { $Title.Substring(0, 57) + "..." } else { $Title }
    Write-Host "    | $($titleTrunc.PadRight(60)) |" -ForegroundColor $Colors.Body
    Write-Host "    +--------------------------------------------------------------+" -ForegroundColor $Colors.Dim
    Write-Host "    |                                                              |" -ForegroundColor $Colors.Dim

    foreach ($item in $Options) {
        $keyStr = "$($item.Key). "
        $labelStr = if ($item.Label.Length -gt 20) { $item.Label.Substring(0, 17) + "..." } else { $item.Label.PadRight(20) }
        $descStr = if ($item.Desc) {
            if ($item.Desc.Length -gt 36) { $item.Desc.Substring(0, 33) + "..." } else { $item.Desc.PadRight(36) }
        } else { "".PadRight(36) }

        Write-Host "    | " -NoNewline -ForegroundColor $Colors.Dim
        Write-Host $keyStr -NoNewline -ForegroundColor $Colors.Gold
        Write-Host $labelStr -NoNewline -ForegroundColor $Colors.Body
        Write-Host " $descStr" -NoNewline -ForegroundColor $Colors.Dim
        Write-Host " |" -ForegroundColor $Colors.Dim
    }

    Write-Host "    |                                                              |" -ForegroundColor $Colors.Dim
    Write-Host "    +--------------------------------------------------------------+" -ForegroundColor $Colors.Dim
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "    === $Text ===" -ForegroundColor $Colors.Gold
    Write-Host ""
}

function Write-SubHeader {
    param([string]$Text)
    Write-Host ""
    Write-Host "    $Text" -ForegroundColor $Colors.LightBlue
    Write-Host "    $('-' * $Text.Length)" -ForegroundColor $Colors.Dim
}

function Write-Step {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor $Colors.LightBlue
}

function Write-Status {
    param([string]$Message)
    Write-Host "      $Message" -ForegroundColor $Colors.Dim
}

function Write-Good {
    param([string]$Message)
    Write-Host "      [OK] " -NoNewline -ForegroundColor $Colors.Success
    Write-Host $Message -ForegroundColor $Colors.Body
}

function Write-Bad {
    param([string]$Message)
    Write-Host "      [!] " -NoNewline -ForegroundColor $Colors.Warning
    Write-Host $Message -ForegroundColor $Colors.Body
}

function Write-Fail {
    param([string]$Message)
    Write-Host "      [X] " -NoNewline -ForegroundColor $Colors.Error
    Write-Host $Message -ForegroundColor $Colors.Body
}

function Write-Info {
    param([string]$Message)
    Write-Host "      [i] " -NoNewline -ForegroundColor $Colors.LightBlue
    Write-Host $Message -ForegroundColor $Colors.Body
}

function Show-PassHeader {
    param([int]$Current, [int]$Max)
    Write-Host ""
    Write-Host "    +------------------------+" -ForegroundColor $Colors.Gold
    $text = "  PASS $Current of $Max"
    Write-Host "    |$($text.PadRight(24))|" -ForegroundColor $Colors.Gold
    Write-Host "    +------------------------+" -ForegroundColor $Colors.Gold
}

function Show-ErrorTable {
    param($Errors)

    Write-Host ""
    Write-Host "    +------------+-----------+------------------+" -ForegroundColor $Colors.Dim
    Write-Host "    | Category   | # Issues  | Description      |" -ForegroundColor $Colors.Body
    Write-Host "    +------------+-----------+------------------+" -ForegroundColor $Colors.Dim

    $categories = @(
        @{ Name = "Captions"; Count = $Errors.Caption; Desc = "naming issues" }
        @{ Name = "Comments"; Count = $Errors.Comment; Desc = "bad comments" }
        @{ Name = "Folders"; Count = $Errors.Folder; Desc = "organization" }
        @{ Name = "XML"; Count = $Errors.XML; Desc = "syntax errors" }
    )

    foreach ($cat in $categories) {
        if ($cat.Count -gt 0) {
            $color = if ($cat.Count -gt 10) { $Colors.Error } else { $Colors.Warning }
            Write-Host "    | $($cat.Name.PadRight(10)) | " -NoNewline -ForegroundColor $Colors.Dim
            Write-Host $cat.Count.ToString().PadLeft(9) -NoNewline -ForegroundColor $color
            Write-Host " | $($cat.Desc.PadRight(16)) |" -ForegroundColor $Colors.Dim
        }
    }

    Write-Host "    +------------+-----------+------------------+" -ForegroundColor $Colors.Dim
    Write-Host "    | TOTAL      | " -NoNewline -ForegroundColor $Colors.Dim
    $totalColor = if ($Errors.Total -eq 0) { $Colors.Success } else { $Colors.Body }
    Write-Host $Errors.Total.ToString().PadLeft(9) -NoNewline -ForegroundColor $totalColor
    Write-Host " |                  |" -ForegroundColor $Colors.Dim
    Write-Host "    +------------+-----------+------------------+" -ForegroundColor $Colors.Dim
}

function Show-Success {
    param([string]$Title, [hashtable]$Stats)

    Write-Host ""
    Write-Host "    +--------------------------------------+" -ForegroundColor $Colors.Success
    $t = if ($Title.Length -gt 34) { $Title.Substring(0, 31) + "..." } else { $Title.ToUpper() }
    Write-Host "    | $($t.PadRight(36)) |" -ForegroundColor $Colors.Success
    Write-Host "    |                                      |" -ForegroundColor $Colors.Success

    foreach ($key in $Stats.Keys) {
        $k = $key.PadRight(18).Substring(0, 18)
        $v = $Stats[$key].ToString().PadLeft(14).Substring(0, 14)
        Write-Host "    | $k $v   |" -ForegroundColor $Colors.Body
    }

    Write-Host "    |                                      |" -ForegroundColor $Colors.Success
    Write-Host "    +--------------------------------------+" -ForegroundColor $Colors.Success
}

function Show-Failure {
    param([string]$Title, [string]$Message)

    Write-Host ""
    Write-Host "    +--------------------------------------+" -ForegroundColor $Colors.Error
    $t = if ($Title.Length -gt 34) { $Title.Substring(0, 31) + "..." } else { $Title.ToUpper() }
    Write-Host "    | $($t.PadRight(36)) |" -ForegroundColor $Colors.Error
    Write-Host "    |                                      |" -ForegroundColor $Colors.Error
    $m = if ($Message.Length -gt 34) { $Message.Substring(0, 31) + "..." } else { $Message }
    Write-Host "    | $($m.PadRight(36)) |" -ForegroundColor $Colors.Body
    Write-Host "    |                                      |" -ForegroundColor $Colors.Error
    Write-Host "    +--------------------------------------+" -ForegroundColor $Colors.Error
}

function Show-Logs {
    param([switch]$Interactive)

    $logFolder = Join-Path $env:USERPROFILE ".iw-tableau-cleanup\logs"

    if (-not (Test-Path $logFolder)) {
        Write-Header "Recent Cleanup Logs"
        Write-Status "No logs found yet. Run a cleanup to generate logs."
        return
    }

    $logs = Get-ChildItem $logFolder -Filter "*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 10

    if ($logs.Count -eq 0) {
        Write-Header "Recent Cleanup Logs"
        Write-Status "No logs found yet. Run a cleanup to generate logs."
        return
    }

    # Loop for interactive mode
    $keepShowing = $true
    while ($keepShowing) {
        Write-Header "Recent Cleanup Logs"
        Write-Host ""
        Write-Host "    +----+------------------+----------------------------------+----------+--------------+" -ForegroundColor $Colors.Dim
        Write-Host "    | #  | Date             | Workbook                         | Status   | Issues Fixed |" -ForegroundColor $Colors.Body
        Write-Host "    +----+------------------+----------------------------------+----------+--------------+" -ForegroundColor $Colors.Dim

        $logData = @()
        $i = 1
        foreach ($log in $logs) {
            $date = $log.LastWriteTime.ToString("MMM dd HH:mm")
            $content = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue
            $status = "Unknown"
            $issuesFixed = "-"
            $workbook = "-"

            if ($content) {
                # Extract workbook name
                if ($content -match "Found:\s*(.+?\.twb)" -or $content -match "workbook[:\s]+(.+?\.twb)") {
                    $workbook = $Matches[1]
                    if ($workbook.Length -gt 32) { $workbook = $workbook.Substring(0, 29) + "..." }
                }

                # Determine status
                if ($content -match "Validation passed|All Checks Passed") { $status = "Success" }
                elseif ($content -match "FAILED|Error running") { $status = "Failed" }
                else { $status = "Partial" }

                # Extract issues fixed (initial - final)
                if ($content -match "initial_errors[`":\s]+(\d+)" -and $content -match "final_errors[`":\s]+(\d+)") {
                    $initial = [int]$Matches[1]
                    # Re-match for final
                    if ($content -match "final_errors[`":\s]+(\d+)") {
                        $final = [int]$Matches[1]
                        $issuesFixed = ($initial - $final).ToString()
                    }
                } elseif ($content -match "(\d+)\s*errors?\s*fixed") {
                    $issuesFixed = $Matches[1]
                } elseif ($status -eq "Success") {
                    $issuesFixed = "0"
                }
            }

            $statusColor = switch ($status) {
                "Success" { $Colors.Success }
                "Failed" { $Colors.Error }
                default { $Colors.Warning }
            }

            $logData += @{ Log = $log; Workbook = $workbook }

            Write-Host "    | " -NoNewline -ForegroundColor $Colors.Dim
            Write-Host $i.ToString().PadRight(2) -NoNewline -ForegroundColor $Colors.Gold
            Write-Host " | $($date.PadRight(16)) | $($workbook.PadRight(32)) | " -NoNewline -ForegroundColor $Colors.Dim
            Write-Host $status.PadRight(8) -NoNewline -ForegroundColor $statusColor
            Write-Host " | $($issuesFixed.PadLeft(12)) |" -ForegroundColor $Colors.Dim
            $i++
        }

        Write-Host "    +----+------------------+----------------------------------+----------+--------------+" -ForegroundColor $Colors.Dim
        Write-Host ""
        Write-Host "    Log folder: $logFolder" -ForegroundColor $Colors.Dim

        if ($Interactive) {
            Write-Host ""
            Write-Host "    Enter # to open log in Notepad, or B to go back" -ForegroundColor $Colors.Dim
            $choice = Get-UserChoice -Prompt "Select:"

            if ($choice -match '^[Bb]$' -or [string]::IsNullOrWhiteSpace($choice)) {
                $keepShowing = $false
            }
            elseif ($choice -match '^\d+$') {
                $idx = [int]$choice - 1
                if ($idx -ge 0 -and $idx -lt $logs.Count) {
                    $selectedLog = $logs[$idx]

                    # Show Claude's summary preview (last 20 lines)
                    Clear-Host
                    Show-Banner -Compact
                    Write-Header "Log Preview: $($selectedLog.Name)"

                    $logContent = Get-Content $selectedLog.FullName -ErrorAction SilentlyContinue
                    if ($logContent) {
                        $previewLines = $logContent | Select-Object -Last 20
                        Write-Host ""
                        Write-Host "    --- Last 20 lines ---" -ForegroundColor $Colors.Dim
                        foreach ($line in $previewLines) {
                            # Truncate long lines for display
                            $displayLine = if ($line.Length -gt 80) { $line.Substring(0, 77) + "..." } else { $line }
                            Write-Host "    $displayLine" -ForegroundColor $Colors.Body
                        }
                        Write-Host "    --- End preview ---" -ForegroundColor $Colors.Dim
                    } else {
                        Write-Status "Log file is empty or could not be read."
                    }

                    Write-Host ""
                    $openChoice = Get-UserConfirmation -Prompt "Open full log in Notepad?" -DefaultYes $true
                    if ($openChoice) {
                        Start-Process notepad.exe -ArgumentList $selectedLog.FullName
                        Write-Good "Opened log in Notepad"
                    }

                    Write-Host ""
                    Write-Host "    Press Enter to continue..." -ForegroundColor $Colors.Dim
                    Read-Host | Out-Null
                    Clear-Host
                    Show-Banner -Compact
                } else {
                    Write-Bad "Invalid selection"
                    Start-Sleep -Seconds 1
                }
            } else {
                Write-Bad "Invalid selection"
                Start-Sleep -Seconds 1
            }
        } else {
            $keepShowing = $false
        }
    }
}

function Show-FolderList {
    param($Config)

    if ($Config.folders.Count -eq 0) {
        Write-Status "(no folders configured)"
        return
    }

    Write-Host ""
    $i = 1
    foreach ($folder in $Config.folders) {
        $status = if ($folder.enabled) { "[ON]" } else { "[OFF]" }
        $statusColor = if ($folder.enabled) { $Colors.Success } else { $Colors.Dim }

        Write-Host "    $i. " -NoNewline -ForegroundColor $Colors.Gold
        Write-Host $folder.name -NoNewline -ForegroundColor $Colors.Body
        Write-Host "  " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
        Write-Host "       Path:     " -NoNewline -ForegroundColor $Colors.Dim
        Write-Host $folder.path -ForegroundColor $Colors.Body
        Write-Host "       Schedule: " -NoNewline -ForegroundColor $Colors.Dim
        Write-Host $folder.schedule -ForegroundColor $Colors.Body
        if ($folder.last_run) {
            Write-Host "       Last Run: " -NoNewline -ForegroundColor $Colors.Dim
            Write-Host $folder.last_run -ForegroundColor $Colors.Dim
        }
        Write-Host ""
        $i++
    }
}

function Get-UserChoice {
    param([string]$Prompt, [string]$Default = "")

    if ($Default) {
        Write-Host "    $Prompt [$Default]: " -NoNewline -ForegroundColor $Colors.Body
    } else {
        Write-Host "    $Prompt " -NoNewline -ForegroundColor $Colors.Body
    }

    $userInput = Read-Host
    if ([string]::IsNullOrWhiteSpace($userInput) -and $Default) {
        return $Default
    }
    return $userInput
}

function Get-UserConfirmation {
    param([string]$Prompt, [bool]$DefaultYes = $false)

    $hint = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    Write-Host "    $Prompt $hint " -NoNewline -ForegroundColor $Colors.Body
    $userInput = Read-Host

    if ([string]::IsNullOrWhiteSpace($userInput)) {
        return $DefaultYes
    }
    return $userInput.ToUpper() -eq "Y"
}

function Show-Spinner {
    param([string]$Message, [scriptblock]$Action)

    $spinChars = @('|', '/', '-', '\')
    $job = Start-Job -ScriptBlock $Action

    $i = 0
    while ($job.State -eq 'Running') {
        Write-Host "`r    $($spinChars[$i % 4]) $Message" -NoNewline -ForegroundColor $Colors.LightBlue
        Start-Sleep -Milliseconds 100
        $i++
    }

    $result = Receive-Job -Job $job
    Remove-Job -Job $job

    Write-Host "`r    $(' ' * ($Message.Length + 6))`r" -NoNewline
    return $result
}
