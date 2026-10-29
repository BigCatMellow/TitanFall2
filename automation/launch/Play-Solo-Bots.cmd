@echo off
setlocal
set "NS_GAME_DIR=C:\Program Files (x86)\Steam\steamapps\common\Titanfall2"
set "NS_SOLO_PROFILE=%~dp0local-test-profile"

if not exist "%NS_GAME_DIR%\NorthstarLauncher.exe" goto missing_game
if not exist "%NS_SOLO_PROFILE%\plugins\bp_ort.dll" goto missing_profile
if not exist "%NS_SOLO_PROFILE%\mods\BT7274.BotLifecycle\mod.json" goto missing_profile
if not exist "%NS_SOLO_PROFILE%\mods\BT7274.LocalPersistence\mod.json" goto missing_profile

if not exist "%NS_SOLO_PROFILE%\mods\Solo.WeaponNotes\mod.json" goto missing_profile
if not exist "%~dp0TitanFall2-project\tools\Start-SoloWeaponSession.ps1" goto missing_profile
if /I "%~1"=="--check" goto checked
set "NS_TRIAL=Movement"
if /I "%~1"=="baseline" set "NS_TRIAL=Baseline"
if /I "%~1"=="height" set "NS_TRIAL=Height"
if /I "%~1"=="roster" set "NS_TRIAL=Roster"
if /I "%~1"=="skills" set "NS_TRIAL=Skills"
if /I "%~1"=="full" set "NS_TRIAL=Full"

tasklist /FI "IMAGENAME eq NorthstarLauncher.exe" /NH 2>nul | find /I "NorthstarLauncher.exe" >nul
if not errorlevel 1 goto already_running
tasklist /FI "IMAGENAME eq Titanfall2.exe" /NH 2>nul | find /I "Titanfall2.exe" >nul
if not errorlevel 1 goto already_running

echo Launching your Northstar solo profile: 8v8 bots on a random full-size map.
echo Bots join after the match intro finishes.
echo Automatic weapon notes are saved locally for this session.
cd /d "%NS_GAME_DIR%"
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0TitanFall2-project\tools\Start-SoloWeaponSession.ps1" -Profile "%NS_SOLO_PROFILE%" -GameDirectory "%NS_GAME_DIR%" -Trial "%NS_TRIAL%"
if errorlevel 1 goto launch_failed
exit /b 0

:checked
echo Solo launcher verified.
echo Game: "%NS_GAME_DIR%"
echo Profile: "%NS_SOLO_PROFILE%"
echo Starts a random full-size map, team deathmatch, 8v8: you and 15 bots.
echo Skips Eden and avoids repeating the previous random map.
echo Fullscreen at the saved video resolution.
echo Mods, aim settings, tracking and saves load from this profile.
echo Automatic weapon notebook enabled.
exit /b 0

:already_running
echo Titanfall 2 or Northstar is already running.
echo Close the game fully, then run this solo launcher again.
pause
exit /b 2

:missing_game
echo NorthstarLauncher.exe was not found in:
echo %NS_GAME_DIR%
pause
exit /b 1

:missing_profile
echo The solo profile or one of its required mods is missing:
echo %NS_SOLO_PROFILE%
pause
exit /b 1

:launch_failed
echo Northstar did not launch. Check that Steam and EA are available.
pause
exit /b 1
