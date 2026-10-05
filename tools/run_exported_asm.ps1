param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$AsmPath
)

$ErrorActionPreference = 'Stop'

$assemblyFile = (Resolve-Path -LiteralPath $AsmPath -ErrorAction Stop).Path
if (-not $assemblyFile.EndsWith('.asm', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Escolha um arquivo .asm exportado pelo Atelier.'
}

$toolchainRoots = @()
if ($env:ATELIER_MSYS2_ROOT) {
    $toolchainRoots += $env:ATELIER_MSYS2_ROOT
}
$toolchainRoots += @('D:\msys64', 'C:\msys64')

$nasmPath = $null
$gccPath = $null
foreach ($toolchainRoot in $toolchainRoots) {
    $candidateNasm = Join-Path $toolchainRoot 'ucrt64\bin\nasm.exe'
    $candidateGcc = Join-Path $toolchainRoot 'ucrt64\bin\gcc.exe'
    if ((Test-Path -LiteralPath $candidateNasm -PathType Leaf) -and
        (Test-Path -LiteralPath $candidateGcc -PathType Leaf)) {
        $nasmPath = $candidateNasm
        $gccPath = $candidateGcc
        break
    }
}
if (-not $nasmPath -or -not $gccPath) {
    throw 'NASM e GCC UCRT64 nao encontrados. Instale o MSYS2 ou configure ATELIER_MSYS2_ROOT.'
}

$objectFile = [System.IO.Path]::ChangeExtension($assemblyFile, '.obj')
$executableFile = [System.IO.Path]::ChangeExtension($assemblyFile, '.exe')

Write-Host "Montando $assemblyFile"
& $nasmPath -f win64 $assemblyFile -o $objectFile
if ($LASTEXITCODE -ne 0) {
    throw "NASM falhou (codigo $LASTEXITCODE)."
}

Write-Host "Ligando $executableFile"
& $gccPath $objectFile -o $executableFile
if ($LASTEXITCODE -ne 0) {
    throw "GCC falhou (codigo $LASTEXITCODE)."
}

Write-Host 'Saida do programa:'
& $executableFile
$programExitCode = $LASTEXITCODE
Write-Host ''
if ($programExitCode -ne 0) {
    throw "O programa terminou com codigo $programExitCode."
}

Write-Host "Executavel pronto: $executableFile"
