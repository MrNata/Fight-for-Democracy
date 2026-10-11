"""Fetch official Godot binaries into this workspace; no global installation."""
from pathlib import Path
import hashlib
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2-stable"
DEST = ROOT / "tools" / "godot"

def fetch(asset):
    target = DEST / asset["name"]
    if not target.exists():
        print("Downloading", asset["name"], flush=True)
        urllib.request.urlretrieve(asset["browser_download_url"], target)
    digest = asset.get("digest", "")
    if digest.startswith("sha256:"):
        actual = hashlib.file_digest(target.open("rb"), "sha256").hexdigest()
        if actual != digest.split(":", 1)[1]:
            raise RuntimeError("Official SHA256 mismatch: " + str(target))
    return target

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    url = f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{VERSION}"
    release = json.load(urllib.request.urlopen(url))
    assets = {a["name"]: a for a in release["assets"]}
    editor = fetch(assets[f"Godot_v{VERSION}_win64.exe.zip"])
    with zipfile.ZipFile(editor) as z:
        z.extractall(DEST)
    print("Editor ready", flush=True)
    templates = fetch(assets[f"Godot_v{VERSION}_export_templates.tpz"])
    out = DEST / "templates"
    out.mkdir(exist_ok=True)
    with zipfile.ZipFile(templates) as z:
        for filename in ["windows_release_x86_64.exe", "windows_debug_x86_64.exe"]:
            member = next(n for n in z.namelist() if n.endswith("/" + filename))
            (out / filename).write_bytes(z.read(member))
    (DEST / "release.json").write_text(json.dumps({"version": VERSION,
        "source": release["html_url"], "assets": [{"name": a["name"], "digest": a.get("digest", "")} for a in assets.values() if a["name"] in [editor.name, templates.name]]}, indent=2), encoding="utf-8")
    print("Windows export templates ready", flush=True)

if __name__ == "__main__":
    main()
