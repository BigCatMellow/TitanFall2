param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$results=Import-Csv (Join-Path $RunDirectory 'results.csv')
$summary=@(foreach($r in $results){
    $folder=Join-Path "$RunDirectory\reports" ('{0:D2}-{1}' -f ([int]$r.index+1),$r.map)
    $review=Join-Path $folder 'movement\fine-tune-review.json'
    $pilots=$null;$stalls=$null;$switches=$null;$back=$null
    if(Test-Path $review){
        $v=Get-Content -Raw $review|ConvertFrom-Json
        $pilots=($v.rounds|Measure-Object pilot_samples -Sum).Sum
        $stalls=($v.rounds|Measure-Object stalls -Sum).Sum
        $switches=($v.target_churn|Measure-Object switches -Sum).Sum
        $back=($v.target_churn|Measure-Object reversals_within_half_second -Sum).Sum
    }
    [pscustomobject]@{map=$r.map;team_imc=[int]$r.imc;team_militia=[int]$r.militia;minutes=[Math]::Round([double]$r.elapsed/60,1);ending=$r.reason;valid=$r.valid;pilot_samples=$pilots;stall_samples=$stalls;stall_percent=if($pilots){[Math]::Round(100*$stalls/$pilots,2)}else{$null};target_switches=$switches;quick_switchbacks=$back;quick_switchback_percent=if($switches){[Math]::Round(100*$back/$switches,1)}else{$null};replay=Join-Path $folder 'movement\replay.html'}
})
$summary|Export-Csv (Join-Path $RunDirectory 'summary.csv') -NoTypeInformation
$lines=@('# Unattended v16 map survey','', '16 bots, 8v8; local client spectating. Fixed v16 build and aim error 0.78.','Team score target: 200; timed-out maps are capped observations, not completed 200-kill matches.','', '| Map | Score | Minutes | Ending | Pilot stall samples | Quick target switch-backs |','|---|---|---:|---|---:|---:|')
$lines+=@($summary|ForEach-Object{'| {0} | {1}-{2} | {3} | {4} | {5}% | {6}% |' -f $_.map,$_.team_imc,$_.team_militia,$_.minutes,$_.ending,$_.stall_percent,$_.quick_switchback_percent})
$lines+=@('', 'Stall percentages describe two-second pilot samples after the population warmup. Intentional range holds are excluded from the stall heuristic. Quick switch-backs are target reversals within half a second; some are legitimate.','', 'This unattended run is useful for map navigation, combat consistency and stability. It does not establish difficulty against a moving human or exact frame rate.','', 'Per-map score/kill rosters, raw logs, movement replays and combat summaries are stored beside this report. No AI or weapon tuning was changed during the run.')
[IO.File]::WriteAllLines((Join-Path $RunDirectory 'Summary.md'),$lines,[Text.UTF8Encoding]::new($false))
$summary|ConvertTo-Json -Depth 5|Set-Content (Join-Path $RunDirectory 'summary.json')
