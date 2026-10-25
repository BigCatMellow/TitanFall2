param([Parameter(Mandatory=$true)][string]$LogPath)
$map = 'Kodai'
$samples = @()
$lines = Get-Content -LiteralPath $LogPath
foreach ($line in $lines) {
    if ($line -match 'BOT_CYCLE_TEST: .* to Relic') { $map = 'Relic' }
    if ($line -match 'BOT_CYCLE_TEST: .* to Wargames') { $map = 'Wargames' }
    if ($line -match 'BOT_MOTION slot=(\d+) mode=(\d+) hp=(-?\d+).*horizontal_delta=([\d.]+)') {
        $samples += [pscustomobject]@{Map=$map; Slot=[int]$Matches[1]; Mode=[int]$Matches[2]; HP=[int]$Matches[3]; Displacement=[double]$Matches[4]}
    }
}
foreach ($group in ($samples | Group-Object Map)) {
    $alive = @($group.Group | Where-Object HP -gt 0)
    $moving = @($alive | Where-Object Displacement -ge 200)
    [pscustomobject]@{
        Map=$group.Name
        BotSlots=@($group.Group.Slot | Sort-Object -Unique).Count
        Samples=$group.Count
        AliveSamples=$alive.Count
        SlotsWith200UnitDisplacement=@($moving.Slot | Sort-Object -Unique).Count
        AliveSamplesBelow50Units=@($alive | Where-Object Displacement -lt 50).Count
        MeanDisplacement=[Math]::Round(($alive | Measure-Object Displacement -Average).Average,1)
        DamagedOrDeadSamples=@($group.Group | Where-Object HP -lt 100).Count
    }
}
"Bot joins: $(@($lines | Select-String 'spawned a bot :').Count)"
"Script errors / crashes / panics: $(@($lines | Select-String 'SCRIPT ERROR|Exception Access Violation|panicked at|FATAL ERROR').Count)"
