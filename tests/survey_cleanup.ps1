$ErrorActionPreference='Stop'
. "$PSScriptRoot/../tools/Stop-OwnedSurveyGame.ps1"
$profile='C:\test\survey'
$script:metadata=[pscustomobject]@{Name='NorthstarLauncher.exe';CommandLine='NorthstarLauncher.exe -profile=C:\test\survey -novid'}
function Get-CimInstance {param($ClassName,$Filter,$ErrorAction);$script:metadata}
function Fake([string]$mode){
    $p=[pscustomobject]@{Id=12345;HasExited=($mode-eq'exited');mode=$mode;kills=0}
    $p|Add-Member ScriptMethod Refresh {}
    $p|Add-Member ScriptMethod Kill {
        $this.kills++
        if($this.mode-eq'denied'){throw 'access denied'}
        $this.HasExited=$true
        if($this.mode-eq'race'){throw 'already exited'}
    }
    $p|Add-Member ScriptMethod WaitForExit {param($milliseconds);$this.mode-ne'timeout'}
    $p
}
function Require([bool]$ok,[string]$message){if(-not$ok){throw $message};"PASS: $message"}
$p=Fake exited;Stop-OwnedSurveyGame $p $profile;Require ($p.kills-eq0) 'Already-exited games need no kill'
$p=Fake race;Stop-OwnedSurveyGame $p $profile;Require ($p.HasExited-and$p.kills-eq1) 'Natural exit between ownership check and kill succeeds'
$p=Fake normal;Stop-OwnedSurveyGame $p $profile;Require ($p.HasExited-and$p.kills-eq1) 'Owned live game is stopped through its original handle'
$script:metadata.CommandLine='NorthstarLauncher.exe -profile=C:\test\survey-other'
$p=Fake normal;Stop-OwnedSurveyGame $p $profile;Require ($p.kills-eq0) 'A neighboring profile name is not ownership'
$script:metadata.CommandLine='NorthstarLauncher.exe -profile="C:\test\survey" -novid'
$p=Fake normal;Stop-OwnedSurveyGame $p $profile;Require ($p.kills-eq1) 'Quoted exact profile is recognized'
$script:metadata.Name='unrelated.exe';$p=Fake normal;Stop-OwnedSurveyGame $p $profile;Require ($p.kills-eq0) 'Unrelated executable is never killed'
$script:metadata.Name='NorthstarLauncher.exe'
$p=Fake denied;$rejected=$false;try{Stop-OwnedSurveyGame $p $profile}catch{$rejected=$true};Require ($rejected-and-not$p.HasExited) 'A live-process kill failure remains an error'
$p=Fake timeout;$rejected=$false;try{Stop-OwnedSurveyGame $p $profile}catch{$rejected=$true};Require $rejected 'A shutdown timeout remains an error'
'8 cleanup checks passed; no real process was killed.'
