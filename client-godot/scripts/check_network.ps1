param([string]$Godot, [Parameter(Mandatory=$true)][string]$Python)
. (Join-Path $PSScriptRoot 'common.ps1')
$engine = Resolve-Godot $Godot
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_reliable_outbox.gd') 'reliable-outbox'
& $Python (Join-Path $ProjectRoot 'tests/run_websocket_tests.py') --godot $engine
if ($LASTEXITCODE -ne 0) { throw 'WebSocket tests failed.' }
