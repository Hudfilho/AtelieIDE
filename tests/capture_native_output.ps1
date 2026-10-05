param(
    [Parameter(Mandatory = $true)][string]$ExecutablePath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

# Capture raw bytes: Godot OS.execute decodes stdout using the Windows code page,
# which would turn correct UTF-8 output into mojibake on Portuguese Windows.
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $ExecutablePath
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $true
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$nativeProcess = New-Object System.Diagnostics.Process
$nativeProcess.StartInfo = $processInfo
$stdoutBytes = New-Object System.IO.MemoryStream
try {
    [void]$nativeProcess.Start()
    $copyOutput = $nativeProcess.StandardOutput.BaseStream.CopyToAsync($stdoutBytes)
    $readErrors = $nativeProcess.StandardError.ReadToEndAsync()
    if (-not $nativeProcess.WaitForExit(15000)) {
        $nativeProcess.Kill()
        $nativeProcess.WaitForExit()
        Write-Error 'Native test timed out after 15 seconds.'
        exit 124
    }
    $copyOutput.GetAwaiter().GetResult()
    $errorsText = $readErrors.GetAwaiter().GetResult()
    [System.IO.File]::WriteAllBytes($OutputPath, $stdoutBytes.ToArray())
    if ($errorsText) { [Console]::Error.Write($errorsText) }
    exit $nativeProcess.ExitCode
}
finally {
    $stdoutBytes.Dispose()
    $nativeProcess.Dispose()
}
