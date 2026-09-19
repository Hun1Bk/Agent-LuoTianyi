param([string]$Godot, [string]$OutputDirectory, [switch]$Package)
. (Join-Path $PSScriptRoot 'common.ps1')
$engine = Resolve-Godot $Godot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $ProjectRoot 'dist' }
$release = Get-Content -LiteralPath (Join-Path $ProjectRoot 'release.json') -Raw | ConvertFrom-Json
if ($release.product -cne 'agentluo' -or $release.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release metadata.' }
$name = "agentluo-$($release.version)"
$packagePath = Join-Path $ProjectRoot "artifacts/$name.zip"
if ($Package -and (Test-Path -LiteralPath $packagePath)) { throw "Delivery already exists: $packagePath" }
$destination = [IO.Path]::GetFullPath((Join-Path $OutputDirectory $name))
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$executable = Join-Path $destination 'agentluo.exe'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--editor', '--import') 'import'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--export-release', 'Windows Desktop', $executable) 'export'
if (-not (Test-Path -LiteralPath $executable) -or -not (Test-Path -LiteralPath (Join-Path $destination 'agentluo.pck'))) {
    throw 'Export did not produce agentluo.exe and agentluo.pck.'
}
Invoke-GodotChecked $executable @('--headless', '--quit-after', '3') 'export-startup'
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'licenses') -Destination $destination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'PREVIEW.md') -Destination $destination -Force
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'release.json') -Destination $destination -Force
if ($Package) {
    Compress-Archive -LiteralPath $destination -DestinationPath $packagePath
    Write-Host "Package: $packagePath"
}
Write-Host "Build: $executable"
