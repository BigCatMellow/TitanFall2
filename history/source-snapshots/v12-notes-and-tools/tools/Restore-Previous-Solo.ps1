param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$notes=Split-Path $PSScriptRoot
$backup=Join-Path $notes 'backups\v12-before'
$expected='DBE7301BFCAEF61E16165B3456D9F8EF851807DF2F64EDD768E2A9928EC63C48'
$dll=Join-Path $backup 'solo-bp_ort.dll'
if ((Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -ne $expected) { throw 'Backup DLL hash mismatch.' }
foreach ($file in @('solo-autoexec.cfg','Play-Solo-Bots.cmd')) {
    if (-not (Test-Path -LiteralPath (Join-Path $backup $file))) { throw "Missing backup: $file" }
}
if ($VerifyOnly) { "Verified v11 rollback files and DLL hash: $expected"; return }
if (Get-Process NorthstarLauncher -ErrorAction SilentlyContinue) {
    throw 'Close Northstar before restoring the previous solo build.'
}
$profile="$env:USERPROFILE\northstar-crash-audit\local-test-profile"
Copy-Item -LiteralPath $dll -Destination "$profile\plugins\bp_ort.dll" -Force
Copy-Item -LiteralPath (Join-Path $backup 'solo-autoexec.cfg') -Destination "$profile\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg" -Force
Copy-Item -LiteralPath (Join-Path $backup 'Play-Solo-Bots.cmd') -Destination "$env:USERPROFILE\northstar-crash-audit\Play-Solo-Bots.cmd" -Force
if ((Get-FileHash -LiteralPath "$profile\plugins\bp_ort.dll" -Algorithm SHA256).Hash -ne $expected) { throw 'Restored DLL verification failed.' }
"Restored v11 solo 8v8 build: $expected"
"$(Get-Date -Format o): Restored v11 solo DLL/config/launcher using Restore-Previous-Solo.ps1." |
    Add-Content -LiteralPath (Join-Path $notes 'RECOVERY-LOG.txt')
"`nRecovery $(Get-Date -Format o): everyday solo restored to v11 ($expected). Verify installed hashes before further work." |
    Add-Content -LiteralPath (Join-Path $notes 'CURRENT-SETUP.md')
