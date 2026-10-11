@echo off
cd /d "%~dp0"
if exist "dist\player\current.cmd" (
    call "dist\player\current.cmd"
) else if exist "tools\godot\Godot_v4.7.2-stable_win64.exe" (
    start "" "tools\godot\Godot_v4.7.2-stable_win64.exe" --path "player"
) else if exist "dist\player\FightForDemocracy.exe" (
    start "" "dist\player\FightForDemocracy.exe"
) else (
    start "" "tools\godot\Godot_v4.7.2-stable_win64.exe" --path "player"
)
