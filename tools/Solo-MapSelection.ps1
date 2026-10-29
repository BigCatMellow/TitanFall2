function Resolve-SoloStartMap([string]$RequestedMap,[string]$GameDirectory,[string]$Profile) {
    # Standard full-size maps with completed bot survey rounds. Eden remains
    # available explicitly, but is excluded from the requested variety pool.
    $standard=@('mp_angel_city','mp_black_water_canal','mp_colony02','mp_complex3',
        'mp_crashsite3','mp_drydock','mp_forwardbase_kodai','mp_glitch','mp_grave',
        'mp_homestead','mp_relic02','mp_rise','mp_thaw','mp_wargames')
    $installed=@(Get-ChildItem -LiteralPath (Join-Path $GameDirectory 'vpk') -Filter '*_dir.vpk' -File |
        ForEach-Object {if($_.Name-match'client_(mp_[a-z0-9_]+)\.bsp\.pak000_dir\.vpk$'){$Matches[1]}} |
        Sort-Object -Unique)
    $pool=@($standard|Where-Object {$_-in$installed})
    $previous=''
    $state=Join-Path $Profile 'bt7274-last-random-map.txt'
    if(Test-Path -LiteralPath $state){$previous=[IO.File]::ReadAllText($state).Trim()}
    if($RequestedMap-eq'random'){
        if(!$pool.Count){throw 'No installed full-size maps are available for random solo play'}
        $eligible=@($pool|Where-Object {$_-ne$previous})
        if(!$eligible.Count){$eligible=$pool}
        $selected=Get-Random -InputObject $eligible
    }else{
        if($RequestedMap-notin$installed){throw "Map assets not found for $RequestedMap"}
        $selected=$RequestedMap
    }
    [pscustomobject]@{requested_map=$RequestedMap;map=[string]$selected;random_pool=$pool;previous_random_map=$previous}
}
