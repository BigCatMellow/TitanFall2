function Stop-OwnedSurveyGame {
    param([object]$Process,[Parameter(Mandatory)][string]$Profile)
    if(-not$Process){return}
    $Process.Refresh()
    if($Process.HasExited){return}
    $metadata=Get-CimInstance Win32_Process -Filter "ProcessId=$($Process.Id)" -ErrorAction Stop
    if(-not$metadata){
        $Process.Refresh()
        if($Process.HasExited){return}
        throw 'Cannot verify the still-running survey process'
    }
    $escaped=[regex]::Escape($Profile)
    $argument='(?:^|\s)-profile=(?:"'+$escaped+'"|'+$escaped+')(?=\s|$)'
    if($metadata.Name-ne'NorthstarLauncher.exe'-or-not$metadata.CommandLine-or-not[regex]::IsMatch($metadata.CommandLine,$argument,[Text.RegularExpressions.RegexOptions]::IgnoreCase)){return}
    try{
        # Kill through the original handle: never reopen a potentially reused PID.
        $Process.Kill()
    }catch{
        $Process.Refresh()
        if(-not$Process.HasExited){throw}
        # The game's own quit can win between the ownership check and Kill().
    }
    if(-not$Process.WaitForExit(15000)){throw 'Owned survey game did not exit within fifteen seconds'}
}
