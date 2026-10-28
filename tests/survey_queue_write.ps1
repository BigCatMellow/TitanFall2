$ErrorActionPreference='Stop'
. "$PSScriptRoot/../tools/Write-SurveyQueueJson.ps1"
$dir=Join-Path ([IO.Path]::GetTempPath()) ('corner-writer-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $dir|Out-Null
$file=Join-Path $dir 'status.json'
Write-SurveyQueueJson $file @{state='old'}
Write-SurveyQueueJson $file @{state='new'}
if((Get-Content $file -Raw|ConvertFrom-Json).state-ne'new'){throw 'Replacement failed'}
'PASS: complete JSON replacement'
function Move-SurveyQueueJsonFile([string]$Source,[string]$Destination){
    $script:calls++
    if($script:mode-eq'denied'){throw [UnauthorizedAccessException]::new('denied')}
    if($script:mode-eq'persistent'-or($script:mode-eq'race'-and$script:calls-lt3)){throw [IO.IOException]::new('sharing race')}
    [IO.File]::Move($Source,$Destination,$true)
}
foreach($mode in @('race','persistent','denied')){
    $script:mode=$mode;$script:calls=0;$failed=$false
    try{Write-SurveyQueueJson $file @{state=$mode} -Attempts 3}catch{$failed=$true}
    if($mode-eq'race'){
        if($failed-or$script:calls-ne3-or(Get-Content $file -Raw|ConvertFrom-Json).state-ne'race'){throw 'Retry failed'}
    }else{
        $expected=if($mode-eq'denied'){1}else{3}
        if(-not$failed-or$script:calls-ne$expected-or(Get-Content $file -Raw|ConvertFrom-Json).state-ne'race'){throw 'Failure erased previous complete JSON'}
    }
    "PASS: $mode preserves complete publication semantics"
}
. "$PSScriptRoot/../tools/Write-SurveyQueueJson.ps1"
$reader=[IO.File]::Open($file,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
$failed=$false
try{try{Write-SurveyQueueJson $file @{state='locked'} -Attempts 2}catch{$failed=$true}}
finally{$reader.Dispose()}
if(-not$failed-or(Get-Content $file -Raw|ConvertFrom-Json).state-ne'race'){throw 'Live reader lock erased valid destination'}
Write-SurveyQueueJson $file @{state='after_lock'}
if((Get-Content $file -Raw|ConvertFrom-Json).state-ne'after_lock'){throw 'Writer did not recover after reader closed'}
'PASS: real reader lock preserves destination and writing recovers after close'
