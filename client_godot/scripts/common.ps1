Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Resolve-Godot([string]$Path) {
    if (-not $Path) { $Path = $env:GODOT_BIN }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'Supply -Godot <Godot 4.7.1 executable> or set GODOT_BIN.'
    }
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $version = (& $resolved --version 2>&1 | Out-String).Trim()
    $lock = Get-Content -LiteralPath (Join-Path $ProjectRoot 'dependencies.lock.json') -Raw | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $version -ne $lock.engine.version_output) {
        throw "Expected $($lock.engine.version_output); got: $version"
    }
    return $resolved
}

function Invoke-GodotChecked([string]$Executable, [string[]]$Arguments, [string]$LogName) {
    $logDirectory = Join-Path $ProjectRoot 'artifacts'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    # A GUI-subsystem export does not expose stdout like the editor console.
    # Wait for the actual child process and inspect Godot's own log as well.
    $engineLog = Join-Path $logDirectory "$LogName.engine.log"
    $stdoutLog = Join-Path $logDirectory "$LogName.stdout.log"
    $stderrLog = Join-Path $logDirectory "$LogName.stderr.log"
    '' | Set-Content -LiteralPath $engineLog -Encoding UTF8
    $quoted = @($Arguments + @('--log-file', $engineLog) | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Executable
    $startInfo.Arguments = $quoted -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = 'Hidden'
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.Start() | Out-Null
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill()
        throw "Godot $LogName timed out after 120 seconds."
    }
    $exitCode = $process.ExitCode
    $stdout.Result | Set-Content -LiteralPath $stdoutLog -Encoding UTF8
    $stderr.Result | Set-Content -LiteralPath $stderrLog -Encoding UTF8
    $process.Dispose()
    $text = @($engineLog, $stdoutLog, $stderrLog | ForEach-Object {
        if (Test-Path -LiteralPath $_) { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 }
    }) -join "`n"
    $text | Set-Content -LiteralPath (Join-Path $logDirectory "$LogName.log") -Encoding UTF8
    if ($exitCode -ne 0 -or $text -match '(?m)(SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:)') {
        throw "Godot $LogName failed (exit $exitCode).`n$text"
    }
    Write-Host "$LogName passed"
}
