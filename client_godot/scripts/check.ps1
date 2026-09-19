param([string]$Godot)
. (Join-Path $PSScriptRoot 'common.ps1')
$engine = Resolve-Godot $Godot
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--editor', '--import') 'import'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--quit-after', '3') 'startup'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_avatar_driver.gd') 'avatar-contract'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_avatar_framing.gd') 'framing-contract'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_demo_session.gd') 'preview-contract'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_preview_input.gd') 'preview-input'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_windows_security.gd') 'windows-security'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_reliable_outbox.gd') 'reliable-outbox'
Invoke-GodotChecked $engine @('--headless', '--path', $ProjectRoot, '--script', 'res://tests/test_client_log.gd') 'client-log'
