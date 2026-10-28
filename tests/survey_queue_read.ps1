$ErrorActionPreference='Stop'
. "$PSScriptRoot/../tools/Read-SurveyQueueJson.ps1"
function Open-SurveyQueueStream([string]$Path){
    $script:calls++
    if($script:mode-eq'denied'){throw [UnauthorizedAccessException]::new('denied')}
    if($script:mode-eq'missing'-or($script:mode-eq'race'-and$script:calls-eq1)){throw [IO.FileNotFoundException]::new('publication gap')}
    $text=if($script:mode-eq'partial'-and$script:calls-eq1){'{'}else{'{"state":"running"}'}
    [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($text))
}
foreach($case in @('race','partial','missing','denied')){
    $script:mode=$case;$script:calls=0;$failed=$false
    try{$result=Read-SurveyQueueJson ignored -Attempts 3}catch{$failed=$true}
    if($case-in@('race','partial')){if($failed-or$result.state-ne'running'-or$script:calls-ne2){throw "Retry failed: $case"}}
    elseif($case-eq'missing'){if(-not$failed-or$script:calls-ne3){throw 'Persistent missing file was masked'}}
    elseif(-not$failed-or$script:calls-ne1){throw 'Permission denial was retried'}
    "PASS: $case"
}
