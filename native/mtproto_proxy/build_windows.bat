@echo off
REM ============================================================
REM Сборка Rust-библиотеки mtproto_proxy.dll для Windows
REM ============================================================
REM Требования:
REM   1. Rust toolchain (rustup, cargo)
REM   2. Visual Studio Build Tools 2022 с C++ workload
REM      (или Visual Studio 2022 Community/Professional)
REM   3. x86_64-pc-windows-msvc target:
REM      rustup target add x86_64-pc-windows-msvc
REM ============================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%"
set "TARGET=x86_64-pc-windows-msvc"
set "BUILD_TYPE=release"

echo ============================================================
echo  ShadowGate - MTProto Proxy Windows Build
echo ============================================================
echo.
echo Project dir: %PROJECT_DIR%
echo Target:      %TARGET%
echo Build type:  %BUILD_TYPE%
echo.

REM Проверка наличия Rust
where rustc >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Rust toolchain not found!
    echo Install Rust from: https://rustup.rs/
    exit /b 1
)

echo [INFO] Rust version:
rustc --version
cargo --version
echo.

REM Проверка target
rustup target list --installed | findstr "%TARGET%" >nul
if %ERRORLEVEL% neq 0 (
    echo [INFO] Target %TARGET% not installed. Installing...
    rustup target add %TARGET%
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Failed to install target %TARGET%
        exit /b 1
    )
)

REM Переход в директорию проекта
cd /d "%PROJECT_DIR%"

REM Сборка
echo [INFO] Building mtproto_proxy.dll (release, features=windows)...
cargo build --release --features windows --target %TARGET%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    exit /b 1
)

set "DLL_SRC=%PROJECT_DIR%target\%TARGET%\release\mtproto_proxy.dll"
set "DLL_DST=%PROJECT_DIR%target\release\mtproto_proxy.dll"

if not exist "%DLL_SRC%" (
    echo [ERROR] Built DLL not found at: %DLL_SRC%
    exit /b 1
)

REM Копируем .dll в target/release для удобства
if not exist "%PROJECT_DIR%target\release" mkdir "%PROJECT_DIR%target\release"
copy /Y "%DLL_SRC%" "%DLL_DST%" >nul

echo.
echo ============================================================
echo  Build successful!
echo ============================================================
echo.
echo DLL: %DLL_SRC%
echo Size:
dir "%DLL_SRC%" | findstr "mtproto_proxy.dll"
echo.
echo Next steps:
echo   1. Copy mtproto_proxy.dll to Flutter Windows build output:
echo      copy "%DLL_SRC%" "build\windows\x64\runner\Release\"
echo.
echo   2. Or run: flutter build windows --release
echo      (the DLL will be loaded automatically by Dart FFI)
echo.

endlocal