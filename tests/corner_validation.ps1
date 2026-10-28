$ErrorActionPreference='Stop'
. "$PSScriptRoot/../tools/Read-CornerValidation.ps1"
$hash='a'*64
function Evidence {
    @([pscustomobject]@{state='passed';lobby=$true;core='1.31.14.0';completed=@('nav_control','nav_guard','nav_respawn','nav_disabled','nav_new_map')},
      [pscustomobject]@{native_sha256=$hash;bridge_sha256=$hash},
      [pscustomobject]@{experiment='navigation_v22';population='16bots_inactive_human';core_sha256=$hash})
}
$e=Evidence;Test-CornerValidationEvidence $e[0] $e[1] $e[2] $hash $hash $hash
'PASS: complete matching navigation smoke'
foreach($case in @('partial','lobby','core','native','bridge','experiment','population')){
    $e=Evidence
    switch($case){
        partial{$e[0].completed=@('nav_control')}
        lobby{$e[0].lobby=$false}
        core{$e[2].core_sha256='b'*64}
        native{$e[1].native_sha256='b'*64}
        bridge{$e[1].bridge_sha256='b'*64}
        experiment{$e[2].experiment='safety_v21'}
        population{$e[2].population='15bots_active_human'}
    }
    $failed=$false;try{Test-CornerValidationEvidence $e[0] $e[1] $e[2] $hash $hash $hash}catch{$failed=$true}
    if(-not$failed){throw "Accepted invalid evidence: $case"};"PASS: reject $case"
}
