"""Exercise real versioned exports with independent content and a running previous binary."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    workspace = ROOT / "build" / ("export-ux-" + str(time.time_ns()))
    workspace.mkdir(parents=True)
    shutil.copytree(ROOT / "player", workspace / "player", ignore=shutil.ignore_patterns(".godot", "tests", "data"))
    (workspace / "content").mkdir()
    fixture = json.loads((ROOT / "player/tests/fixtures/project.json").read_text(encoding="utf-8"))
    fixture["project_version"] = "0.3.0"
    fixture["release_notes"] = "Primeiro pacote do teste isolado."
    (workspace / "content/project.json").write_text(json.dumps(fixture, ensure_ascii=False), encoding="utf-8")
    templates = workspace / "tools/godot/templates"
    templates.mkdir(parents=True)
    for name in ("windows_release_x86_64.exe", "windows_debug_x86_64.exe"):
        os.link(ROOT / "tools/godot/templates" / name, templates / name)
    (workspace / "docs").mkdir()
    for name in ("GODOT-COPYRIGHT.txt", "GODOT-LICENSE.txt", "DISTRIBUTION-README.txt"):
        shutil.copy2(ROOT / "docs" / name, workspace / "docs" / name)
    engine = ROOT / "tools/godot/Godot_v4.7.2-stable_win64_console.exe"
    result = subprocess.run([str(engine), "--headless", "--path", str(ROOT / "studio"),
                             "--script", "res://tests/run_export_tests.gd", "--", "--workspace=" + str(workspace)],
                            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240)
    log = result.stdout + result.stderr
    (workspace / "test.log").write_text(log, encoding="utf-8")
    print(log)
    assert result.returncode == 0 and "ERROR" not in log and "FAIL:" not in log, str(workspace)
    print("EXPORTED FIXTURE WORKSPACE: " + str(workspace))


if __name__ == "__main__":
    main()
