# Сборка Omnitask Local для Windows.
# Запускать на Windows с установленными Flutter SDK и Visual Studio 2022
# (workload «Разработка классических приложений на C++»).
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
#
# Результат: build\windows\x64\runner\Release\ (самодостаточная папка
# с omnitask_local.exe) и архив omnitask-windows-x64.zip рядом.

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "==> flutter pub get"
flutter pub get

Write-Host "==> flutter build windows --release"
flutter build windows --release

$releaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $releaseDir "omnitask_local.exe"))) {
    throw "Сборка не удалась: $releaseDir\omnitask_local.exe не найден"
}

$zip = "omnitask-windows-x64.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$releaseDir\*" -DestinationPath $zip

Write-Host ""
Write-Host "Готово:"
Write-Host "  Приложение: $releaseDir\omnitask_local.exe"
Write-Host "  Архив:      $zip (можно раздать или выложить в релиз)"
