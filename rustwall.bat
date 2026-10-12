@echo off
setlocal EnableDelayedExpansion
title RustWall - Firewall Manager

:: ─────────────────────────────────────────
::  RustWall Menu Launcher
:: ─────────────────────────────────────────

:: Check Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ============================================
    echo   [X] ADMINISTRATOR REQUIRED!
    echo  ============================================
    echo.
    echo   This tool needs admin rights to manage firewall.
    echo   Please run this file as Administrator.
    echo.
    echo   Right-click this file ^-^> "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: Path to rustwall.exe (relative to this .bat file)
set "RUSTWALL=%~dp0target\release\rustwall.exe"

if not exist "%RUSTWALL%" (
    echo.
    echo  [X] rustwall.exe not found at:
    echo      %RUSTWALL%
    echo.
    echo  Please build first:
    echo      cargo build --release
    echo.
    pause
    exit /b 1
)

:: ─────────────────────────────────────────
::  Main Menu Loop
:: ─────────────────────────────────────────
:MAIN_MENU
cls
echo.
echo  ==========================================================
echo    ^|^|  RUSTWALL - Terminal Firewall Manager  ^|^|
echo  ==========================================================
echo.
echo    [1]  Status          - Show firewall status
echo    [2]  List Rules      - Show RustWall rules
echo    [3]  List ALL        - Show all firewall rules
echo.
echo    [4]  Block App       - Block an application
echo    [5]  Allow App       - Allow an application
echo    [6]  Delete Rule     - Delete a specific rule
echo.
echo    [7]  Lockdown        - Block all outbound (whitelist mode)
echo    [8]  Unlock          - Restore normal mode
echo.
echo    [9]  Enable FW       - Turn firewall ON
echo    [10] Disable FW      - Turn firewall OFF (DANGEROUS!)
echo.
echo    [11] Cleanup         - Remove all RustWall rules
echo    [12] Help            - Show full help
echo.
echo    [0]  Exit
echo.
echo  ==========================================================
set /p choice="  Choose [0-12]: "

if "%choice%"=="1"  goto CMD_STATUS
if "%choice%"=="2"  goto CMD_LIST
if "%choice%"=="3"  goto CMD_LIST_ALL
if "%choice%"=="4"  goto CMD_BLOCK
if "%choice%"=="5"  goto CMD_ALLOW
if "%choice%"=="6"  goto CMD_DELETE
if "%choice%"=="7"  goto CMD_LOCKDOWN
if "%choice%"=="8"  goto CMD_UNLOCK
if "%choice%"=="9"  goto CMD_ENABLE
if "%choice%"=="10" goto CMD_DISABLE
if "%choice%"=="11" goto CMD_CLEANUP
if "%choice%"=="12" goto CMD_HELP
if "%choice%"=="0"  goto EXIT

echo.
echo  [!] Invalid choice. Try again.
timeout /t 1 >nul
goto MAIN_MENU

:: ─────────────────────────────────────────
::  Command Handlers
:: ─────────────────────────────────────────

:CMD_STATUS
cls
echo.
echo  ---- Firewall Status ----
echo.
"%RUSTWALL%" status
echo.
pause
goto MAIN_MENU

:CMD_LIST
cls
echo.
echo  ---- RustWall Rules ----
echo.
"%RUSTWALL%" list
echo.
pause
goto MAIN_MENU

:CMD_LIST_ALL
cls
echo.
echo  ---- All Firewall Rules ----
echo.
echo  [i] This may take a moment...
echo.
"%RUSTWALL%" list --all
echo.
pause
goto MAIN_MENU

:CMD_BLOCK
cls
echo.
echo  ---- Block Application ----
echo.
echo  Paste the full path to the .exe file.
echo  Example: C:\Program Files\App\app.exe
echo.
set /p "app_path=  Path: "
if "%app_path%"=="" goto MAIN_MENU

echo.
echo  Direction:
echo    [1] Both (in + out)  [default]
echo    [2] Outbound only
echo    [3] Inbound only
set /p "dir_choice=  Choose [1-3]: "

if "%dir_choice%"=="2" (
    set "direction=out"
) else if "%dir_choice%"=="3" (
    set "direction=in"
) else (
    set "direction=both"
)

echo.
"%RUSTWALL%" block "%app_path%" --direction %direction%
echo.
pause
goto MAIN_MENU

:CMD_ALLOW
cls
echo.
echo  ---- Allow Application ----
echo.
echo  Paste the full path to the .exe file.
echo.
set /p "app_path=  Path: "
if "%app_path%"=="" goto MAIN_MENU

echo.
echo  Direction:
echo    [1] Both (in + out)  [default]
echo    [2] Outbound only
echo    [3] Inbound only
set /p "dir_choice=  Choose [1-3]: "

if "%dir_choice%"=="2" (
    set "direction=out"
) else if "%dir_choice%"=="3" (
    set "direction=in"
) else (
    set "direction=both"
)

echo.
"%RUSTWALL%" allow "%app_path%" --direction %direction%
echo.
pause
goto MAIN_MENU

:CMD_DELETE
cls
echo.
echo  ---- Delete Rule ----
echo.
echo  First, here are your current RustWall rules:
echo.
"%RUSTWALL%" list
echo.
echo  Enter the rule name (without "RustWall: " prefix)
echo  Example: Block calc.exe (out)
echo.
set /p "rule_name=  Rule name: "
if "%rule_name%"=="" goto MAIN_MENU

echo.
"%RUSTWALL%" delete "%rule_name%"
echo.
pause
goto MAIN_MENU

:CMD_LOCKDOWN
cls
echo.
echo  ============================================
echo   [!] LOCKDOWN MODE
echo  ============================================
echo.
echo  This will BLOCK ALL outbound traffic.
echo  Only apps you explicitly "allow" will work.
echo.
echo  Make sure you know what you are doing!
echo.
set /p "confirm=  Type YES to confirm: "
if /i not "%confirm%"=="YES" (
    echo.
    echo  Cancelled.
    timeout /t 1 >nul
    goto MAIN_MENU
)

echo.
"%RUSTWALL%" lockdown
echo.
echo  [i] Use menu [5] Allow App to whitelist trusted apps.
echo.
pause
goto MAIN_MENU

:CMD_UNLOCK
cls
echo.
"%RUSTWALL%" unlock
echo.
pause
goto MAIN_MENU

:CMD_ENABLE
cls
echo.
"%RUSTWALL%" enable
echo.
pause
goto MAIN_MENU

:CMD_DISABLE
cls
echo.
echo  ============================================
echo   [!] WARNING - TURNING OFF FIREWALL
echo  ============================================
echo.
echo  This will DISABLE Windows Firewall.
echo  Your computer becomes VULNERABLE.
echo.
set /p "confirm=  Type YES to confirm: "
if /i not "%confirm%"=="YES" (
    echo.
    echo  Cancelled.
    timeout /t 1 >nul
    goto MAIN_MENU
)

echo.
"%RUSTWALL%" disable
echo.
pause
goto MAIN_MENU

:CMD_CLEANUP
cls
echo.
echo  ---- Cleanup RustWall Rules ----
echo.
echo  Current rules:
"%RUSTWALL%" list
echo.
set /p "confirm=  Delete ALL RustWall rules? (Y/N): "
if /i not "%confirm%"=="Y" (
    echo.
    echo  Cancelled.
    timeout /t 1 >nul
    goto MAIN_MENU
)

echo.
"%RUSTWALL%" cleanup
echo.
pause
goto MAIN_MENU

:CMD_HELP
cls
echo.
"%RUSTWALL%" --help
echo.
pause
goto MAIN_MENU

:: ─────────────────────────────────────────
::  Exit
:: ─────────────────────────────────────────
:EXIT
cls
echo.
echo  Goodbye! ^_^
echo.
timeout /t 1 >nul
exit /b 0