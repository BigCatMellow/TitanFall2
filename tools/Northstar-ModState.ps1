# Northstar 1.31 enabledmods Version1 uses per-version objects. A bare false
# is not a valid disabled version entry: the loader may auto-enable the mod.
function Assert-NorthstarProfilePath([string]$Profile,[string]$Path) {
    $root=[IO.Path]::GetFullPath($Profile).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath($Path)
    if(-not$full.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Operation escapes the explicitly selected profile'}
}
function Test-NorthstarModEnabled($Value) {
    if($Value -is [bool]){return $Value}
    if($null-eq$Value){return $false}
    foreach($p in $Value.PSObject.Properties){if($p.Value -is [bool] -and $p.Value){return $true}}
    return $false
}
function Copy-NorthstarModState($Value) {
    if($Value -is [bool]){return $Value}
    return ($Value|ConvertTo-Json -Depth 10|ConvertFrom-Json)
}
function Disable-NorthstarMod($Enabled,[string]$Name,[string]$Profile) {
    $value=$false
    if($Enabled.Version-eq1){
        $versions=@{}
        $existing=$Enabled.PSObject.Properties[$Name]
        if($existing-and$existing.Value-isnot[bool]){
            foreach($p in $existing.Value.PSObject.Properties){$versions[$p.Name]=$false}
        }
        $manifest=Join-Path $Profile "mods/$Name/mod.json"
        if(Test-Path -LiteralPath $manifest){
            $version=(Get-Content -Raw -LiteralPath $manifest|ConvertFrom-Json).Version
            if($version){$versions[[string]$version]=$false}
        }
        $value=[pscustomobject]$versions
    }
    $Enabled|Add-Member -NotePropertyName $Name -NotePropertyValue $value -Force
}
