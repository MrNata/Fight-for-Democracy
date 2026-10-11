"""Verify the migration against a separate workspace fixture, never official saves."""
from pathlib import Path
from tempfile import TemporaryDirectory
from copy import deepcopy
import json
from migrate_v02 import enrich, migrate_file
from prepare import seed

root = Path(__file__).resolve().parents[1]
build = root / "build"
build.mkdir(exist_ok=True)
checks = 0

def check(condition, description):
    global checks
    if not condition:
        raise AssertionError(description)
    checks += 1

old = seed()
old.pop("content_revision")
old.pop("migration_v02_complete")
for character in old["characters"]:
    character.pop("collision")
    for move in character["moves"].values():
        for field in ["hitbox", "cancel", "air_allowed"]:
            move.pop(field)
old["characters"][0]["stats"]["health"] = 177
old["characters"][0]["moves"]["light_punch"]["damage"] = 21
old["characters"][0]["custom_metadata"] = {"preserve": True}
old["campaign"]["routes"] = {"custom_test": ["opaque authoring metadata"]}
snapshot = deepcopy(old)
upgraded = enrich(old)
check(old == snapshot, "Migration mutated its input")
check(upgraded["characters"][0]["stats"]["health"] == 177, "User stats lost")
check(upgraded["characters"][0]["moves"]["light_punch"]["damage"] == 21, "Authored move lost")
check(upgraded["characters"][0]["custom_metadata"] == {"preserve": True}, "Unknown fields lost")
check([c["id"] for c in old["characters"]] == [c["id"] for c in upgraded["characters"]], "IDs changed")
check(upgraded["campaign"]["routes"] == old["campaign"]["routes"], "Authored order changed")
check(enrich(upgraded) == upgraded, "Migration is not idempotent")
with TemporaryDirectory(prefix="migration_", dir=build) as directory:
    task_path = Path(directory).resolve()
    check(task_path.is_relative_to(build.resolve()), "Test directory escaped the workspace")
    source = task_path / "project.json"
    assets = task_path / "assets"
    assets.mkdir()
    (assets / "authored.txt").write_text("user asset", encoding="utf-8")
    source.write_text(json.dumps(old, ensure_ascii=False), encoding="utf-8")
    original_bytes = source.read_bytes()
    migrate_file(source)
    backup = task_path / "backups" / "pre-v02.json"
    check(backup.read_bytes() == original_bytes, "Migration backup differs from the original file")
    check((backup.parent / "assets" / "authored.txt").read_text(encoding="utf-8") == "user asset", "Backup omitted assets")
    first = source.read_bytes()
    migrate_file(source)
    check(source.read_bytes() == first and backup.read_bytes() == original_bytes, "Second preparation overwrote data or backup")
print(f"MIGRATION TESTS: {checks} passed, 0 failed")
