param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$backup="$env:USERPROFILE\northstar-crash-audit\Notes\backups\working-v12-before-recovery-20261024-151754"
$solo="$env:USERPROFILE\northstar-crash-audit\local-test-profile"
$expected='1183389B692F59758C569631F0C7BAB50703C7FB425212876DBB5ABB8DBE7D7A'
$dll="$backup\solo\plugins\bp_ort.dll"
if((Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -ne $expected) { throw 'Working v12 backup hash mismatch.' }
foreach($file in @('solo\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg','Play-Solo-Bots.cmd')) {
    if(-not(Test-Path -LiteralPath (Join-Path $backup $file))) { throw "Missing rollback file $file" }
}
if($VerifyOnly) { "Verified working v12 rollback: $backup"; return }
if(Get-Process NorthstarLauncher -ErrorAction SilentlyContinue) { throw 'Close Northstar before restoring the working bot build.' }
Copy-Item -LiteralPath $dll -Destination "$solo\plugins\bp_ort.dll" -Force
Copy-Item -LiteralPath "$backup\solo\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg" -Destination "$solo\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg" -Force
Copy-Item -LiteralPath "$backup\Play-Solo-Bots.cmd" -Destination "$env:USERPROFILE\northstar-crash-audit\Play-Solo-Bots.cmd" -Force
if((Get-FileHash -LiteralPath "$solo\plugins\bp_ort.dll" -Algorithm SHA256).Hash -ne $expected) { throw 'Restored DLL hash mismatch.' }
"Restored working v12 bots/config/launcher. Current loadout saves and the local save add-on were preserved."
"$(Get-Date -Format o): working v12 solo DLL/config/launcher restored; saves preserved." |
    Add-Content -LiteralPath "$env:USERPROFILE\northstar-crash-audit\Notes\RECOVERY-LOG.txt"
"`nRollback $(Get-Date -Format o): everyday solo is v12 ($expected); verify hashes before continuing." |
    Add-Content -LiteralPath "$env:USERPROFILE\northstar-crash-audit\Notes\CURRENT-SETUP.md"
