$ErrorActionPreference = "Stop"

Write-Host "1. Stopping Gradle Daemon..."
cd android
./gradlew --stop
cd ..

Write-Host "2. Cleaning Project..."
flutter clean
flutter pub get

Write-Host "3. Forcing Icon Update..."
$source = "assets\icon\mb.png"
if (-not (Test-Path $source)) {
    Write-Error "Source icon not found at $source"
}

$destinations = @(
    "android\app\src\main\res\mipmap-mdpi\ic_launcher.png",
    "android\app\src\main\res\mipmap-hdpi\ic_launcher.png",
    "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png",
    "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png",
    "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"
)

foreach ($dest in $destinations) {
    if (-not (Test-Path $dest)) {
        New-Item -ItemType File -Path $dest -Force | Out-Null
    }
    Copy-Item -Path $source -Destination $dest -Force
    Write-Host "Copied icon to $dest"
}

Write-Host "4. Installing and Running Release Build..."
Write-Host "Please keep your device connected and unlocked."
flutter run --release

Write-Host "Process Complete."
