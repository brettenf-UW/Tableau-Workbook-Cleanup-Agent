@echo off
setlocal EnableDelayedExpansion
REM Tableau Cleanup Agent - Windows Installer (CMD)
REM Copies skill files to user's Claude skills folder

echo.
echo   Tableau Cleanup Agent - Install
echo   ================================
echo.

REM Get script directory (handles spaces in path)
set "SOURCE=%~dp0claude-skill"
set "DEST=%USERPROFILE%\.claude\skills\tableau-cleanup"

REM Check if claude-skill folder exists
if not exist "%SOURCE%\" (
    echo   ERROR: claude-skill\ folder not found
    echo   Make sure you're running from the project root
    goto :error
)

REM Copy files using robocopy (modern, reliable)
echo   Copying skill files...
robocopy "%SOURCE%" "%DEST%" /E /NFL /NDL /NJH /NJS /NC /NS >nul 2>&1

REM robocopy returns 0-7 for success, 8+ for errors
if %ERRORLEVEL% GEQ 8 (
    echo   ERROR: Failed to copy files
    goto :error
)

echo.
echo   SUCCESS! Skill installed to:
echo   %DEST%
echo.
echo   Next steps:
echo   1. Run 'tableau-setup' to configure watch folders
echo   2. Run 'tableau-clean' to clean workbooks
echo.
echo   See README.md for full documentation
echo.
goto :done

:error
echo.
echo   Installation failed.
echo.

:done
endlocal
pause
