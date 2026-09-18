param([string]$Godot)
. (Join-Path $PSScriptRoot 'common.ps1')
$engine = Resolve-Godot $Godot
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--editor', '--import') 'import'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--quit-after', '3') 'startup'
