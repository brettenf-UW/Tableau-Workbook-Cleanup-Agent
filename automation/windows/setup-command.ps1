# Tableau Workbook Scrubber - Command Setup
# Adds 'tableau-scrubber' command to PowerShell profile AND cmd.exe PATH

param(
    [switch]$Uninstall,
    [switch]$PowerShellOnly,
    [switch]$CmdOnly
)

$ErrorActionPreference = "Stop"

# Get paths
$ScriptDir = $PSScriptRoot
$MainScript = Join-Path $ScriptDir "tableau-scrubber.ps1"
$BatchScript = Join-Path $ScriptDir "tableau-scrubber.bat"
$ProfilePath = $PROFILE.CurrentUserAllHosts
$BinDir = Join-Path $env:USERPROFILE ".iw-tableau-cleanup\bin"

# The function to add to profile
$FunctionBlock = @"

# Tableau Workbook Scrubber - Added by setup-command.ps1
function tableau-scrubber {
    & "$MainScript" @args
}
# End Tableau Workbook Scrubber

"@

function Install-PowerShellCommand {
    Write-Host ""
    Write-Host "    --- PowerShell Setup ---" -ForegroundColor Yellow

    # Check if main script exists
    if (-not (Test-Path $MainScript)) {
        Write-Host "    [X] Error: tableau-scrubber.ps1 not found" -ForegroundColor Red
        return $false
    }

    # Create profile if it doesn't exist
    if (-not (Test-Path $ProfilePath)) {
        $profileDir = Split-Path $ProfilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
        Write-Host "    [OK] Created PowerShell profile" -ForegroundColor Green
    }

    # Check if already installed
    $existingContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($existingContent -match "# Tableau Workbook Scrubber - Added by setup-command.ps1") {
        # Remove existing
        $pattern = "(?s)\r?\n# Tableau Workbook Scrubber - Added by setup-command\.ps1.*?# End Tableau Workbook Scrubber\r?\n"
        $existingContent = $existingContent -replace $pattern, ""
        Set-Content $ProfilePath -Value $existingContent.TrimEnd()
        Write-Host "    [OK] Removed old PowerShell command" -ForegroundColor DarkGray
    }

    # Add to profile
    Add-Content $ProfilePath -Value $FunctionBlock
    Write-Host "    [OK] Added 'tableau-scrubber' to PowerShell profile" -ForegroundColor Green
    Write-Host "         $ProfilePath" -ForegroundColor DarkGray

    return $true
}

function Install-CmdCommand {
    Write-Host ""
    Write-Host "    --- CMD Setup ---" -ForegroundColor Yellow

    # Check if batch script exists
    if (-not (Test-Path $BatchScript)) {
        Write-Host "    [X] Error: tableau-scrubber.bat not found" -ForegroundColor Red
        return $false
    }

    # Create bin directory
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
        Write-Host "    [OK] Created bin directory" -ForegroundColor Green
    }

    # Copy batch file to bin directory (update path inside it first)
    $batchContent = @"
@echo off
:: Tableau Workbook Scrubber - CMD Wrapper
:: Allows running 'tableau-scrubber' from cmd.exe

setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$MainScript" %*
endlocal
"@
    Set-Content (Join-Path $BinDir "tableau-scrubber.bat") -Value $batchContent
    Write-Host "    [OK] Installed tableau-scrubber.bat" -ForegroundColor Green
    Write-Host "         $BinDir" -ForegroundColor DarkGray

    # Check if bin dir is already in PATH
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$BinDir*") {
        # Add to user PATH
        $newPath = if ($userPath) { "$userPath;$BinDir" } else { $BinDir }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "    [OK] Added bin directory to PATH" -ForegroundColor Green
        Write-Host "         (New cmd windows will have the command)" -ForegroundColor DarkGray
    } else {
        Write-Host "    [OK] Bin directory already in PATH" -ForegroundColor DarkGray
    }

    return $true
}

function Uninstall-PowerShellCommand {
    Write-Host ""
    Write-Host "    --- Removing PowerShell Setup ---" -ForegroundColor Yellow

    if (Test-Path $ProfilePath) {
        $content = Get-Content $ProfilePath -Raw
        if ($content -match "# Tableau Workbook Scrubber - Added by setup-command.ps1") {
            $pattern = "(?s)\r?\n# Tableau Workbook Scrubber - Added by setup-command\.ps1.*?# End Tableau Workbook Scrubber\r?\n"
            $newContent = $content -replace $pattern, ""
            Set-Content $ProfilePath -Value $newContent.TrimEnd()
            Write-Host "    [OK] Removed from PowerShell profile" -ForegroundColor Green
        } else {
            Write-Host "    [!] Command not found in profile" -ForegroundColor Yellow
        }
    }
}

function Uninstall-CmdCommand {
    Write-Host ""
    Write-Host "    --- Removing CMD Setup ---" -ForegroundColor Yellow

    $batFile = Join-Path $BinDir "tableau-scrubber.bat"
    if (Test-Path $batFile) {
        Remove-Item $batFile -Force
        Write-Host "    [OK] Removed tableau-scrubber.bat" -ForegroundColor Green
    }

    # Remove from PATH
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -like "*$BinDir*") {
        $newPath = ($userPath -split ";" | Where-Object { $_ -ne $BinDir }) -join ";"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "    [OK] Removed bin directory from PATH" -ForegroundColor Green
    }
}

# Banner
Write-Host ""
Write-Host "    TABLEAU WORKBOOK SCRUBBER - Command Setup" -ForegroundColor Yellow
Write-Host "    ==========================================" -ForegroundColor Yellow

# Handle uninstall
if ($Uninstall) {
    if (-not $CmdOnly) { Uninstall-PowerShellCommand }
    if (-not $PowerShellOnly) { Uninstall-CmdCommand }
    Write-Host ""
    Write-Host "    Uninstall complete." -ForegroundColor Green
    Write-Host "    Restart your terminal for changes to take effect." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# Install
Write-Host ""
Write-Host "    This will set up 'tableau-scrubber' command for:" -ForegroundColor White
if (-not $CmdOnly) { Write-Host "      - PowerShell (via profile function)" -ForegroundColor DarkGray }
if (-not $PowerShellOnly) { Write-Host "      - CMD (via batch file in PATH)" -ForegroundColor DarkGray }
Write-Host ""

$psSuccess = $true
$cmdSuccess = $true

if (-not $CmdOnly) {
    $psSuccess = Install-PowerShellCommand
}

if (-not $PowerShellOnly) {
    $cmdSuccess = Install-CmdCommand
}

# Summary
Write-Host ""
Write-Host "    ==========================================" -ForegroundColor Green
Write-Host "    Setup Complete!" -ForegroundColor Green
Write-Host "    ==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "    Usage:" -ForegroundColor Yellow
Write-Host "      tableau-scrubber              (interactive menu)" -ForegroundColor DarkGray
Write-Host "      tableau-scrubber -Action clean" -ForegroundColor DarkGray
Write-Host "      tableau-scrubber -Help" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    Next steps:" -ForegroundColor Yellow
if ($psSuccess -and -not $CmdOnly) {
    Write-Host "      PowerShell: Run '. `$PROFILE' or restart PowerShell" -ForegroundColor DarkGray
}
if ($cmdSuccess -and -not $PowerShellOnly) {
    Write-Host "      CMD: Open a new command prompt window" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "    To uninstall: .\setup-command.ps1 -Uninstall" -ForegroundColor DarkGray
Write-Host ""

# Offer to reload PowerShell profile
if ($psSuccess -and -not $CmdOnly) {
    $reload = Read-Host "    Load PowerShell command now? (Y/n)"
    if ($reload -ne "n" -and $reload -ne "N") {
        . $ProfilePath
        Write-Host ""
        Write-Host "    [OK] Profile reloaded. You can now use 'tableau-scrubber' in PowerShell" -ForegroundColor Green
        Write-Host ""
    }
}
