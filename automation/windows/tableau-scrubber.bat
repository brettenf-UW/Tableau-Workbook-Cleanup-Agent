@echo off
:: Tableau Workbook Scrubber - CMD Wrapper
:: Allows running 'tableau-scrubber' from cmd.exe
::
:: Usage: tableau-scrubber [options]
::   -Action clean|configure|schedule|logs
::   -WorkbookPath "path\to\workbook.twb"
::   -Help
::   -Version

setlocal

:: Get the directory where this batch file lives
set "SCRIPT_DIR=%~dp0"

:: Call the PowerShell script with all arguments passed through
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%tableau-scrubber.ps1" %*

endlocal
