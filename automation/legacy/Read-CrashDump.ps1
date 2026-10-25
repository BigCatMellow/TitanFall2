param([Parameter(Mandatory=$true)][string]$DumpPath)
$ErrorActionPreference='Stop'
$dump=[IO.File]::ReadAllBytes($DumpPath)
function U32([long]$offset){ [BitConverter]::ToUInt32($dump,[int]$offset) }
function U64([long]$offset){ [BitConverter]::ToUInt64($dump,[int]$offset) }
$streams=@{}
$directory=U32 12
for($i=0;$i -lt (U32 8);$i++){ $entry=$directory+12*$i; $streams[[int](U32 $entry)]=@{Size=(U32 ($entry+4));Rva=(U32 ($entry+8))} }
$mods=@()
$m=$streams[4].Rva
for($i=0;$i -lt (U32 $m);$i++){
    $offset=$m+4+108*$i
    $name=U32 ($offset+20)
    $mods += [pscustomobject]@{Base=(U64 $offset);Size=(U32 ($offset+8));Name=[IO.Path]::GetFileName([Text.Encoding]::Unicode.GetString($dump,$name+4,(U32 $name)))}
}
function Describe([ulong]$address){
    foreach($mod in $mods){if($address -ge $mod.Base -and $address -lt $mod.Base+$mod.Size){ return ('{0}+0x{1:x}' -f $mod.Name,($address-$mod.Base)) }}
    return ('0x{0:x}' -f $address)
}
$exception=$streams[6].Rva
$context=U32 ($exception+164)
$rsp=U64 ($context+152)
[pscustomobject]@{Exception=('0x{0:x}' -f (U32 ($exception+8)));Fault=(Describe (U64 ($exception+24)));Thread=(U32 $exception);RSP=('0x{0:x}' -f $rsp)} | Format-List
$threads=$streams[3].Rva
$ranges=@()
if($streams.ContainsKey(9)){
    $mem=$streams[9].Rva;$cursor=U64 ($mem+8)
    for($j=0;$j -lt (U64 $mem);$j++){
        $r=$mem+16+16*$j;$length=U64 ($r+8)
        $ranges += [pscustomobject]@{Start=(U64 $r);Size=$length;Rva=$cursor}
        $cursor+=$length
    }
}
if($streams.ContainsKey(5)){
    $mem=$streams[5].Rva
    for($j=0;$j -lt (U32 $mem);$j++){
        $r=$mem+4+16*$j
        $ranges += [pscustomobject]@{Start=(U64 $r);Size=(U32 ($r+8));Rva=(U32 ($r+12))}
    }
}
for($i=0;$i -lt (U32 $threads);$i++){
    $t=$threads+4+48*$i
    if((U32 $t) -ne (U32 $exception)){continue}
    $start=U64 ($t+24);$size=U32 ($t+32);$data=U32 ($t+36)
    if($data -eq 0){
        $range=$ranges | Where-Object {$rsp -ge $_.Start -and $rsp -lt $_.Start+$_.Size} | Select-Object -First 1
        if(!$range){throw 'Exception stack memory is absent from dump'}
        $start=$range.Start;$size=$range.Size;$data=$range.Rva
    }
    $begin=[long]($rsp-$start)
    [pscustomobject]@{StackStart=('0x{0:x}' -f $start);StackSize=$size;StackRva=$data;ScanOffset=$begin} | Format-List
    $hits=0
    for($o=$begin;$o -lt [Math]::Min($size,$begin+8192);$o+=8){
        $value=U64 ($data+$o);$description=Describe $value
        if($description -match '\.dll\+|\.exe\+'){
            '{0:x4} {1}' -f ($o-$begin),$description
            $hits++
            if($hits -ge 220){break}
        }
    }
}
