@echo off
:: Tableau Workbook Scrubber - One-Time Installation
:: Creates desktop shortcut, commands, and installs skill files

echo.
echo ======================================
echo   Tableau Workbook Scrubber - Install
echo ======================================
echo.

set "SCRIPT_DIR=%~dp0"
set "SKILL_SRC=%SCRIPT_DIR%..\..\claude-skill"
set "SKILL_DEST=%USERPROFILE%\.claude\skills\tableau-cleanup"
set "DESKTOP=%USERPROFILE%\Desktop"
set "CMD_DIR=%USERPROFILE%\.iw-tableau-cleanup\bin"

:: Create directories
if not exist "%CMD_DIR%" mkdir "%CMD_DIR%"
if not exist "%USERPROFILE%\.claude\skills" mkdir "%USERPROFILE%\.claude\skills"

:: Copy skill files
echo Installing skill files...
if exist "%SKILL_SRC%" (
    xcopy /E /I /Y "%SKILL_SRC%" "%SKILL_DEST%" > nul 2>&1
    echo   [OK] Skill installed to: %SKILL_DEST%
) else (
    echo   [!] Warning: Skill source not found at %SKILL_SRC%
)

:: Create desktop shortcut for main menu
echo Creating desktop shortcut...
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%DESKTOP%\Tableau Scrubber.lnk'); $s.TargetPath = 'powershell.exe'; $s.Arguments = '-ExecutionPolicy Bypass -File \"%SCRIPT_DIR%tableau-scrubber.ps1\"'; $s.WorkingDirectory = '%SCRIPT_DIR%'; $s.IconLocation = 'shell32.dll,21'; $s.Description = 'Tableau Workbook Scrubber'; $s.Save()"

:: Create batch commands
echo Creating commands...

:: Main unified command: tableau-scrubber
(
echo @echo off
echo :: Tableau Workbook Scrubber - Main Entry Point
echo powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%tableau-scrubber.ps1" %%*
) > "%CMD_DIR%\tableau-scrubber.bat"
echo   [OK] tableau-scrubber

:: Individual shortcuts (for convenience)
(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%configure.ps1" %%*
) > "%CMD_DIR%\tableau-setup.bat"
echo   [OK] tableau-setup

(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-cleanup.ps1" %%*
) > "%CMD_DIR%\tableau-clean.bat"
echo   [OK] tableau-clean

(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install-schedule.ps1" %%*
) > "%CMD_DIR%\tableau-schedule.bat"
echo   [OK] tableau-schedule

(
echo @echo off
echo echo Stopping Tableau Cleanup...
echo taskkill /F /IM "claude.exe" 2^>nul
echo taskkill /F /FI "WINDOWTITLE eq Tableau Cleanup*" 2^>nul
echo echo Cancelled.
) > "%CMD_DIR%\tableau-cancel.bat"
echo   [OK] tableau-cancel

:: Add to PATH if not already there
echo.
echo Checking PATH...
echo %PATH% | find /i "%CMD_DIR%" > nul
if errorlevel 1 (
    echo Adding commands to PATH...
    setx PATH "%PATH%;%CMD_DIR%" > nul 2>&1
    echo   [OK] Commands added to PATH
    echo.
    echo   NOTE: Close and reopen cmd/PowerShell for commands to work.
) else (
    echo   [OK] Commands already in PATH
)

:: Run PowerShell setup for profile function
echo.
echo Setting up PowerShell profile...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-command.ps1" -CmdOnly > nul 2>&1

:: Install Chafa for colored banner (optional but cool!)
echo.
echo ======================================
echo   Installing Colored Banner (Chafa)
echo ======================================
echo.

:: Check if Chafa is already installed
where chafa >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Chafa already installed
    goto :chafa_done
)

:: Check if Scoop is installed
where scoop >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Scoop already installed
    goto :install_chafa
)

:: Install Scoop
echo   Installing Scoop (Windows package manager)...
echo   This enables the colored ASCII art banner.
echo.
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression" 2>nul
if %errorlevel% neq 0 (
    echo   [!] Could not install Scoop - using fallback banner
    goto :chafa_done
)
echo   [OK] Scoop installed

:install_chafa
echo   Installing Chafa...
call scoop install chafa >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Chafa installed - colored banner enabled!
) else (
    echo   [!] Could not install Chafa - using fallback banner
)

:chafa_done

:: Copy banner image to assets folder
echo.
echo Copying banner image...
set "ASSETS_DIR=%SCRIPT_DIR%assets"
if not exist "%ASSETS_DIR%" mkdir "%ASSETS_DIR%"
set "BANNER_SRC=%SCRIPT_DIR%..\..\Temp Documenation for CLI update\ChatGPT Image Jan 7, 2026, 01_31_56 PM.png"
if exist "%BANNER_SRC%" (
    copy /Y "%BANNER_SRC%" "%ASSETS_DIR%\banner.png" >nul 2>&1
    echo   [OK] Banner image copied to assets folder
) else (
    echo   [!] Banner image not found (will use fallback)
)

echo.
echo ======================================
echo   Installation Complete!
echo ======================================
echo.
echo You can now:
echo.
echo   1. Double-click "Tableau Scrubber" on your desktop
echo.
echo   2. Or open cmd/PowerShell and type:
echo.
echo      tableau-scrubber     Main menu (interactive)
echo      tableau-scrubber -Action clean
echo      tableau-scrubber -Action configure
echo      tableau-scrubber -Action schedule
echo      tableau-scrubber -Action logs
echo      tableau-scrubber -Help
echo.
echo   Shortcuts:
echo      tableau-clean        Run cleanup now
echo      tableau-setup        Configure folders
echo      tableau-schedule     Set up daily schedule
echo      tableau-cancel       Stop if running
echo.
echo ======================================
echo.
pause
