@echo off
setlocal EnableDelayedExpansion
title RustWall - Connection Blocker

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [X] Run as Administrator!
    echo.
    pause
    exit /b 1
)

set "RUSTWALL=%~dp0target\release\rustwall.exe"
if not exist "%RUSTWALL%" (
    echo  [X] rustwall.exe not found. Build first.
    pause
    exit /b 1
)

:MENU
cls
echo.
echo  ==========================================================
echo    RUSTWALL - Block Unwanted Internet Connections
echo  ==========================================================
echo.
echo    [1] Show ACTIVE connections (which apps are online)
echo    [2] Block by process NAME (easy)
echo    [3] Block by full PATH (precise)
echo    [4] Block ALL .exe in a FOLDER
echo    [5] Show current RustWall rules
echo    [6] Delete a rule
echo    [7] Cleanup all RustWall rules
echo.
echo    [0] Exit
echo.
echo  ==========================================================
set /p choice="  Choose: "

if "%choice%"=="1" goto SHOW_CONNECTIONS
if "%choice%"=="2" goto BLOCK_BY_NAME
if "%choice%"=="3" goto BLOCK_BY_PATH
if "%choice%"=="4" goto BLOCK_FOLDER
if "%choice%"=="5" goto SHOW_RULES
if "%choice%"=="6" goto DELETE_RULE
if "%choice%"=="7" goto CLEANUP
if "%choice%"=="0" exit /b 0

echo  [!] Invalid choice.
timeout /t 1 >nul
goto MENU

:: ─────────────────────────────────────────
:SHOW_CONNECTIONS
cls
echo.
echo  ---- Apps with ACTIVE internet connections ----
echo.
powershell -NoProfile -Command "Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object { $_.RemoteAddress -notmatch '^(127\.|::1|0\.0\.0\.0)' } | Select-Object @{n='Process';e={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}}, @{n='PID';e={$_.OwningProcess}}, RemoteAddress, RemotePort | Sort-Object Process -Unique | Format-Table -AutoSize"
echo.
echo  [i] Use option [2] to block any suspicious app by name.
echo.
pause
goto MENU

:: ─────────────────────────────────────────
:BLOCK_BY_NAME
cls
echo.
echo  ---- Block by Process NAME ----
echo.
echo  Example: chrome, whatsapp, discord
echo.
set /p "pname=  Process name: "
if "%pname%"=="" goto MENU

echo.
echo  Looking up path for "%pname%"...
echo.

for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "(Get-Process -Name '%pname%' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Path)"`) do set "APP_PATH=%%P"

if "%APP_PATH%"=="" (
    echo  [X] Process "%pname%" not found or access denied.
    echo.
    pause
    goto MENU
)

echo  Found: %APP_PATH%
echo.
"%RUSTWALL%" block "%APP_PATH%"
echo.
pause
goto MENU

:: ─────────────────────────────────────────
:BLOCK_BY_PATH
cls
echo.
echo  ---- Block by Full PATH ----
echo.
echo  Paste the full path to the .exe file:
echo.
set /p "app_path=  Path: "
if "%app_path%"=="" goto MENU

echo.
"%RUSTWALL%" block "%app_path%"
echo.
pause
goto MENU

:: ─────────────────────────────────────────
:BLOCK_FOLDER
cls
echo.
echo  ---- Block ALL .exe in a FOLDER ----
echo.
echo  Paste a folder path. All .exe files inside will be blocked.
echo  Example: C:\Users\jmadh\Downloads\SuspiciousApp
echo.
set /p "folder=  Folder: "
if "%folder%"=="" goto MENU

if not exist "%folder%" (
    echo  [X] Folder does not exist.
    pause
    goto MENU
)

echo.
echo  Files found:
dir /b "%folder%\*.exe"
echo.
set /p "confirm=  Block ALL of them? (Y/N): "
if /i not "%confirm%"=="Y" goto MENU

echo.
for %%F in ("%folder%\*.exe") do (
    echo  -- Blocking: %%~nxF
    "%RUSTWALL%" block "%%~fF"
)
echo.
echo  [i] Done.
echo.
pause
goto MENU

:: ─────────────────────────────────────────
:SHOW_RULES
cls
echo.
"%RUSTWALL%" list
echo.
pause
goto MENU

:: ─────────────────────────────────────────
:DELETE_RULE
cls
echo.
echo  Current RustWall rules:
echo.
"%RUSTWALL%" list
echo.
echo  Enter rule name (e.g. Block chrome.exe (out))
echo.
set /p "rname=  Rule: "
if "%rname%"=="" goto MENU

echo.
"%RUSTWALL%" delete "%rname%"
echo.
pause
goto MENU

:: ─────────────────────────────────────────
:CLEANUP
cls
echo.
"%RUSTWALL%" cleanup
echo.
pause
goto MENU