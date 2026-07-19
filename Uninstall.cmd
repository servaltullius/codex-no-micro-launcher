@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\OpenAI\CodexNoMicro\Codex-No-Micro.ps1" -Action Uninstall
set "exitCode=%ERRORLEVEL%"
echo.
if not "%exitCode%"=="0" echo Uninstallation failed with exit code %exitCode%.
pause
exit /b %exitCode%
