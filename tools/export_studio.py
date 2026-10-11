"""Export Studio into a fresh directory and select it only after a successful smoke run."""
from pathlib import Path
import hashlib
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    engine = ROOT / "tools/godot/Godot_v4.7.2-stable_win64_console.exe"
    version = "0.3.0"
    build_id = f"studio-{version}-{time.time_ns()}"
    folder = ROOT / "dist/studio/versions" / build_id
    folder.mkdir(parents=True)
    exe = folder / "DeveloperStudio.exe"
    result = subprocess.run([str(engine), "--headless", "--path", str(ROOT / "studio"),
                             "--export-release", "Windows Studio", str(exe)],
                            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    log = result.stdout + result.stderr
    (folder / "export.log").write_text(log, encoding="utf-8")
    assert result.returncode == 0 and "ERROR" not in log and exe.exists() and exe.with_suffix(".pck").exists(), log
    smoke = subprocess.run([str(exe), "--headless", "--quit-after", "20", "--", "--workspace=" + str(ROOT),
                            "--no-preferences"], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
    (folder / "smoke.log").write_text(smoke.stdout + smoke.stderr, encoding="utf-8")
    assert smoke.returncode == 0 and "ERROR" not in smoke.stdout + smoke.stderr, smoke.stdout + smoke.stderr
    record = dict(version=version, build_id=build_id, executable=str(exe), verified=True,
                  executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
    pointer = ROOT / "dist/studio/current.json"
    temporary = pointer.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(record, indent=2), encoding="utf-8")
    temporary.replace(pointer)
    launcher = ROOT / "dist/studio/current.cmd"
    temporary = launcher.with_suffix(".cmd.tmp")
    temporary.write_text('@echo off\nstart "" "%~dp0versions\\' + build_id + '\\DeveloperStudio.exe" -- --workspace="%~dp0..\\.."\n', encoding="utf-8")
    temporary.replace(launcher)
    print("STUDIO EXPORT VERIFIED: " + str(exe))


if __name__ == "__main__":
    main()
