$ErrorActionPreference='Stop'
. "$PSScriptRoot/../tools/Corner-MatrixPolicy.ps1"
function Row($map,$repeat,$guard,$samples,$low){[pscustomobject]@{map=$map;repeat=$repeat;guard=$guard;metrics=@{live_pilot_samples=$samples;low_progress_percent=$low}}}
$off=Row mp_test 1 0 1000 4
if(-not(Find-CornerRegression @($off,(Row mp_test 1 1 1000 10)))){throw 'Severe matched regression missed'}
'PASS: severe matched regression detected'
foreach($on in @((Row mp_test 2 1 1000 10),(Row mp_other 1 1 1000 10),(Row mp_test 1 1 499 10),(Row mp_test 1 1 1000 9),(Row mp_test 1 1 1000 $null))){
    if(Find-CornerRegression @($off,$on)){throw 'Ineligible pair caused a cutoff'}
    'PASS: unmatched/insufficient/boundary/missing comparison ignored'
}
