flutter clean
flutter pub get

flutter build windows
$windowsPath = ".\build\windows\x64\runner\Release"
robocopy .\dependencies $windowsPath sqlite3.dll
robocopy $windowsPath .\build\binaries\LogViewer_win /e

flutter build apk --split-per-abi
robocopy .\build\app\outputs\apk\release\ .\build\binaries\ *.apk