param([string]$RepositoryRoot=(Split-Path $PSScriptRoot),[switch]$SelfTest)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
$culture=[Globalization.CultureInfo]::InvariantCulture
$navStates=@('pursue','recover','embark','retreat')
function N($value){return [double]::Parse([string]$value,$culture)}
function Percent($n,$d){if($d){return [Math]::Round(100*$n/$d,2)};return $null}
function MarkProgress($rows){
    foreach($r in $rows){$r|Add-Member calc_low 0 -Force;$r|Add-Member calc_continuous 0 -Force}
    foreach($g in $rows|Where-Object bot -eq '1'|Group-Object slot){
        $a=@($g.Group|Sort-Object{N $_.t})
        for($i=1;$i-lt$a.Count;$i++){
            $r=$a[$i]
            if($r.alive-ne'1'-or$r.titan-ne'0'-or$r.state-notin$navStates){continue}
            $continuous=$true
            for($j=$i-1;$j-ge0;$j--){
                $p=$a[$j]
                if($p.alive-ne'1'-or$p.titan-ne'0'-or$p.id-ne$r.id-or(N $a[$j+1].t)-(N $p.t)-gt2.1){break}
                if($p.state-notin$navStates){$continuous=$false}
                $age=(N $r.t)-(N $p.t)
                if($age-ge10){
                    if($age-le13 -and [Math]::Pow((N $r.x)-(N $p.x),2)+[Math]::Pow((N $r.y)-(N $p.y),2)-lt2500){
                        $r.calc_low=1;if($continuous){$r.calc_continuous=1}
                    };break
                }
            }
        }
    }
}
function PlayedBounds([string]$path){
    $stream=[IO.File]::OpenRead($path);$gzip=[IO.Compression.GZipStream]::new($stream,[IO.Compression.CompressionMode]::Decompress);$reader=[IO.StreamReader]::new($gzip)
    $bounds=@{};$last=$null
    try{while($null-ne($line=$reader.ReadLine())){
        if($line-match'BOT_FRAME epoch=(\d+) map=(\S+) t=([\d.]+)'){$last=@{key="$($Matches[1])|$($Matches[2])";t=(N $Matches[3])}}
        elseif($last-and$line.Contains('BOT_LIFECYCLE: match playing')){$bounds[$last.key]=@{start=$last.t;end=$null}}
        elseif($last-and$line.Contains('Match Complete')-and$bounds.ContainsKey($last.key)){$bounds[$last.key].end=$last.t}
    }}finally{$reader.Dispose();$gzip.Dispose();$stream.Dispose()}
    return $bounds
}
if($SelfTest){
    $rows=@(0..6|ForEach-Object{[pscustomobject]@{slot='1';id='5';bot='1';alive='1';titan='0';state='pursue';t=[string]($_*2);x='0';y='0'}})
    MarkProgress $rows
    if(@($rows|Where-Object calc_continuous -eq 1).Count-ne2){throw 'Continuous navigation fixture failed'}
    $rows[2].state='engage';MarkProgress $rows
    if(@($rows|Where-Object calc_low -eq 1).Count-ne2 -or @($rows|Where-Object calc_continuous -eq 1).Count-ne0){throw 'Intentional hold exclusion failed'}
    $rows[2].state='pursue';$rows[2].alive='0';MarkProgress $rows
    if(@($rows|Where-Object calc_low -eq 1).Count-ne0){throw 'Life-boundary exclusion failed'}
    'PASS: sustained navigation, intervening intentional hold, and life reset fixtures';return
}
$inputs=[Collections.Generic.List[object]]::new()
foreach($r in Get-Content -Raw -LiteralPath "$repo\Notes\review-paused-20261025\map-comparison.json"|ConvertFrom-Json){
    $rel='Notes/'+(($r.movement_source -split '\\Notes\\',2)[1]).Replace('\','/')
    $inputs.Add([pscustomobject]@{movement=$rel;cohort=if($r.state-eq'complete'){'controlled-complete'}else{'controlled-partial'};phase=$r.phase;original_stall_percent=$r.stall_percent})
}
$inputs.Add([pscustomobject]@{movement='Notes/trend-analysis-20261025/played-latest/movement';cohort='played';phase='Played 2026-10-25';original_stall_percent=$null})
$inputs.Add([pscustomobject]@{movement='Notes/sessions/nslog2026-10-24_23-16-24';cohort='played';phase='Played 2026-10-24';original_stall_percent=$null})
$results=[Collections.Generic.List[object]]::new()
foreach($sourceSpec in $inputs){
    $dir=Join-Path $repo $sourceSpec.movement
    $meta=Get-Content -Raw -LiteralPath "$dir\metadata.json"|ConvertFrom-Json
    if($meta.build_line-notlike'*combat-decisions-v16*'){throw "Unexpected build: $($sourceSpec.movement)"}
    $bounds=if($sourceSpec.cohort-eq'played'){PlayedBounds "$dir\archived.log.gz"}else{@{}}
    $rows=@(Import-Csv -LiteralPath "$dir\observations.csv")
    foreach($g in $rows|Where-Object map -ne mp_lobby|Group-Object epoch,map){
        $r0=$g.Group[0];$key="$($r0.epoch)|$($r0.map)";$a=@($g.Group)
        if($sourceSpec.cohort-eq'played'){
            if(-not$bounds.ContainsKey($key)-or$null-eq$bounds[$key].end){throw "Missing played round boundary: $key"}
            $b=$bounds[$key];$a=@($a|Where-Object{(N $_.t)-ge$b.start-and(N $_.t)-le$b.end})
        }
        MarkProgress $a
        $pilots=@($a|Where-Object{$_.bot-eq'1'-and$_.alive-eq'1'-and$_.titan-eq'0'})
        $low=@($pilots|Where-Object calc_low -eq 1);$sustained=@($pilots|Where-Object calc_continuous -eq 1)
        $engage=@($pilots|Where-Object{$_.state-eq'engage'-and$_.visible-eq'1'-and[int]$_.target-ge0})
        $overhead=@($engage|Where-Object{(N $_.tz)-(N $_.z)-gt5000})
        $top=@($sustained|Group-Object{('{0},{1},{2}' -f ([Math]::Round((N $_.x)/128)*128),([Math]::Round((N $_.y)/128)*128),([Math]::Round((N $_.z)/64)*64))}|Sort-Object Count -Descending|Select-Object -First 3|ForEach-Object{[pscustomobject]@{cell=$_.Name;samples=$_.Count;slots=@($_.Group.slot|Sort-Object -Unique)}})
        $times=@($a.t|ForEach-Object{N $_}|Sort-Object -Unique)
        $results.Add([pscustomobject]@{
            map=$r0.map;epoch=[int]$r0.epoch;cohort=$sourceSpec.cohort;phase=$sourceSpec.phase;source=$sourceSpec.movement
            window_start=$times[0];window_end=$times[-1];window_span=$times[-1]-$times[0]
            pilot_samples=$pilots.Count;legacy_style_low_samples=$low.Count;legacy_style_percent=(Percent $low.Count $pilots.Count)
            continuous_navigation_low_samples=$sustained.Count;continuous_navigation_percent=(Percent $sustained.Count $pilots.Count)
            original_untrimmed_percent=$sourceSpec.original_stall_percent
            crowded_pilot_samples=@($pilots|Where-Object{[int]$_.near_allies-ge2}).Count
            visible_engage_samples=$engage.Count;overhead_engage_samples=$overhead.Count;overhead_engage_percent=(Percent $overhead.Count $engage.Count)
            states=@($pilots|Group-Object state|ForEach-Object{[pscustomobject]@{state=$_.Name;samples=$_.Count}})
            sustained_hotspots=$top
        })
    }
}
$out=Join-Path $repo 'research/trends-20261025'
New-Item -ItemType Directory -Path $out -Force|Out-Null
$results.ToArray()|ConvertTo-Json -Depth 7|Set-Content -LiteralPath "$out\rounds.json"
$groups=@(foreach($g in $results|Group-Object cohort,map){
    $p=($g.Group.pilot_samples|Measure-Object -Sum).Sum;$low=($g.Group.continuous_navigation_low_samples|Measure-Object -Sum).Sum
    [pscustomobject]@{map=$g.Group[0].map;cohort=$g.Group[0].cohort;rounds=$g.Count;pilot_samples=$p;continuous_navigation_low_samples=$low;continuous_navigation_percent=(Percent $low $p)}
})
$groups|ConvertTo-Json -Depth 4|Set-Content -LiteralPath "$out\map-cohorts.json"
$limits='Stable v16 only. Played rounds trimmed from playing callback to match-complete using preceding two-second frames (approximate boundaries). No lobbies. Low progress means below50 XY units net displacement over10-13seconds; strict variant also requires all sampled states in that window to be navigation/recovery/boarding and the same live pilot. Samples overlap and are not independent incidents. Cohorts, partial rounds and small arenas remain separate; no causal gameplay/balance conclusion follows from percentages alone.'
$lines=@('# Phase-aware v16 trend summary','',$limits,'','| Map | Cohort | Recordings | Live pilot samples | Sustained navigation low progress |','|---|---|---:|---:|---:|')
$lines+=@($groups|Sort-Object cohort,map|ForEach-Object{'| {0} | {1} | {2} | {3} | {4}% |' -f $_.map,$_.cohort,$_.rounds,$_.pilot_samples,$_.continuous_navigation_percent})
[IO.File]::WriteAllLines("$out\SUMMARY.md",$lines,[Text.UTF8Encoding]::new($false))
$groups|ConvertTo-Json -Depth 4
