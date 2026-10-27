$ErrorActionPreference='Stop'
$solo="$env:USERPROFILE\northstar-crash-audit\local-test-profile"
$backup="$env:USERPROFILE\northstar-crash-audit\Notes\backups\before-combat-decisions-20261024-230020"
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue) { throw 'Close Northstar/Titanfall 2 before restoring the bot build.' }
$original=Join-Path $backup 'local-test-profile\bp_ort.dll'
if((Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash -ne '2A68A1CE0C0AB6294DE62C7E2742BE064C7ED086111C8251F1822FCCD22FA66C') { throw 'Backup DLL hash mismatch' }
Copy-Item -LiteralPath $original -Destination (Join-Path $solo 'plugins\bp_ort.dll') -Force
Copy-Item -LiteralPath (Join-Path $backup 'local-test-profile\autoexec_ns_server.cfg') -Destination (Join-Path $solo 'mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg') -Force
if((Get-FileHash -LiteralPath (Join-Path $solo 'plugins\bp_ort.dll') -Algorithm SHA256).Hash -ne '2A68A1CE0C0AB6294DE62C7E2742BE064C7ED086111C8251F1822FCCD22FA66C') { throw 'Restored DLL hash mismatch' }
Write-Host 'Restored v15 bots and pre-combat config. Current loadouts, progress, tactical recharge and reload add-ons are preserved.'
