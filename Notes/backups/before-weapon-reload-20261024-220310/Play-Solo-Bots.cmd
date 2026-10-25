@echo off
setlocal
set "NS_GAME_DIR=C:\Program Files (x86)\Steam\steamapps\common\Titanfall2"
set "NS_SOLO_PROFILE=%~dp0local-test-profile"

if not exist "%NS_GAME_DIR%\NorthstarLauncher.exe" goto missing_game
if not exist "%NS_SOLO_PROFILE%\plugins\bp_ort.dll" goto missing_profile
if not exist "%NS_SOLO_PROFILE%\mods\James.BotLifecycle\mod.json" goto missing_profile
if not exist "%NS_SOLO_PROFILE%\mods\James.LocalPersistence\mod.json" goto missing_profile

if /I "%~1"=="--check" goto checked

tasklist /FI "IMAGENAME eq NorthstarLauncher.exe" /NH 2>nul | find /I "NorthstarLauncher.exe" >nul
if not errorlevel 1 goto already_running
tasklist /FI "IMAGENAME eq Titanfall2.exe" /NH 2>nul | find /I "Titanfall2.exe" >nul
if not errorlevel 1 goto already_running

echo Launching your Northstar solo profile: 8v8 bots on Eden.
echo Bots join after the match intro finishes.
cd /d "%NS_GAME_DIR%"
start "" /D "%NS_GAME_DIR%" "%NS_GAME_DIR%\NorthstarLauncher.exe" -profile="%NS_SOLO_PROFILE%" -novid -fullscreen -ip 127.0.0.1 -port 37025 -maxplayersplaylist +setplaylist tdm +setplaylistvaroverrides "max_players 16" +mp_gamemode tdm +map mp_eden
if errorlevel 1 goto launch_failed
exit /b 0

:checked
echo Solo launcher verified.
echo Game: "%NS_GAME_DIR%"
echo Profile: "%NS_SOLO_PROFILE%"
echo Starts Eden, team deathmatch, 8v8: you and 15 bots.
echo Fullscreen at the saved video resolution.
echo Mods, aim settings, tracking and saves load from this profile.
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
