@echo off
:: Tableau Cleanup Agent - Quick Setup
:: Double-click this file or run "setup" from this folder

powershell -ExecutionPolicy Bypass -File "%~dp0configure.ps1"
pause
