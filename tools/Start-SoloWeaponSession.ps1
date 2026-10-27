param([string]$Profile="$env:USERPROFILE\northstar-crash-audit\local-test-profile",
    [string]$GameDirectory='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2',
    [string]$NotesRoot="$env:USERPROFILE\northstar-crash-audit\Notes\weapon-notebook\sessions",
    [ValidateSet('normal_play','controlled_validation')][string]$Mode='normal_play')
$ErrorActionPreference='Stop'
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is already running'}
$node=(Get-Command node.exe -ErrorAction Stop).Source
if(-not(Test-Path "$Profile/mods/Solo.WeaponNotes/mod.json")){throw 'Solo.WeaponNotes is missing from this profile'}
# Read and validate metadata before starting either process. Use .NET hashing
# so the ordinary Windows PowerShell shortcut does not need module autoloading.
$stream=[IO.File]::OpenRead("$Profile/plugins/bp_ort.dll")
$hasher=[Security.Cryptography.SHA256]::Create()
try{$nativeHash=[BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$hasher.Dispose()}
$core=(Get-Item "$Profile/Northstar.dll").VersionInfo.FileVersion
$mods=@(Get-ChildItem "$Profile/mods" -Filter mod.json -Recurse|ForEach-Object{Get-Content -Raw -LiteralPath $_.FullName|ConvertFrom-Json}|Where-Object {$_.Name-like'Solo.*'-or$_.Name-like'BT7274.*'}|ForEach-Object{@{name=$_.Name;version=$_.Version}})
$enabled=Get-Content "$Profile/enabledmods.json" -Raw|ConvertFrom-Json
$cfg="$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
$settings=[ordered]@{}
foreach($line in Get-Content $cfg){
    if($line-match '^\s*(bot_[a-z_]+|bt7274_[a-z_]+|solo_weapon_balance[a-z_]*)\s+([-0-9.a-z]+)(?:\s|$)'){
        # Regex captures are plain strings. Windows PowerShell 5.1 otherwise
        # serializes Get-Content's attached provider/drive object graph.
        $settings[$Matches[1]]=$Matches[2]
    }
}
$session=Join-Path $NotesRoot ((Get-Date -Format yyyyMMdd-HHmmss)+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $session -Force|Out-Null
$since=[datetimeoffset]::Now.ToUnixTimeMilliseconds()
$game=Start-Process -FilePath "$GameDirectory/NorthstarLauncher.exe" -WorkingDirectory $GameDirectory -WindowStyle Normal -PassThru -ArgumentList "-profile=`"$Profile`"",'-novid','-fullscreen','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 16"','+solo_notes_mode',$Mode,'+mp_gamemode','tdm','+map','mp_eden'
$recorder=Start-Process -FilePath $node -WindowStyle Hidden -ArgumentList '--preserve-symlinks','--preserve-symlinks-main',"`"$PSScriptRoot/Record-WeaponNotes.mjs`"",'--profile',"`"$Profile`"",'--pid',"$($game.Id)",'--since',"$since",'--out',"`"$session`"" -RedirectStandardOutput "$session/recorder.stdout.log" -RedirectStandardError "$session/recorder.stderr.log" -PassThru
[ordered]@{session=(Split-Path $session -Leaf);started=(Get-Date).ToString('o');mode=$Mode;game_pid=$game.Id;recorder_pid=$recorder.Id;native_sha256=$nativeHash;core=$core;installed_addons=$mods;enabled_versions=$enabled;startup_settings=$settings;notes=$session;privacy='Anonymous entity/life identifiers only; no account IDs, preset names, screen/audio capture or upload'}|ConvertTo-Json -Depth 8|Set-Content "$session/session.json"
Get-Content "$session/session.json"
