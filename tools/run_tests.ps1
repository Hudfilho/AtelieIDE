param(
    [string]$GodotPath,
    [switch]$Native,
    [string]$RitualPath
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) { $GodotPath = $godotCommand.Source }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Informe -GodotPath com o caminho do executavel console do Godot.'
}
if ($RitualPath -and -not $Native) {
    throw '-RitualPath exige -Native para comparar o ritual com um executavel real.'
}
if ($Native) {
    foreach ($toolchainRoot in @($env:ATELIER_MSYS2_ROOT, 'D:\msys64', 'C:\msys64')) {
        if (-not $toolchainRoot) { continue }
        $candidateNasm = Join-Path $toolchainRoot 'ucrt64\bin\nasm.exe'
        $candidateGcc = Join-Path $toolchainRoot 'ucrt64\bin\gcc.exe'
        if ((Test-Path -LiteralPath $candidateNasm) -and (Test-Path -LiteralPath $candidateGcc)) {
            if (-not $env:ATELIER_NASM_PATH) { $env:ATELIER_NASM_PATH = $candidateNasm }
            if (-not $env:ATELIER_GCC_PATH) { $env:ATELIER_GCC_PATH = $candidateGcc }
            break
        }
    }
    if (-not $env:ATELIER_NASM_PATH -or -not $env:ATELIER_GCC_PATH -or
        -not (Test-Path -LiteralPath $env:ATELIER_NASM_PATH) -or
        -not (Test-Path -LiteralPath $env:ATELIER_GCC_PATH)) {
        throw 'Para -Native, configure NASM/GCC ou instale-os no MSYS2 em D:\msys64 ou C:\msys64.'
    }
}

$tests = @(Get-ChildItem -LiteralPath (Join-Path $projectPath 'tests') -Filter '*_smoke.gd' -File |
    Sort-Object Name | ForEach-Object { $_.Name })
if ($tests.Count -eq 0) { throw 'Nenhum teste *_smoke.gd encontrado.' }
if ($Native) { $tests += 'nasm_all_runes.gd' }
foreach ($test in $tests) {
    $testArguments = @('--headless', '--path', $projectPath, '--script', "res://tests/$test")
    if ($test -eq 'nasm_all_runes.gd' -and $RitualPath) {
        $testArguments += @('--', (Resolve-Path -LiteralPath $RitualPath).Path)
    }
    Write-Host "Testando $test"
    # Engine resource warnings are not assertions. SCRIPT ERROR must still fail
    # the run, even when an older smoke test accidentally exits with status 0.
    $ErrorActionPreference = 'Continue'
    $testOutput = @(& $GodotPath @testArguments 2>&1)
    $testExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    foreach ($line in $testOutput) { Write-Host $line }
    $combinedOutput = $testOutput -join "`n"
    if ($testExitCode -ne 0 -or $combinedOutput -match 'SCRIPT ERROR:|Assertion failed' -or
        $combinedOutput -notmatch '(?m)^[A-Z_]+_OK(?:\s|:|$)') {
        throw "Teste falhou: $test (codigo $testExitCode)."
    }
}
Write-Host "ATELIER_TESTS_OK: $($tests.Count) suites"
