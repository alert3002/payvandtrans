# Reinstall Flutter deps and clean caches. Run: .\reinstall_deps.ps1
Set-Location $PSScriptRoot

Write-Host "1. flutter clean..." -ForegroundColor Cyan
flutter clean

Write-Host "2. Remove pubspec.lock..." -ForegroundColor Cyan
if (Test-Path pubspec.lock) { Remove-Item pubspec.lock -Force }

Write-Host "3. flutter pub get..." -ForegroundColor Cyan
flutter pub get

Write-Host "4. Android: gradlew clean..." -ForegroundColor Cyan
if (Test-Path android\gradlew.bat) {
    Set-Location android
    .\gradlew.bat clean
    Set-Location ..
}

Write-Host "5. Optional: flutter pub cache repair" -ForegroundColor Yellow
Write-Host "   Done. Run: flutter run" -ForegroundColor Green
