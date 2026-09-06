$appChoice = Read-Host "Pilih Aplikasi yang ingin dijalankan:`n[1] Temenin Ajaa (Client)`n[2] Temenin Ajaa Driver`nPilihan Anda (1/2)"

if ($appChoice -eq "1") {
    $targetPath = "temenin_ajaa"
} elseif ($appChoice -eq "2") {
    $targetPath = "driver_temenin_ajaa\driver_app"
} else {
    Write-Host "Pilihan tidak valid." -ForegroundColor Red
    exit
}

Write-Host "`n--- Daftar Device yang Tersedia ---" -ForegroundColor Cyan
flutter devices

$deviceId = Read-Host "`nKetik nama/ID device yang ingin digunakan (contoh: chrome, windows, edge, atau biarkan kosong untuk ditanya oleh Flutter)"

Set-Location $targetPath

if ([string]::IsNullOrWhiteSpace($deviceId)) {
    Write-Host "`nMenjalankan aplikasi..." -ForegroundColor Green
    flutter run
} else {
    Write-Host "`nMenjalankan aplikasi di device: $deviceId..." -ForegroundColor Green
    flutter run -d $deviceId
}
