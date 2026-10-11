@echo off
cd /d "%~dp0"
if exist "dist\studio\current.cmd" (
    call "dist\studio\current.cmd"
) else if exist "dist\studio\DeveloperStudio.exe" (
    start "" "dist\studio\DeveloperStudio.exe" -- --workspace="%~dp0."
) else (
    start "" "tools\godot\Godot_v4.7.2-stable_win64.exe" --path "studio"
)
