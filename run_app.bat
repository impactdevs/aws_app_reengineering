@echo off
echo Starting Flutter app with reliable installation...

REM Clean and get dependencies
flutter clean
flutter pub get

REM Build the APK
echo Building APK...
flutter build apk --debug

REM Check if APK was generated
if exist "android\app\build\outputs\apk\debug\app-debug.apk" (
    echo APK found in standard location
    set APK_PATH=android\app\build\outputs\apk\debug\app-debug.apk
) else if exist "android\app\build\outputs\flutter-apk\app-debug.apk" (
    echo APK found in flutter-apk location
    set APK_PATH=android\app\build\outputs\flutter-apk\app-debug.apk
) else (
    echo ERROR: APK not found in either location
    exit /b 1
)

REM Install APK manually
echo Installing APK manually...
"%ANDROID_HOME%\platform-tools\adb.exe" install -r "%APK_PATH%"

if %ERRORLEVEL% EQU 0 (
    echo App installed successfully!

    REM Try to launch with flutter run for hot reload
    echo Attempting to connect Flutter for hot reload...
    timeout /t 2
    flutter run --no-build
) else (
    echo Installation failed. Trying direct APK install...
    "C:\Users\Katende Chris\AppData\Local\Android\Sdk\platform-tools\adb.exe" install -r "%APK_PATH%"

    if %ERRORLEVEL% EQU 0 (
        echo App installed successfully with direct path!
        echo You can now use the app on your device.
        echo To enable hot reload, run: flutter attach
    ) else (
        echo Installation failed. Please check device connection.
    )
)

pause