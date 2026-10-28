# Child plans historically use dll_sha256; queue plans use native_sha256.
# Accept either exact SHA256, but never resolve contradictory evidence by guessing.
function Read-SurveyRuntimeHash($Plan) {
    $hashes=@(@($Plan.dll_sha256,$Plan.native_sha256)|Where-Object {$_})
    if(-not$hashes.Count){throw 'Prior plan has no native runtime hash'}
    foreach($hash in $hashes){if($hash-notmatch'^[a-fA-F0-9]{64}$'){throw 'Invalid prior native hash'}}
    if(@($hashes|ForEach-Object {$_.ToUpperInvariant()}|Select-Object -Unique).Count-ne1){throw 'Conflicting prior native hashes'}
    [string]$hashes[0]
}
