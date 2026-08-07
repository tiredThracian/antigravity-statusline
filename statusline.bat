@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\ibrah\.gemini\antigravity-cli\statusline.ps1 %*
exit /b %ERRORLEVEL%
