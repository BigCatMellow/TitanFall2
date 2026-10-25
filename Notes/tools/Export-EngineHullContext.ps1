param(
    [string]$ServerDll='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2\server.dll',
    [Parameter(Mandatory=$true)][string]$OutputPath
)
# Reads the installed PE file, never a process. Checks the known function
# instructions before interpreting its table; these are static defaults.
$ErrorActionPreference='Stop'
$b=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ServerDll))
if([BitConverter]::ToUInt16($b,0)-ne0x5a4d){throw 'Not a PE file'}
$pe=[BitConverter]::ToInt32($b,60)
if([BitConverter]::ToUInt32($b,$pe)-ne0x4550 -or [BitConverter]::ToUInt16($b,$pe+24)-ne0x20b){throw 'Expected PE32+'}
$imageBase=[BitConverter]::ToUInt64($b,$pe+48)
$count=[BitConverter]::ToUInt16($b,$pe+6)
$start=$pe+24+[BitConverter]::ToUInt16($b,$pe+20)
$sections=@(for($i=0;$i-lt$count;$i++){
    $o=$start+$i*40
    [pscustomobject]@{rva=[BitConverter]::ToUInt32($b,$o+12);size=[BitConverter]::ToUInt32($b,$o+16);raw=[BitConverter]::ToUInt32($b,$o+20)}
})
function Offset([long]$rva){
    $s=@($sections|Where-Object {$rva-ge$_.rva -and $rva-lt([long]$_.rva+$_.size)})
    if($s.Count-ne1){throw "Unmapped RVA $rva"}
    return [int]($rva-$s[0].rva+$s[0].raw)
}
function Rva([long]$raw){
    $s=@($sections|Where-Object {$raw-ge$_.raw -and $raw-lt([long]$_.raw+$_.size)})
    if($s.Count-ne1){throw "Unmapped file offset $raw"}
    return [long]($raw-$s[0].raw+$s[0].rva)
}
function CString([long]$rva){
    $o=Offset $rva; $end=$o
    while($end-lt$b.Length -and $end-$o-lt128 -and $b[$end]-ne0){$end++}
    if($end-$o-ge128){throw 'Unexpected hull string'}
    return [Text.Encoding]::ASCII.GetString($b,$o,$end-$o)
}
$fnRva=0x35e200; $fn=Offset $fnRva
$prefix=[BitConverter]::ToString($b,$fn,6)
$tail=[BitConverter]::ToString($b,$fn+10,8)
if($prefix-ne'48-63-C1-48-8D-0D' -or $tail-ne'48-C1-E0-06-8B-04-08-C3'){throw 'GetNavMeshHullIndex instructions differ; do not decode this build'}
$indexTableRva=$fnRva+10+[BitConverter]::ToInt32($b,$fn+6)
$enumNames=@('Human','Medium','FlyingVehicle','Small','Titan')
$hulls=@(for($i=0;$i-lt5;$i++){
    $o=Offset ($indexTableRva+$i*64)
    $namePointer=[BitConverter]::ToUInt64($b,$o-56)
    [pscustomobject]@{plugin_hull=$enumNames[$i];hull_id=$i;engine_name=(CString ($namePointer-$imageBase));navmesh_index=[BitConverter]::ToInt32($b,$o)}
})
if($hulls[0].engine_name-ne'HULL_HUMAN'){throw 'Hull table name check failed'}
$latin=[Text.Encoding]::GetEncoding(28591)
$binary=$latin.GetString($b)
$suffixes=@(foreach($name in @('small','med_short','medium','large')){
    $stringMatches=[regex]::Matches($binary,[regex]::Escape(([char]0)+$name+([char]0)))
    foreach($m in $stringMatches){
        $rva=Rva ($m.Index+1)
        $pointer=[BitConverter]::GetBytes([uint64]($imageBase+$rva))
        $refs=@([regex]::Matches($binary,[regex]::Escape($latin.GetString($pointer)))|ForEach-Object{[pscustomobject]@{file_offset=$_.Index;rva=(Rva $_.Index)}})
        [pscustomobject]@{suffix=$name;rva=$rva;pointer_references=$refs}
    }
})
$med=@($suffixes|Where-Object suffix -eq 'med_short')
if($med.Count-ne1 -or $med[0].pointer_references.Count-ne1){throw 'Expected one med_short pointer reference'}
$suffixArrayRva=$med[0].pointer_references[0].rva-8
$suffixArray=@(for($i=0;$i-lt4;$i++){
    $o=Offset ($suffixArrayRva+$i*8)
    [pscustomobject]@{index=$i;suffix=(CString ([BitConverter]::ToUInt64($b,$o)-$imageBase))}
})
if(($suffixArray.suffix -join ',')-ne'small,med_short,medium,large'){throw 'Suffix pointer array check failed'}
$arrayUses=@(foreach($m in [regex]::Matches($binary,'[\x48\x4c]\x8d[\x05\x0d\x15\x1d\x25\x2d\x35\x3d]')){
    $rva=Rva $m.Index
    if($rva+7+[BitConverter]::ToInt32($b,$m.Index+3)-eq$suffixArrayRva){$rva}
})
$result=[ordered]@{
    source=(Resolve-Path -LiteralPath $ServerDll).Path;sha256=(Get-FileHash -LiteralPath $ServerDll).Hash
    function_rva=$fnRva;index_table_rva=$indexTableRva;table_stride=64;hulls=$hulls;suffix_strings=$suffixes
    suffix_array_rva=$suffixArrayRva;suffix_array=$suffixArray;array_address_uses=$arrayUses
    limits='Offline PE inspection proves this installed file maps Human hull 0 to navmesh slot 0. Suffix strings and pointer references alone do not prove the loader maps slot 0 to small.nm; loader use and live patches still require verification. No game memory, configuration or binary was changed.'
}
$parent=Split-Path $OutputPath
if($parent){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
$result|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $OutputPath
$result|ConvertTo-Json -Depth 7
