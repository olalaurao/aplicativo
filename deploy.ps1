# Script para compilar e instalar o app Citrine no celular conectado
Write-Host "🚀 Iniciando build do Citrine..." -ForegroundColor Cyan

# Entrar na pasta android e compilar
Set-Location android
./gradlew assembleDebug

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Build concluído com sucesso!" -ForegroundColor Green
    Write-Host "📲 Instalando no dispositivo..." -ForegroundColor Yellow
    
    # Voltar para a raiz e instalar
    Set-Location ..
    adb install -r android/app/build/outputs/apk/debug/app-debug.apk
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n🎉 App instalado e pronto para usar!" -ForegroundColor Green
        # Opcional: Abre o app automaticamente
        adb shell am start -n com.productivity.citrine/com.productivity.citrine.MainActivity
    } else {
        Write-Host "`n❌ Erro ao instalar. Verifique se o celular está conectado e com o Debug USB ativo." -ForegroundColor Red
    }
} else {
    Write-Host "`n❌ Erro durante o build do Gradle." -ForegroundColor Red
    Set-Location ..
}
