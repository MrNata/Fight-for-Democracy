"""Additive v0.2 migration. IDs, factions, authored moves and unknown fields survive."""
from copy import deepcopy
import json
import shutil
from pathlib import Path

CANCELS = {
    "light_punch": ["heavy_punch", "light_kick", "special_a", "special_b"],
    "light_kick": ["heavy_kick", "special_a", "special_b"],
    "heavy_punch": ["special_a", "special_b"],
    "heavy_kick": ["special_a", "special_b"],
    "special_a": ["super"], "special_b": ["super"],
}

def enrich(data):
    result = deepcopy(data)
    if result.get("content_revision", 1) >= 2 and result.get("migration_v02_complete", False):
        return result
    for character in result["characters"]:
        character.setdefault("collision", dict(width=84, height=204, crouch_height=112, push_width=85))
        for key, move in character["moves"].items():
            move.setdefault("hitbox", dict(offset_x=25, offset_y=110 if "kick" in key else 175, height=65))
            move.setdefault("cancel", dict(into=CANCELS.get(key, []), start=0, end=8, require_hit=True))
            move.setdefault("air_allowed", key in ["light_punch", "heavy_punch", "light_kick", "heavy_kick"])
        if character["id"] in ["teste_regente", "teste_guardiao"] and character.get("placeholder"):
            character.setdefault("legacy_identity", dict(name=character["name"], description=character["description"]))
            character["name"] = "Lula — caricatura fictícia" if character["id"] == "teste_regente" else "Enéas Carneiro — caricatura fictícia"
            character["description"] = "Personagem de uma realidade alternativa satírica. Arte e golpes de base temporários; não é uma biografia nem uma representação factual."
            character["portrait_style"] = "white_beard" if character["id"] == "teste_regente" else "glasses_beard"
    result["campaign"].setdefault("narrative_boss_id", "teste_guardiao")
    if not any(arena["id"] == "trono_urna_x" for arena in result["arenas"]):
        result["arenas"].append(dict(id="trono_urna_x", name="Trono da URNA-X", region="Salvador, Bahia — representação fantástica",
            sky="#26192f", floor="#543943", accent="#f0c36d", background="", music="", placeholder=True, boss_only=True))
    for faction in result["factions"]:
        faction.setdefault("boss_arena", "laboratorio" if faction["id"] == "esquerda" else "trono_urna_x")
    result["story"]["left_ending"] = "PARADOXO DA URNA-X: Enéas é invencível somente neste confronto final da história da Esquerda. Sobreviva ao encerramento inevitável. No Versus, ele pode ser derrotado normalmente."
    result["content_revision"] = 2
    result["migration_v02_complete"] = True
    return result

def migrate_file(path: Path):
    original = json.loads(path.read_text(encoding="utf-8"))
    updated = enrich(original)
    if updated == original:
        return
    # Never replace the preserved first version with a later export or autosave.
    backup = path.parent / "backups" / "pre-v02.json"
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        backup.write_bytes(path.read_bytes())
        if (path.parent / "assets").exists():
            shutil.copytree(path.parent / "assets", backup.parent / "assets", dirs_exist_ok=True)
    temporary = path.with_suffix(".migration.tmp")
    temporary.write_text(json.dumps(updated, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)
    print("v0.2 additive content migration; original preserved:", backup)
