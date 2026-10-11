param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
if (-not $Godot) { $Godot = Join-Path $taskRoot 'tools\godot\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot ausente. Execute python tools/bootstrap.py ou passe -Godot caminho.exe.' }
Push-Location $taskRoot
try {
    python tools/prepare.py
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar conteúdo.' }
    python tools/test_migration.py
    if ($LASTEXITCODE -ne 0) { throw 'Testes de migração falharam.' }
    foreach ($project in @('player','studio')) {
        $log = & $Godot --headless --path $project --editor --import 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $log -match 'SCRIPT ERROR|ERROR:') { throw $log }
    }
    $runtime = & $Godot --headless --path player --script res://tests/run_tests.gd 2>&1 | Out-String
    Write-Output $runtime
    if ($LASTEXITCODE -ne 0 -or $runtime -match 'SCRIPT ERROR|ERROR:|FAIL:') { throw 'Testes de runtime falharam.' }
    $flow = & $Godot --headless --path player --script res://tests/run_ui_tests.gd -- --content=res://tests/fixtures/project.json 2>&1 | Out-String
    Write-Output $flow
    if ($LASTEXITCODE -ne 0 -or $flow -match 'SCRIPT ERROR|ERROR:|FAIL:') { throw 'Testes do fluxo Player falharam.' }
    $studio = & $Godot --headless --path studio --script res://tests/run_studio_tests.gd -- --no-preferences 2>&1 | Out-String
    Write-Output $studio
    if ($LASTEXITCODE -ne 0 -or $studio -match 'SCRIPT ERROR|ERROR:|FAIL:') { throw 'Testes do Studio falharam.' }
    $ux = & $Godot --headless --path studio --script res://tests/run_ux_tests.gd -- --no-preferences 2>&1 | Out-String
    Write-Output $ux
    if ($LASTEXITCODE -ne 0 -or $ux -match 'SCRIPT ERROR|ERROR:|FAIL:') { throw 'Testes de UX falharam.' }
    $controls = & $Godot --headless --path player --script res://tests/run_controls_ui_tests.gd -- --content=res://tests/fixtures/project.json --controls-file=user://test-controls-defaults.json 2>&1 | Out-String
    Write-Output $controls
    if ($LASTEXITCODE -ne 0 -or $controls -match 'SCRIPT ERROR|ERROR:|FAIL:') { throw 'Testes de controles Player falharam.' }
    foreach ($mode in @('ai','local','training','simulation')) {
        $log = & $Godot --headless --path player --quit-after 120 -- --test-fight "--mode=$mode" 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $log -match 'SCRIPT ERROR|ERROR:') { throw $log }
    }
    Write-Output 'Projetos importados, testes aprovados e quatro modos abertos sem erro.'
} finally { Pop-Location }
