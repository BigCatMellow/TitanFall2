param([string]$RepositoryRoot=(Split-Path $PSScriptRoot))
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
$files=@(& git -C $repo ls-files --cached --others --exclude-standard)
if($LASTEXITCODE-ne0){throw 'Cannot enumerate publication files'}
$issues=[Collections.Generic.List[object]]::new();$textCount=0;$gzipCount=0
$credential='\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{30,})\b|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
foreach($rel in $files){
    $path=Join-Path $repo $rel
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){continue}
    $item=Get-Item -LiteralPath $path
    if($item.Length-gt50MB){$issues.Add([pscustomobject]@{file=$rel;kind='Oversized repository file'})}
    if($rel-match'(?i)(?:^|/)(?:save_data|test-saves|baseline|target)(?:/|$)' -or $item.Extension-in@('.dll','.exe','.bin','.vpk','.starpak','.rpak','.dmp','.nm','.ain','.zip')){
        $issues.Add([pscustomobject]@{file=$rel;kind='Private/runtime/game binary path'})
    }
    if($item.Extension-eq'.png'){continue}
    if($item.Extension-eq'.gz'){
        $stream=[IO.File]::OpenRead($path);$gzip=[IO.Compression.GZipStream]::new($stream,[IO.Compression.CompressionMode]::Decompress);$reader=[IO.StreamReader]::new($gzip)
        try{$text=$reader.ReadToEnd()}finally{$reader.Dispose();$gzip.Dispose();$stream.Dispose()};$gzipCount++
    }else{$text=[IO.File]::ReadAllText($path);$textCount++}
    if([regex]::IsMatch($text,$credential)){$issues.Add([pscustomobject]@{file=$rel;kind='Credential/private key pattern'})}
    if([regex]::IsMatch($text,'(?i)https?://[^\s"<>]+\?[^\s"<>]*(?:token|tokencode|ticket|authToken|code)=[A-Za-z0-9_-]{12,}')){
        $issues.Add([pscustomobject]@{file=$rel;kind='Unredacted authentication URL pattern'})
    }
}
if(@(Get-ChildItem -LiteralPath "$repo\.github\workflows" -File -ErrorAction SilentlyContinue).Count){$issues.Add([pscustomobject]@{file='.github/workflows';kind='Active inherited workflow'})}
$result=[ordered]@{checked=(Get-Date).ToString('o');files=$files.Count;text_files=$textCount;compressed_logs=$gzipCount;issues=$issues.ToArray();limits='Pattern/size/path checks, not a guarantee against every secret. Imported account identifiers and auth fields are separately sanitized.'}
$result|ConvertTo-Json -Depth 5
if($issues.Count){throw "$($issues.Count) publication checks need review"}
