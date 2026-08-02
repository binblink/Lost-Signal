@echo off
REM Delegate executable discovery and test execution to the PowerShell runner.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_tests.ps1"
exit /b %ERRORLEVEL%
