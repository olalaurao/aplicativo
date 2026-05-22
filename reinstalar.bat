@echo off
setlocal
echo.
echo ===================================================
echo   CITRINE - REINSTALADOR (DEBUG MODE)
echo ===================================================
echo.
echo [1/3] Atualizando pacotes...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERRO] flutter pub get falhou com codigo %errorlevel%
    pause
    exit /b %errorlevel%
)
echo [2/3] Gerando APK (Isso pode demorar um pouco)...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo [ERRO] flutter build apk falhou com codigo %errorlevel%
    pause
    exit /b %errorlevel%
)
echo [3/3] Procurando o APK recem-gerado e instalando...
for /f "delims=" %%I in ('powershell -command "Get-ChildItem -Path '.' -Filter 'app-debug.apk' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName"') do set "LATEST_APK=%%I"
if "%LATEST_APK%"=="" (
    echo [ERRO] Nenhum APK encontrado!
    pause
    exit /b 1
)
echo Instalando APK mais recente:
echo %LATEST_APK%
adb install -r "%LATEST_APK%"
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Falha ao instalar no celular. Verifique se o cabo esta conectado.
    pause
    exit /b %errorlevel%
)
echo.
echo ===================================================
echo   PRONTO! App instalado e atualizado.
echo ===================================================
pause