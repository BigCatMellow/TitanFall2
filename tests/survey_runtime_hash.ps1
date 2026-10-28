$ErrorActionPreference='Stop'
. "$PSScriptRoot/../tools/Read-SurveyRuntimeHash.ps1"
$a='a'*64;$b='b'*64
foreach($plan in @(@{dll_sha256=$a},@{native_sha256=$a},@{dll_sha256=$a;native_sha256=$a.ToUpperInvariant()})){
    if((Read-SurveyRuntimeHash ([pscustomobject]$plan))-ne$a){throw 'Compatible schema rejected'}
    'PASS: compatible hash schema'
}
foreach($plan in @(@{},@{native_sha256='bad'},@{dll_sha256=$a;native_sha256=$b})){
    $failed=$false
    try{Read-SurveyRuntimeHash ([pscustomobject]$plan)|Out-Null}catch{$failed=$true}
    if(-not$failed){throw 'Invalid or conflicting evidence accepted'}
    'PASS: invalid/conflicting hash rejected'
}
