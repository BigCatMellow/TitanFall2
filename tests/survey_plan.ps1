param([string]$Profile="$env:USERPROFILE\northstar-crash-audit\map-cycle-test-profile")
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
$dir=Join-Path $repo ('target/offline-checks/survey-plan-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$dir/prior" -Force|Out-Null
$plan=@{dll_sha256=(Get-FileHash "$Profile/plugins/bp_ort.dll").Hash;core_sha256=(Get-FileHash "$Profile/Northstar.dll").Hash;bridge_sha256=(Get-FileHash "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash;goal=200}
$plan|ConvertTo-Json|Set-Content "$dir/prior/plan.json"
@{results=@(@{map='mp_forwardbase_kodai';result=@{valid='true'}},@{map='mp_grave';result=@{valid='true'}},@{map='mp_homestead';result=@{valid='false'}})}|ConvertTo-Json -Depth 5|Set-Content "$dir/prior/status.json"
$request=@{batch="$dir/never-created";profile=$Profile;goal=75;max_attempts=2;completed_batches=@("$dir/prior")}
function Plan {
    $request|ConvertTo-Json -Depth 5|Set-Content "$dir/request.json"
    (& "$repo/tools/Run-OvernightSurvey.ps1" -RequestPath "$dir/request.json" -PlanOnly)|ConvertFrom-Json
}
function Require([bool]$ok,[string]$message){if(-not$ok){throw $message};"PASS: $message"}
function Reject([string]$message){$rejected=$false;try{Plan|Out-Null}catch{$rejected=$true};Require $rejected $message}
$result=Plan
Require ($result.goal-eq75-and$result.remaining.Count-eq20-and$result.completed.Count-eq2) '75-point plan skips completed trials and retains the failed map'
Require ($result.remaining[0]-eq'mp_homestead'-and'mp_coliseum_column'-notin$result.remaining-and@($result.remaining|Select-Object -Unique).Count-eq20) 'Remaining map order is unique and excludes the meshless arena'
Require (-not(Test-Path "$dir/never-created")) 'Plan-only mode does not create or mutate a live batch'
$request.goal=0;Reject 'Invalid score limit is rejected';$request.goal=75
$request.max_attempts=4;Reject 'Retries cannot become unbounded';$request.max_attempts=2
$plan.core_sha256='different-runtime';$plan|ConvertTo-Json|Set-Content "$dir/prior/plan.json";Reject 'Prior results from a different core cannot silently enter the cohort'
'6 survey planning checks passed.'
