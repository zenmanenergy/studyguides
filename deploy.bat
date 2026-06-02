@echo off
setlocal

set TARGET=%1
if "%TARGET%"=="" (
    echo Usage: deploy.bat ^<user@server-ip^>
    echo Example: deploy.bat root@204.168.211.182
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

echo First-time setup on %REMOTE_USER%@%SERVER_IP%...

echo Uploading setup script...
scp server_setup.sh %REMOTE_USER%@%SERVER_IP%:/tmp/server_setup.sh
if %errorlevel% neq 0 ( echo ERROR: Upload failed & exit /b 1 )

echo Running setup (clones from GitHub and installs everything)...
ssh %REMOTE_USER%@%SERVER_IP% "bash /tmp/server_setup.sh"
if %errorlevel% neq 0 ( echo ERROR: Setup failed & exit /b 1 )

echo.
echo Setup complete!
echo Site: http://%SERVER_IP%/studyguides/
echo.
echo Set your API key on the server:
echo   ssh %REMOTE_USER%@%SERVER_IP%
echo   nano /opt/studyguides/.env
echo   systemctl restart studyguides-chat
echo.
echo For future updates, run: update.bat %TARGET%
