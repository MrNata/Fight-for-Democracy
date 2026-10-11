"""Run the shipped binaries from an isolated directory, with bounded execution."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]

def run(exe, folder, name, args=()):
    log = folder / (name + ".log")
    result = subprocess.run([str(exe), "--headless", "--quit-after", "20", "--log-file", str(log), *args],
                            cwd=folder, capture_output=True, text=True, timeout=30)
    text = log.read_text(encoding="utf-8") if log.exists() else "ERROR: missing log"
    assert result.returncode == 0 and "ERROR" not in text and "Godot Engine" in text, text
    return {"mode": name, "exit_code": result.returncode, "errors": False}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, default=ROOT)
    workspace = parser.parse_args().workspace.resolve()
    source = workspace / "dist" / "player"
    pointer = source / "current.json"
    if pointer.exists():
        source = Path(json.loads(pointer.read_text(encoding="utf-8"))["executable"]).parent
    isolated = ROOT / "build" / ("clean-player-" + str(time.time_ns()))
    isolated.mkdir(parents=True)
    for name in ("FightForDemocracy.exe", "FightForDemocracy.pck", "GODOT-COPYRIGHT.txt", "GODOT-LICENSE.txt", "LEIA-ME.txt"):
        shutil.copy2(source / name, isolated / name)
    exe = isolated / "FightForDemocracy.exe"
    outcomes = [run(exe, isolated, "menu"), run(exe, isolated, "battle", ["--", "--test-fight", "--mode=ai"])]
    studio = workspace / "dist" / "studio" / "DeveloperStudio.exe"
    studio_pointer = studio.parent / "current.json"
    if studio_pointer.exists():
        studio = Path(json.loads(studio_pointer.read_text(encoding="utf-8"))["executable"])
    if studio.exists():
        outcomes.append(run(studio, studio.parent, "studio", ["--", "--workspace=" + str(workspace), "--no-preferences"]))
    report = {"machine": "current development Windows PC", "isolated_directory": str(isolated),
              "player_files": [p.name for p in isolated.iterdir() if p.suffix != ".log"], "checks": outcomes,
              "limitations": "Isolated folder on the same PC; not a fresh Windows installation or different hardware."}
    (source / "clean-smoke.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("DISTRIBUTION SMOKE: isolated Player menu/battle" + (" and exported Studio" if studio.exists() else "") + " opened without errors.")

if __name__ == "__main__":
    main()
