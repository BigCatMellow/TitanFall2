param([string]$RepositoryRoot=(Split-Path $PSScriptRoot))
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
$culture=[Globalization.CultureInfo]::InvariantCulture
function N($value){[double]::Parse([string]$value,$culture)}
function Key($r){'{0}|{1}|{2}' -f $r.epoch,$r.slot,((N $r.t).ToString('F2',$culture))}
$inputFiles=[Collections.Generic.List[string]]::new()
$inputFiles.Add('research/trends-20261025/rounds.json')
$inputFiles.Add('tools/Build-WeaponAbilityReview.ps1')
$rounds=@(Get-Content -Raw -LiteralPath "$repo/research/trends-20261025/rounds.json"|ConvertFrom-Json)
$result=@(foreach($s in $rounds){
    $meta=Get-Content -Raw -LiteralPath "$repo/$($s.source)/metadata.json"|ConvertFrom-Json
    if($meta.build_line-notlike'*combat-decisions-v16*'){throw 'This review requires v16 data'}
    $combatRel=if($s.source-eq'Notes/sessions/nslog2026-10-24_23-16-24'){
        'Notes/sessions/combat-nslog2026-10-24_23-16-24/combat.csv'
    }else{($s.source -replace '/movement$','')+'/combat/combat.csv'}
    foreach($rel in @($combatRel,"$($s.source)/observations.csv","$($s.source)/metadata.json")){$inputFiles.Add($rel)}
    $cache=@{}
    foreach($c in Import-Csv -LiteralPath "$repo/$combatRel"){
        if($c.PSObject.Properties.Name-contains'active'){throw 'Review assumptions need updating for active diagnostics'}
        $key=Key $c
        if($cache.ContainsKey($key)){throw "Duplicate combat key: $key"}
        $cache[$key]=$c
    }
    $pilots=@(Import-Csv -LiteralPath "$repo/$($s.source)/observations.csv"|Where-Object{
        [int]$_.epoch-eq$s.epoch-and$_.map-eq$s.map-and(N $_.t)-ge$s.window_start-and(N $_.t)-le$s.window_end-and
        $_.bot-eq'1'-and$_.alive-eq'1'-and$_.titan-eq'0'
    })
    if($pilots.Count-ne$s.pilot_samples){throw "Pilot cohort count mismatch: $($s.source), epoch $($s.epoch)"}
    $matched=@(foreach($p in $pilots){$key=Key $p;if($cache.ContainsKey($key)){$cache[$key]}})
    [pscustomobject]@{
        source=$s.source;combat_source=$combatRel;map=$s.map;epoch=$s.epoch;cohort=$s.cohort;phase=$s.phase
        window_start=$s.window_start;window_end=$s.window_end;live_pilot_samples=$pilots.Count
        with_combat_cache=$matched.Count;without_combat_cache=$pilots.Count-$matched.Count
        cached_weapons=@($matched|Group-Object weapon|Sort-Object Name|ForEach-Object{[pscustomobject]@{weapon=$_.Name;samples=$_.Count}})
        cached_tactics=@($matched|Group-Object tactic|Sort-Object Name|ForEach-Object{[pscustomobject]@{tactic=$_.Name;samples=$_.Count}})
        cached_empty_not_reloading=@($matched|Where-Object{$_.clip-eq'0'-and$_.reloading-eq'0'}).Count
        cached_reloading=@($matched|Where-Object reloading -eq '1').Count
        current_ammo_verified=$false
    }
})
$out="$repo/research/weapons-abilities-20261025"
New-Item -ItemType Directory -Path $out -Force|Out-Null
$result|ConvertTo-Json -Depth 7|Set-Content -LiteralPath "$out/coverage.json"
$reload=Get-Content -Raw -LiteralPath "$repo/Notes/tests/weapon-reload-20261024/results.txt"
$reloadCases=@(foreach($m in [regex]::Matches($reload,'RELOAD_TEST: PASS map=(\S+) gun=(\S+) speedloader=(true|false) reload=([\d.]+)->([\d.]+) empty=([\d.]+)->([\d.]+)')){
    $normal=N $m.Groups[4].Value;$changed=N $m.Groups[5].Value
    $empty=N $m.Groups[6].Value;$changedEmpty=N $m.Groups[7].Value
    if([Math]::Abs($changed/$normal-0.9)-gt0.0001-or[Math]::Abs($changedEmpty/$empty-0.9)-gt0.0001){throw 'Archived reload multiplier mismatch'}
    [pscustomobject]@{weapon=$m.Groups[2].Value;speedloader=$m.Groups[3].Value-eq'true';normal_before=$normal;normal_after=$changed;empty_before=$empty;empty_after=$changedEmpty}
})
if($reloadCases.Count-ne8){throw 'Expected eight archived reload cases'}
$tactical=Get-Content -Raw -LiteralPath "$repo/Notes/tests/tactical-recharge-20261024/results.txt"
$rates=@(foreach($m in [regex]::Matches($tactical,'TACTICAL_TEST: PASS (\S+) base_rate=([\d.]+) half_rate=([\d.]+) duration=([\d.]+) ammo=(\d+)')){
    $base=N $m.Groups[2].Value;$half=N $m.Groups[3].Value
    if([Math]::Abs($half/$base-2)-gt0.001){throw 'Archived tactical refill multiplier mismatch'}
    [pscustomobject]@{weapon=$m.Groups[1].Value;refill_rate_before=$base;refill_rate_after=$half;recorded_duration=N $m.Groups[4].Value;recorded_ammo=[int]$m.Groups[5].Value}
})
$grapple=[regex]::Match($tactical,'TACTICAL_TEST: PASS grapple base=([\d.]+) half=([\d.]+) power_cell=true')
if($rates.Count-ne6-or-not$grapple.Success){throw 'Expected six setting checks and timed Grapple result'}
if([Math]::Abs((N $grapple.Groups[2].Value)/(N $grapple.Groups[1].Value)-0.5)-gt0.06){throw 'Archived Grapple ratio mismatch'}
if(-not$reload.Contains('bots_unchanged=15')-or-not$tactical.Contains('bots_unchanged=15')){throw 'Expected archived bot exclusion checks'}
[pscustomobject]@{
    evidence_date='2026-10-24';new_runtime_test=$false
    reload_cases=$reloadCases;reload_bot_transfer_stripping_exercised=$reload.Contains('bot_strip=true')
    tactical_setting_cases=$rates
    grapple=[pscustomobject]@{before=N $grapple.Groups[1].Value;after=N $grapple.Groups[2].Value;power_cell=$true}
    limits='Archived engine setting checks and one timed Grapple refill, not new tests, animation-time measurements for every gun or representative balance outcomes. v16 BOT_COMBAT caches can be stale.'
}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$out/archived-validation.json"
$lines=@('# Recorded weapon coverage','',
    'Phase windows match the map review. These are v16 BOT_COMBAT cache names joined to live bot-pilot frames, not verified current inventory/ammo. No shot, hit, damage, tactical-ready or ability-activation dataset is present. See FINDINGS.md.','',
    '| Map | Cohort | Phase | Live pilot samples | With combat cache | Cached weapon names |',
    '|---|---|---|---:|---:|---|')
$lines+=@($result|ForEach-Object{'| {0} | {1} | {2} | {3} | {4} | {5} |' -f $_.map,$_.cohort,$_.phase,$_.live_pilot_samples,$_.with_combat_cache,($_.cached_weapons.weapon-join', ')})
$lines+=@('','## Cohort totals','')
$lines+=@($result|Group-Object cohort|ForEach-Object{
    '- {0}: {1} recordings; {2} live pilot snapshots, {3} matched combat-cache snapshots.' -f $_.Name,$_.Count,($_.Group.live_pilot_samples|Measure-Object -Sum).Sum,($_.Group.with_combat_cache|Measure-Object -Sum).Sum
})
$lines|Set-Content -LiteralPath "$out/COVERAGE.md"
$lines+=@('','## Cached names by cohort','',
    '| Cohort | Cached weapon identifier | Matched pilot snapshots |','|---|---|---:|')
$lines+=@(foreach($g in $result|Group-Object cohort){
    $entries=@($g.Group.cached_weapons)
    $entries|Group-Object weapon|Sort-Object Name|ForEach-Object{'| {0} | {1} | {2} |' -f $g.Name,$_.Name,($_.Group.samples|Measure-Object -Sum).Sum}
})
$lines|Set-Content -LiteralPath "$out/COVERAGE.md"
foreach($rel in @('Notes/tests/weapon-reload-20261024/results.txt','Notes/tests/tactical-recharge-20261024/results.txt',
    'Notes/tests/weapon-reload-20261024/James.ReloadTest/mod/scripts/vscripts/james_reload_test.nut',
    'Notes/tests/tactical-recharge-20261024/James.TacticalProbe/mod/scripts/vscripts/james_tactical_probe.nut',
    'bp_ort/src/bots/cmds/basic_combat.rs','bp_ort/src/bots/combat_decisions.rs')){$inputFiles.Add($rel)}
foreach($mod in @('James.WeaponReload','James.TacticalRecharge')){
    Get-ChildItem -LiteralPath "$repo/$mod" -Recurse -File|ForEach-Object{$inputFiles.Add($_.FullName.Substring($repo.Length+1).Replace('\','/'))}
}
$hashes=@(foreach($rel in $inputFiles|Sort-Object -Unique){
    $bytes=[IO.File]::ReadAllBytes("$repo/$rel")
    $normalized=[Text.Encoding]::UTF8.GetBytes([Text.Encoding]::UTF8.GetString($bytes).Replace("`r`n","`n"))
    [pscustomobject]@{file=$rel;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($normalized)).ToLowerInvariant()}
})
[pscustomobject]@{hash_mode='UTF-8 text, CRLF normalized to LF';inputs=$hashes;game_launched=$false;production_code_changed=$false;deployed=$false}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath "$out/provenance.json"
"PASS: all$($result.Count) pilot cohort counts, unique combat joins, eight archived reload ratios, six tactical refill ratios and timed Grapple evidence. No game launched."
