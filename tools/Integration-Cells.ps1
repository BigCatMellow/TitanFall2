$script:IntegrationDefinition=Get-Content "$PSScriptRoot/../automation/integration-v28-cells.json" -Raw|ConvertFrom-Json
function Get-IntegrationCell([string]$Name){
    $entry=$script:IntegrationDefinition.cells.PSObject.Properties[$Name]
    if(!$entry){throw "Unknown integration cell $Name"}
    $c=[ordered]@{};foreach($p in $script:IntegrationDefinition.base.PSObject.Properties){$c[$p.Name]=$p.Value}
    foreach($p in $entry.Value.PSObject.Properties){$c[$p.Name]=$p.Value};return $c
}
function Get-IntegrationConVars {
    $c=[ordered]@{};foreach($p in $script:IntegrationDefinition.convars.PSObject.Properties){$c[$p.Name]=$p.Value};return $c
}
