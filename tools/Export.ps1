param([switch]$Studio, [switch]$OmitUnlicensed)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskEngine = Join-Path $taskRoot 'tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Push-Location $taskRoot
try {
    & (Join-Path $PSScriptRoot 'Test.ps1') -Godot $taskEngine
    if ($Studio) {
        python tools/export_studio.py
        if ($LASTEXITCODE -ne 0) { throw 'Exportação Studio falhou.' }
    }
    if ($OmitUnlicensed) {
        & $taskEngine --headless --path studio --script res://tests/export_cli.gd -- --omit-unlicensed
    } else {
        & $taskEngine --headless --path studio --script res://tests/export_cli.gd
    }
    if ($LASTEXITCODE -ne 0) { throw 'Exportação Player falhou.' }
    python tools/audit_package.py
    if ($LASTEXITCODE -ne 0) { throw 'Auditoria do pacote falhou.' }
    python tools/verify_distribution.py
    if ($LASTEXITCODE -ne 0) { throw 'Verificação dos executáveis em pasta isolada falhou.' }
    Write-Output 'Exportação e auditoria concluídas: dist/player'
} finally { Pop-Location }
