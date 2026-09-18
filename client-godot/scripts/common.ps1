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
    # PowerShell 5 treats native stderr as ErrorRecord, even for ordinary output.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $Executable @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
    $text | Set-Content -LiteralPath (Join-Path $logDirectory "$LogName.log") -Encoding UTF8
    if ($exitCode -ne 0 -or $text -match '(?m)(SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:)') {
        throw "Godot $LogName failed (exit $exitCode).`n$text"
    }
    Write-Host "$LogName passed"
}
