param([string]$Label='working-v12')
$ErrorActionPreference='Stop'
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a simple backup label.' }
$repo='C:\Users\james\bp-ort-fork'
$notes='C:\Users\james\northstar-crash-audit\Notes'
$audit='C:\Users\james\northstar-crash-audit'
$game='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2'
$destination=Join-Path "$notes\backups" ($Label+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path "$destination\source" -Force | Out-Null
Push-Location $repo
try {
    $files=@(& rg --files --hidden -g '!target/**' -g '!.git/**')
    if ($LASTEXITCODE -ne 0) { throw 'Source file listing failed.' }
    foreach($relative in $files) {
        $target=Join-Path "$destination\source" $relative
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $target
    }
    & git diff --binary --output="$destination\tracked-changes.patch"
    if ($LASTEXITCODE -ne 0) { throw 'Source diff backup failed.' }
    & git status --short | Set-Content -LiteralPath "$destination\git-status.txt"
    & git rev-parse HEAD | Set-Content -LiteralPath "$destination\git-head.txt"
} finally { Pop-Location }
foreach($entry in @(
    @{Name='solo';Path="$audit\local-test-profile"},
    @{Name='test';Path="$audit\map-cycle-test-profile"},
    @{Name='regular';Path="$game\R2Northstar"}
)) {
    $target=Join-Path $destination $entry.Name
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach($folder in @('mods','plugins','save_data','cfg')) {
        $from=Join-Path $entry.Path $folder
        if(Test-Path -LiteralPath $from) { Copy-Item -LiteralPath $from -Destination $target -Recurse }
    }
    Get-ChildItem -LiteralPath $entry.Path -File | Copy-Item -Destination $target
}
New-Item -ItemType Directory -Path "$destination\core" -Force | Out-Null
foreach($name in @('NorthstarLauncher.exe','Northstar.dll','wsock32.dll','ns_startup_args.txt')) {
    $from=Join-Path $game $name
    if(Test-Path -LiteralPath $from) { Copy-Item -LiteralPath $from -Destination "$destination\core" }
}
Copy-Item -LiteralPath "$audit\Play-Solo-Bots.cmd" -Destination $destination
Get-ChildItem -LiteralPath $notes -File | Copy-Item -Destination $destination
Copy-Item -LiteralPath "$notes\tools" -Destination $destination -Recurse
$manifest=@(Get-ChildItem -LiteralPath $destination -Recurse -File | ForEach-Object {
    [pscustomobject]@{Path=$_.FullName.Substring($destination.Length+1);Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$manifest | Export-Csv -LiteralPath "$destination\manifest.csv" -NoTypeInformation
$bad=@($manifest | Where-Object { (Get-FileHash -LiteralPath (Join-Path $destination $_.Path) -Algorithm SHA256).Hash -ne $_.SHA256 })
if($bad.Count) { throw 'Backup verification failed.' }
[pscustomobject]@{Backup=$destination;Files=$manifest.Count;Bytes=($manifest|Measure-Object Bytes -Sum).Sum;Verified=$true} | ConvertTo-Json
