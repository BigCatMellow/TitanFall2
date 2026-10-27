$ErrorActionPreference='Stop'
$repo="$env:USERPROFILE\bp-ort-fork"
$env:PATH="$env:USERPROFILE\Downloads\llvm-mingw-20261020-ucrt-x86_64\llvm-mingw-20261020-ucrt-x86_64\bin;"+$env:PATH
Push-Location $repo
try {
    foreach ($name in @('navigation_buffers','jump_pulse','progress_watchdog','behavior_tuning','coordination')) {
        $exe=Join-Path $repo "target\$name-tests.exe"
        & "$env:USERPROFILE\.cargo\bin\rustc.exe" +nightly-2025-09-11-x86_64-pc-windows-gnu --edition 2024 --test "tests\$name.rs" -o $exe
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $name" }
        & $exe
        if ($LASTEXITCODE -ne 0) { throw "Tests failed: $name" }
    }
    git -C $repo diff --check
    if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
} finally { Pop-Location }
