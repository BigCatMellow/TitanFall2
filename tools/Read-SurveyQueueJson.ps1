# Child status publication may briefly remove the old name during replacement.
# Retry transient sharing/missing/partial-JSON reads; never mask a persistent failure.
function Open-SurveyQueueStream([string]$Path) {
    [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite-bor[IO.FileShare]::Delete))
}
function Read-SurveyQueueJson([string]$Path,[int]$Attempts=10) {
    for($attempt=0;$attempt-lt$Attempts;$attempt++){
        $reader=$null
        try{
            $stream=Open-SurveyQueueStream $Path
            $reader=[IO.StreamReader]::new($stream)
            return ($reader.ReadToEnd()|ConvertFrom-Json -ErrorAction Stop)
        }catch{
            $cause=$_.Exception
            while($cause.InnerException){$cause=$cause.InnerException}
            $transient=$cause-is[IO.IOException]-or$_.FullyQualifiedErrorId-match'ConvertFromJson|InvalidJson'
            if($attempt-ge$Attempts-1-or-not$transient){throw}
            Start-Sleep -Milliseconds 100
        }finally{if($reader){$reader.Dispose()}}
    }
}
