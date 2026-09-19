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
    # Publish the final name only after every source file has been archived.
    # Compress-Archive may emit a nonterminating error and omit a locked EXE.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $temporaryZip = Join-Path $ProjectRoot ("artifacts/" + $name + "." + [Guid]::NewGuid().ToString('N') + ".building.zip")
    try {
        $files = @(Get-ChildItem -LiteralPath $destination -File -Recurse)
        $archive = [IO.Compression.ZipFile]::Open($temporaryZip, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in $files) {
                $relative = $file.FullName.Substring($destination.Length + 1).Replace('\', '/')
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, "$name/$relative", [IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        } finally { $archive.Dispose() }
        $archive = [IO.Compression.ZipFile]::OpenRead($temporaryZip)
        try {
            $entries = @($archive.Entries | Where-Object { $_.Name })
            if ($entries.Count -ne $files.Count) { throw 'Archive file count mismatch.' }
            foreach ($file in $files) {
                $relative = $file.FullName.Substring($destination.Length + 1).Replace('\', '/')
                $entry = $archive.GetEntry("$name/$relative")
                if (-not $entry -or $entry.Length -ne $file.Length) { throw "Missing or truncated archive entry: $relative" }
            }
        } finally { $archive.Dispose() }
        # Move without overwrite also protects against another simultaneous build.
        [IO.File]::Move($temporaryZip, $packagePath)
    } finally {
        if (Test-Path -LiteralPath $temporaryZip) { Remove-Item -LiteralPath $temporaryZip }
    }
    Write-Host "Package: $packagePath"
}
Write-Host "Build: $executable"
