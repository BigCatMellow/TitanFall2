# Publish complete JSON with a same-directory rename. Readers never see a
# truncated destination. Retry sharing errors, never permission errors.
function Move-SurveyQueueJsonFile([string]$Source,[string]$Destination){
    [IO.File]::Move($Source,$Destination,$true)
}
function Write-SurveyQueueJson([string]$Path,$Value,[int]$Attempts=10){
    $target=[IO.Path]::GetFullPath($Path)
    $temporary=$target+'.'+$PID+'.tmp'
    $json=$Value|ConvertTo-Json -Depth 16
    for($attempt=0;$attempt-lt$Attempts;$attempt++){
        try{
            [IO.File]::WriteAllText($temporary,$json,[Text.UTF8Encoding]::new($false))
            Move-SurveyQueueJsonFile $temporary $target
            return
        }catch{
            $cause=$_.Exception;while($cause.InnerException){$cause=$cause.InnerException}
            if($attempt-ge$Attempts-1-or$cause-isnot[IO.IOException]){throw}
            Start-Sleep -Milliseconds 100
        }
    }
}
