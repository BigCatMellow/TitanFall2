param([Parameter(Mandatory=$true)][string]$SessionDirectory)
$ErrorActionPreference='Stop'
$events=@(Get-Content -LiteralPath (Join-Path $SessionDirectory 'events.json') -Raw|ConvertFrom-Json)
$rows=@(Import-Csv -LiteralPath (Join-Path $SessionDirectory 'observations.csv'))
$results=@(foreach($event in ($events|Where-Object {$_.kind -eq 'route' -and $_.reason -eq 'breadcrumb_retreat'})) {
    $window=@($rows|Where-Object {$_.bot -eq '1' -and [int]$_.epoch -eq [int]$event.epoch -and [int]$_.slot -eq [int]$event.slot -and [double]$_.t -ge [double]$event.t -and [double]$_.t -le ([double]$event.t+4)}|Sort-Object {[double]$_.t})
    $samples=@(foreach($sample in $window){if($sample.alive -ne '1'){break}; $sample})
    $travel=0.; $closest=[double]::PositiveInfinity
    foreach($sample in $samples) {
        $dx=[double]$sample.x-[double]$event.x; $dy=[double]$sample.y-[double]$event.y
        $travel=[Math]::Max($travel,[Math]::Sqrt($dx*$dx+$dy*$dy))
        $dx=[double]$sample.x-[double]$event.gx; $dy=[double]$sample.y-[double]$event.gy
        $closest=[Math]::Min($closest,[Math]::Sqrt($dx*$dx+$dy*$dy))
    }
    [pscustomobject]@{epoch=$event.epoch;slot=$event.slot;t=$event.t;samples=$samples.Count;
        max_displacement=[Math]::Round($travel,1);closest_to_goal=if($samples.Count){[Math]::Round($closest,1)}else{$null};
        moved_128=($travel -ge 128);near_goal=($closest -le 96)}
})
ConvertTo-Json -InputObject $results -Depth 4 | Set-Content -LiteralPath (Join-Path $SessionDirectory 'retreat-checks.json')
[pscustomobject]@{RetreatEvents=$results.Count;Observed=@($results|Where-Object samples -gt 0).Count;
    Moved128=@($results|Where-Object moved_128 -eq $true).Count;NearGoal=@($results|Where-Object near_goal -eq $true).Count}
