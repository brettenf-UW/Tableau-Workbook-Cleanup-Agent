@echo off
:: Tableau Cleanup Agent - One-Time Installation
:: Creates desktop shortcut, commands, and installs skill files

echo.
echo ======================================
echo   Tableau Cleanup Agent - Install
echo ======================================
echo.

set "SCRIPT_DIR=%~dp0"
set "SKILL_SRC=%SCRIPT_DIR%..\..\\.claude\skills\tableau-cleanup"
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
    echo   Skill installed to: %SKILL_DEST%
) else (
    echo   Warning: Skill source not found at %SKILL_SRC%
)

:: Create desktop shortcut for Setup
echo Creating desktop shortcut...
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%DESKTOP%\Tableau Cleanup Setup.lnk'); $s.TargetPath = 'powershell.exe'; $s.Arguments = '-ExecutionPolicy Bypass -File \"%SCRIPT_DIR%configure.ps1\"'; $s.WorkingDirectory = '%SCRIPT_DIR%'; $s.IconLocation = 'shell32.dll,21'; $s.Description = 'Configure Tableau Cleanup Agent'; $s.Save()"

:: Create simple batch commands
echo Creating simple commands...

:: tableau-setup command
(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%configure.ps1" %%*
) > "%CMD_DIR%\tableau-setup.bat"

:: tableau-clean command
(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-cleanup.ps1" %%*
) > "%CMD_DIR%\tableau-clean.bat"

:: tableau-schedule command
(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install-schedule.ps1" %%*
) > "%CMD_DIR%\tableau-schedule.bat"

:: tableau-cancel command
(
echo @echo off
echo echo Stopping Tableau Cleanup...
echo taskkill /F /IM "claude.exe" 2^>nul
echo taskkill /F /FI "WINDOWTITLE eq Tableau Cleanup*" 2^>nul
echo echo Cancelled.
) > "%CMD_DIR%\tableau-cancel.bat"

:: Add to PATH if not already there
echo.
echo Checking PATH...
echo %PATH% | find /i "%CMD_DIR%" > nul
if errorlevel 1 (
    echo Adding commands to PATH...
    setx PATH "%PATH%;%CMD_DIR%" > nul 2>&1
    echo.
    echo NOTE: Close and reopen cmd for commands to work.
) else (
    echo Commands already in PATH.
)

echo.
echo ======================================
echo   Installation Complete!
echo ======================================
echo.
echo You can now:
echo.
echo   1. Double-click "Tableau Cleanup Setup" on your desktop
echo.
echo   2. Or open cmd and type:
echo      tableau-setup     - Configure folders
echo      tableau-clean     - Run cleanup now
echo      tableau-cancel    - Stop cleanup if running
echo      tableau-schedule  - Set up daily schedule
echo.
echo ======================================
echo.
pause
