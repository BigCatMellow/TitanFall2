@echo off
cd /d "C:\Program Files (x86)\Steam\steamapps\common\Titanfall2"
start "" "NorthstarLauncher.exe" -profile=%USERPROFILE%\northstar-crash-audit\local-test-profile -novid -ip 127.0.0.1 -port 37025 -maxplayersplaylist +setplaylist tdm +setplaylistvaroverrides "max_players 16" +mp_gamemode tdm +map mp_eden
