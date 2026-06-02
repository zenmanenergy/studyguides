@echo off
setlocal

set TARGET=%1
if "%TARGET%"=="" (
    echo Usage: deploy.bat ^<user@server-ip^>
    echo Example: deploy.bat snelson@204.168.211.182
    exit /b 1
)

rem Allow plain IP with default user, or user@ip format
echo %TARGET% | findstr "@" >nul
if %errorlevel%==0 (
    for /f "tokens=1,2 delims=@" %%a in ("%TARGET%") do (
        set REMOTE_USER=%%a
        set SERVER_IP=%%b
    )
) else (
    set REMOTE_USER=%USERNAME%
    set SERVER_IP=%TARGET%
)

set UPLOAD_DIR=/tmp/studyguides_upload

echo Deploying to %REMOTE_USER%@%SERVER_IP%...

echo Creating upload directory on server...
ssh %REMOTE_USER%@%SERVER_IP% "rm -rf %UPLOAD_DIR% && mkdir -p %UPLOAD_DIR%"
if %errorlevel% neq 0 ( echo ERROR: SSH connection failed & exit /b 1 )

echo Copying files...
scp -r subjects chat_server.py requirements.txt .env.example studyguides-chat.service server_setup.sh %REMOTE_USER%@%SERVER_IP%:%UPLOAD_DIR%/
if %errorlevel% neq 0 ( echo ERROR: File copy failed & exit /b 1 )

echo Running server setup...
ssh %REMOTE_USER%@%SERVER_IP% "sudo bash %UPLOAD_DIR%/server_setup.sh"
if %errorlevel% neq 0 ( echo ERROR: Setup script failed & exit /b 1 )

echo.
echo Deployment complete!
echo Site: http://%SERVER_IP%/studyguides/
echo.
echo If this is the first deployment, set your API key on the server:
echo   ssh %REMOTE_USER%@%SERVER_IP%
echo   nano /opt/studyguides/.env
echo   systemctl restart studyguides-chat
