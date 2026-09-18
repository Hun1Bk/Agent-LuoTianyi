param([string]$Godot, [string]$OutputDirectory)
. (Join-Path $PSScriptRoot 'common.ps1')
$engine = Resolve-Godot $Godot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $ProjectRoot 'dist' }
$destination = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$executable = Join-Path $destination 'AgentLuo.exe'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--editor', '--import') 'import'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--export-release', 'Windows Desktop', $executable) 'export'
if (-not (Test-Path -LiteralPath $executable) -or -not (Test-Path -LiteralPath (Join-Path $destination 'AgentLuo.pck'))) {
    throw 'Export did not produce AgentLuo.exe and AgentLuo.pck.'
}
Invoke-GodotChecked $executable @('--headless', '--quit-after', '3') 'export-startup'
Write-Host "Build: $executable"
