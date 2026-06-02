@echo off
setlocal

set TARGET=%1
if "%TARGET%"=="" (
    echo Usage: update.bat ^<user@server-ip^>
    echo Example: update.bat root@204.168.211.182
    exit /b 1
)

rem Allow plain IP or user@ip format
echo %TARGET% | findstr "@" >nul
if %errorlevel%==0 (
    for /f "tokens=1,2 delims=@" %%a in ("%TARGET%") do (
        set REMOTE_USER=%%a
        set SERVER_IP=%%b
    )
) else (
    set REMOTE_USER=root
    set SERVER_IP=%TARGET%
)

echo Updating %REMOTE_USER%@%SERVER_IP%...
ssh %REMOTE_USER%@%SERVER_IP% "git -C /opt/studyguides pull && /opt/studyguides/venv/bin/pip install -q -r /opt/studyguides/requirements.txt && systemctl restart studyguides-chat && echo Done."
if %errorlevel% neq 0 ( echo ERROR: Update failed & exit /b 1 )

echo.
echo Update complete! Site: http://%SERVER_IP%/studyguides/