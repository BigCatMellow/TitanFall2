function Find-CornerRegression($Rows){
    foreach($pair in @($Rows|Group-Object map,repeat)){
        $off=@($pair.Group|Where-Object guard -eq 0);$on=@($pair.Group|Where-Object guard -eq 1)
        if($off.Count-ne1-or$on.Count-ne1){continue}
        $a=$off[0].metrics;$b=$on[0].metrics
        if($null-eq$a.low_progress_percent-or$null-eq$b.low_progress_percent){continue}
        if($a.live_pilot_samples-ge500-and$b.live_pilot_samples-ge500-and$b.low_progress_percent-gt($a.low_progress_percent+5)-and$b.low_progress_percent-gt(1.5*$a.low_progress_percent)){
            return [pscustomobject]@{map=$on[0].map;repeat=$on[0].repeat;off=$a.low_progress_percent;on=$b.low_progress_percent}
        }
    }
}
