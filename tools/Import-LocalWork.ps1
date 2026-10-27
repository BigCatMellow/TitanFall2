param(
    [string]$AuditRoot="$env:USERPROFILE\northstar-crash-audit",
    [string]$RepositoryRoot=(Split-Path $PSScriptRoot),
    [switch]$RecoverExisting,
    [switch]$HistoryOnly
)
# Import authored work/research, not a distributable copy of the installed game.
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepositoryRoot)
$audit=[IO.Path]::GetFullPath($AuditRoot)
$notes=Join-Path $audit 'Notes'
$manifest=[Collections.Generic.List[object]]::new()
$accountIds=@(Get-ChildItem -LiteralPath "$audit\local-test-profile\save_data\BT7274.LocalPersistence" -Filter 'loadouts_*.json'|ForEach-Object{if($_.BaseName-match'^loadouts_(\d+)$'){$Matches[1]}})
function Clean([string]$text){
    foreach($account in $accountIds){$text=$text.Replace($account,'LOCAL_PLAYER_UID')}
    $text=[regex]::Replace($text,'(?i)https?://[^\s"<>]+',{
        param($m)
        if($m.Value-match'\?.*(?:token|tokencode|ticket|authcode|code=|password=)'){
            return $m.Value.Split('?')[0]+'?[REDACTED_AUTH_QUERY]'
        };return $m.Value
    })
    $text=[regex]::Replace($text,'(?i)(\b(?:tokencode|authToken|userToken|access_token|refresh_token|rcon_password|password)\s*[=:]\s*)(?:"[^"\r\n]*"|[^\s&",<>]+)','$1[REDACTED]')
    $text=[regex]::Replace($text,'\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{30,})\b','[REDACTED_CREDENTIAL]')
    return $text
}
function Reason([string]$rel,[string]$ext){
    if($rel-match'(?i)(?:^|/)live-human[^/]*\.json$'){return 'Private live persistence-capture metadata'}
    if($rel-match'(?i)(?:^|/)(?:save_data|test-saves|baseline|invalid-test-save[^/]*|target|\.git)(?:/|$)' -or $rel-match'(?i)(?:^|/)(?:loadouts_\d+|previous_\d+|auth)\.(?:json|bin)') {return 'Personal/runtime state or generated build tree'}
    if($rel-match'(?i)^backups/[^/]+/(?:regular|solo|test)/' -or $rel-match'(?i)(?:^|/)(?:Northstar\.[^/]+|R2Northstar)(?:/|$)'){return 'Installed third-party/game mod backup; use upstream distribution'}
    if($rel-match'(?i)(?:^|/)mp_weapon_[^/]+\.txt$' -or $ext-in@('.gnut','.pdef','.pdiff')){return 'Extracted game resource; research conclusions retained'}
    if($ext-in@('.dll','.exe','.pdb','.bin','.dmp','.vpk','.starpak','.rpak','.mdl','.nm','.ain','.vtf','.vmt','.ttf','.res')){return 'Binary/game asset or machine snapshot; hashes retained, rebuild/reinstall separately'}
    if($ext-eq'.zip'){return 'Archive retained locally; source snapshots expanded separately when applicable'}
    if($ext-notin@('.md','.ps1','.cmd','.rs','.toml','.lock','.json','.csv','.html','.patch','.yml','.yaml','.nut','.txt','.set','.cfg','.menu','.rson','.gitignore','.js','.nix','.log','.png','')){return 'Unclassified local artifact'}
    return $null
}
function RecordExcluded([string]$source,[string]$rel,[string]$reason){
    $item=Get-Item -LiteralPath $source
    $manifest.Add([pscustomobject]@{source=(Clean $rel);published=$null;bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $source).Hash;status='excluded';reason=$reason})
}
function Publish([string]$source,[string]$rel,[string]$destRel){
    $item=Get-Item -LiteralPath $source;$reason=Reason $rel $item.Extension.ToLowerInvariant()
    if($reason){RecordExcluded $source $rel $reason;return}
    $destRel=Clean $destRel
    if($item.Extension-eq'.log'){$destRel+='.gz'}
    $dest=[IO.Path]::GetFullPath((Join-Path $repo $destRel))
    if(-not$dest.StartsWith($repo+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Import destination escaped repository'}
    New-Item -ItemType Directory -Path (Split-Path $dest) -Force|Out-Null
    if($RecoverExisting -and (Test-Path -LiteralPath $dest)){
        # Explicit recovery of an interrupted import; never read this tool's
        # own still-open output stream as source input.
    }
    elseif($item.Extension-eq'.png'){Copy-Item -LiteralPath $source -Destination $dest -Force}
    else{
        $text=Clean ([IO.File]::ReadAllText($source))
        if($item.Extension-eq'.log'){
            $stream=[IO.File]::Open($dest,[IO.FileMode]::Create)
            $gzip=[IO.Compression.GZipStream]::new($stream,[IO.Compression.CompressionLevel]::Optimal)
            $writer=[IO.StreamWriter]::new($gzip,[Text.UTF8Encoding]::new($false))
            try{$writer.Write($text)}finally{$writer.Dispose();$gzip.Dispose();$stream.Dispose()}
        }else{[IO.File]::WriteAllText($dest,$text,[Text.UTF8Encoding]::new($false))}
    }
    $manifest.Add([pscustomobject]@{source=(Clean $rel);published=$destRel.Replace('\','/');bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $source).Hash;published_sha256=(Get-FileHash -LiteralPath $dest).Hash;status='included';reason=if($item.Extension-eq'.log'){'Sanitized UTF-8 log compressed as gzip'}else{'Authored source, notes or derived research; account/auth text sanitized'}})
}
if($HistoryOnly){
    foreach($record in @(Get-Content -Raw -LiteralPath "$repo\docs\LOCAL-IMPORT-MANIFEST.json"|ConvertFrom-Json)){$manifest.Add($record)}
}
if(-not$HistoryOnly){
foreach($file in Get-ChildItem -LiteralPath $notes -Recurse -File){
    $rel=$file.FullName.Substring($notes.Length+1).Replace('\','/')
    Publish $file.FullName $rel ('Notes/'+$rel)
}
# Runtime-only authored harnesses were not all present in the Rust checkout.
foreach($profile in @('local-test-profile','map-cycle-test-profile')){
    foreach($mod in Get-ChildItem -LiteralPath "$audit\$profile\mods" -Directory|Where-Object Name -like 'BT7274.*'){
        foreach($file in Get-ChildItem -LiteralPath $mod.FullName -Recurse -File){
            $rel=$file.FullName.Substring($mod.FullName.Length+1).Replace('\','/')
            Publish $file.FullName ("runtime-mods/$profile/$($mod.Name)/$rel") ("automation/runtime-mods/$profile/$($mod.Name)/$rel")
        }
    }
}
foreach($file in Get-ChildItem -LiteralPath $audit -File){
    if($file.Name-eq'project-import.log'){continue}
    Publish $file.FullName ('audit-root/'+$file.Name) ('automation/legacy/'+$file.Name)
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$snapshots=@(Get-ChildItem -LiteralPath "$notes\source-snapshots" -Filter '*.zip')
$snapshots+=@(Get-ChildItem -LiteralPath "$notes\candidates" -Recurse -Filter 'source-candidate.zip')
foreach($snapshot in $snapshots){
    $archive=[IO.Compression.ZipFile]::OpenRead($snapshot.FullName)
    $label=if($snapshot.BaseName-eq'source-candidate'){$snapshot.Directory.Name}else{$snapshot.BaseName}
    try{
        foreach($entry in $archive.Entries){
            if($entry.FullName.EndsWith('/')){continue}
            $rel=$entry.FullName.Replace('\','/')
            if($rel-match'(^|/)\.\.(/|$)' -or [IO.Path]::IsPathRooted($rel)){throw 'Invalid archive entry path'}
            $ext=[IO.Path]::GetExtension($rel).ToLowerInvariant()
            if(Reason $rel $ext){continue}
            if($ext-eq'.png'){continue}
            $destRel=Clean ("history/source-snapshots/$label/$rel")
            $dest=[IO.Path]::GetFullPath((Join-Path $repo $destRel))
            if(-not$dest.StartsWith($repo+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Archive entry escaped repository'}
            $reader=[IO.StreamReader]::new($entry.Open());try{$text=Clean ($reader.ReadToEnd())}finally{$reader.Dispose()}
            New-Item -ItemType Directory -Path (Split-Path $dest) -Force|Out-Null
            [IO.File]::WriteAllText($dest,$text,[Text.UTF8Encoding]::new($false))
        }
}finally{$archive.Dispose()}
}
}
foreach($dir in Get-ChildItem -LiteralPath $audit -Directory|Where-Object{$_.Name-notin@('Notes','local-test-profile','map-cycle-test-profile','TitanFall2-project','NorthstarLauncher')}){
    foreach($file in Get-ChildItem -LiteralPath $dir.FullName -Recurse -File){
        $rel=$file.FullName.Substring($audit.Length+1).Replace('\','/')
        Publish $file.FullName ('audit-history/'+$rel) ('automation/history/'+$rel)
    }
}
New-Item -ItemType Directory -Path "$repo\docs" -Force|Out-Null
$manifest.ToArray()|ConvertTo-Json -Depth 4|Set-Content -LiteralPath "$repo\docs\LOCAL-IMPORT-MANIFEST.json"
$manifest|Group-Object status|Select-Object Name,Count|ConvertTo-Json
