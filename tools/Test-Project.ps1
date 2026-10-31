param([string]$RepositoryRoot=(Split-Path $PSScriptRoot),[string]$Toolchain='nightly-2025-09-11-x86_64-pc-windows-gnu',[string]$LlvmBin=$env:LLVM_MINGW_BIN)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
if($LlvmBin){$env:PATH=$LlvmBin+';'+$env:PATH}
$rustc=(Get-Command rustc.exe -ErrorAction Stop).Source
New-Item -ItemType Directory -Path "$repo\target\offline-checks" -Force|Out-Null
Push-Location $repo
try{
    foreach($name in @('navigation_buffers','jump_pulse','progress_watchdog','behavior_tuning','coordination','escape_recovery','combat_decisions','action_policy','weapon_mapping','nav_diagnostics','route_guard','perception','combat_movement','crouch_recovery','height_response','skill_policy','personality','offhand_safety','frag_escape','awareness','target_policy','frag_input_probe','clearance_approach')){
        $exe=Join-Path $repo "target\offline-checks\$name.exe"
        & $rustc "+$Toolchain" --edition 2024 --test "tests\$name.rs" -o $exe
        if($LASTEXITCODE-ne0){throw "Compile failed: $name"}
        & $exe
        if($LASTEXITCODE-ne0){throw "Tests failed: $name"}
    }
    foreach($fixture in @('migrate_rename','migrate_rollback','migrate_versioned','trial_settings')){
        & "$repo\tests\$fixture.ps1"
        if(-not$?){throw "Fixture failed: $fixture"}
    }
    & git diff --check -- bp_ort shared tests tools README.md AGENTS.md NOTICE
    if($LASTEXITCODE-ne0){throw 'Source whitespace check failed'}
}finally{Pop-Location}
