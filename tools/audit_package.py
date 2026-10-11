"""Inspect the actual unencrypted Godot PCK directory, including file hashes.
Format reference: godotengine/godot 4.7.2-stable core/io/file_access_pack.cpp.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]

def read_pack(path):
    raw = path.read_bytes()
    magic, version, major, minor, patch, flags = struct.unpack_from("<6I", raw)
    if magic != 0x43504447 or version not in (2, 3, 4) or flags & 1:
        raise ValueError("Unsupported or encrypted PCK header")
    file_base = struct.unpack_from("<Q", raw, 24)[0]
    cursor = struct.unpack_from("<Q", raw, 32)[0] if version >= 3 else 96
    count = struct.unpack_from("<I", raw, cursor)[0]
    cursor += 4
    files = {}
    for _ in range(count):
        length = struct.unpack_from("<I", raw, cursor)[0]
        cursor += 4
        name = raw[cursor:cursor+length].rstrip(b"\0").decode("utf-8").removeprefix("res://")
        cursor += length
        offset, size = struct.unpack_from("<QQ", raw, cursor)
        digest = raw[cursor+16:cursor+32]
        file_flags = struct.unpack_from("<I", raw, cursor+32)[0]
        cursor += 36
        assert not file_flags & 1, "Encrypted file cannot be audited: " + name
        body = raw[file_base+offset:file_base+offset+size]
        assert len(body) == size and hashlib.md5(body).digest() == digest, "PCK integrity failed: " + name
        files[name] = body
    return files

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, default=ROOT)
    workspace = parser.parse_args().workspace.resolve()
    folder = workspace / "dist" / "player"
    pointer = folder / "current.json"
    if pointer.exists():
        folder = Path(json.loads(pointer.read_text(encoding="utf-8"))["executable"]).parent
    exe = folder / "FightForDemocracy.exe"
    assert exe.exists() and exe.stat().st_size > 1000000, "Executable not generated"
    files = read_pack(folder / "FightForDemocracy.pck")
    forbidden = ("studio", "editor/", "export_manager", "tests/", "AGENTS", "backups/", ".bak", ".tmp")
    problems = [name for name in files if any(token.lower() in name.lower() for token in forbidden)]
    assert not problems, "Administrative files leaked: " + str(problems)
    assert "data/default.json" in files and ("scenes/main.tscn" in files or "scenes/main.tscn.remap" in files), "Missing player resources"
    for script in ("content_store", "campaign_system", "fighter", "combat_match", "audio_system", "save_system"):
        assert "runtime/" + script + ".gd" in files or "runtime/" + script + ".gdc" in files, "Runtime script missing: " + script
    content = json.loads(files["data/default.json"])
    source = json.loads((workspace / "content" / "project.json").read_text(encoding="utf-8"))
    source.pop("library", None)
    source.pop("resource_placements", None)
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    for omitted in manifest.get("omitted_resources", []):
        target, field = omitted["target"], omitted["field"]
        assert field in ("sprite", "background", "music", "effects", "crowd"), "Invalid omission"
        record = source.get(target) if target in ("menu", "resource_audio") else next(
            entry for entry in source["characters"] + source["arenas"] if entry["id"] == target)
        if field == "crowd":
            assert any(layer["file"] == omitted["file"] for layer in record[field]), "Omitted layer differs from authoring"
            record[field] = [layer for layer in record[field] if layer["file"] != omitted["file"]]
        else:
            assert record[field] == omitted["file"], "Omitted asset differs from authoring"
            record[field] = ""
    assert content == source, "Authoring content differs from Player package"
    for asset in manifest["assets"]:
        path = "data/" + asset
        assert path in files or path + ".remap" in files or path + ".import" in files, "Missing referenced asset: " + asset
    report = dict(edition="Player", file_count=len(files),
                  administrative_files=problems, integrity="all MD5 hashes verified",
                  omitted_resources=manifest.get("omitted_resources", []),
                  executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                  packaged_files=sorted(files))
    (folder / "audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"PACKAGE AUDIT: {len(files)} files verified; no Studio or test files in Player.")

if __name__ == "__main__":
    main()
