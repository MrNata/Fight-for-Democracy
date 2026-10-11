"""Seed content once and copy shared runtime into the private Studio."""
from pathlib import Path
import json
import shutil
import re
from migrate_v02 import enrich, migrate_file

ROOT = Path(__file__).resolve().parents[1]

def move(name, damage, startup, active, recovery, reach, fame=0, gain=0, **extra):
    return dict(name=name, damage=damage, startup=startup, active=active,
                recovery=recovery, reach=reach, fame_cost=fame, fame_gain=gain,
                knockback=extra.pop("knockback", 210), stun=extra.pop("stun", 16),
                priority=extra.pop("priority", 1), cooldown=extra.pop("cooldown", 0),
                **extra)

def seed():
    moves = {
        "light_punch": move("Soco leve", 6, 5, 3, 12, 120, gain=4),
        "heavy_punch": move("Soco forte", 12, 11, 4, 21, 140, gain=6, priority=2),
        "light_kick": move("Chute leve", 8, 7, 4, 15, 155, gain=4),
        "heavy_kick": move("Chute forte", 15, 14, 5, 26, 180, gain=7, priority=3),
        "throw": move("Agarrão", 14, 7, 3, 26, 100, gain=4, unblockable=True),
        "counter": move("Contra-ataque", 11, 4, 4, 26, 150, gain=10, priority=4),
        "special_a": move("Onda eleitoral", 22, 14, 5, 28, 140, fame=35, priority=5, projectile=True, projectile_speed=680, cooldown=90),
        "special_b": move("Discurso relâmpago", 28, 9, 7, 35, 240, fame=50, priority=6, cooldown=120),
        "super": move("URNA: sobrecarga", 42, 20, 9, 44, 380, fame=80, priority=7, knockback=450, cooldown=180),
        "finisher": move("Fim do debate", 20, 18, 5, 42, 180, fame=50, priority=8),
    }
    factions = [dict(id="direita", name="Direita", color="#65d6a0", boss="teste_regente"),
                dict(id="esquerda", name="Esquerda", color="#ef6c82", boss="teste_guardiao"),
                dict(id="centrao", name="Centrão", color="#ecc96c", boss="teste_regente"),
                dict(id="independente", name="Independentes / especiais", color="#73b9eb", boss="teste_regente")]
    chars = []
    for faction, count in zip(factions, [40, 40, 40, 36]):
        for i in range(count):
            cid = f"{faction['id']}_{i+1:03}"
            name = f"Slot fictício {faction['name']} {i+1:02}"
            if faction["id"] == "direita" and i == 0:
                cid, name = "teste_aurora", "Aurora — lutadora de teste"
            if faction["id"] == "esquerda" and i == 0:
                cid, name = "teste_torquato", "Torquato — lutador de teste"
            if faction["id"] == "independente" and i < 2:
                cid, name = [("teste_regente", "Regente URNA-X — chefe temporário"),
                             ("teste_guardiao", "Guardião — chefe temporário")][i]
            chars.append(dict(id=cid, name=name, faction=faction["id"], fictional=True,
                placeholder=True, description="Personagem fictício com arte temporária. Não representa uma pessoa real.",
                combat_class=["equilibrado", "ágil", "pesado"][i % 3],
                stats=dict(health=100, strength=1.0, speed=340, mobility=1.0, defense=0.0),
                palette=dict(clothes=faction["color"], skin=["#b97d5f", "#e1b490", "#775442"][i%3], accent="#f4e3af"),
                appearance=i % 4, sprite="", animation=dict(columns=1, rows=1, fps=8),
                moves=json.loads(json.dumps(moves)), voices={}, ai=dict(reaction=24, aggression=0.5),
                campaign_enabled=True, boss=cid in ["teste_regente", "teste_guardiao"]))
    ranks = [dict(name=n, fights=c, difficulty=i, reward=100+i*40) for i,(n,c) in enumerate(zip(
        ["Vereador", "Prefeito", "Deputado Estadual", "Deputado Federal", "Senador", "Governador", "Presidente"], [7,10,17,18,19,20,22]))]
    arenas = [dict(id="praca", name="Praça da República da Arena", region="Brasília", sky="#121d33", floor="#293a4e", accent="#65d6a0", background="", music="", placeholder=True),
              dict(id="laboratorio", name="Laboratório URNA-X", region="Brasília", sky="#211830", floor="#3b304a", accent="#ae8ee6", background="", music="", placeholder=True)]
    return enrich(dict(schema_version=1, title="FIGHT FOR DEMOCRACY", factions=factions, characters=chars,
        arenas=arenas, campaign=dict(seed=2026, ranks=ranks, routes={}, narrative_invincible_route="esquerda"),
        economy=dict(win_reward=100, loss_reward=20, upgrades=[
            dict(id="health", name="Vida máxima", price=120, max_level=5, effect=0.05),
            dict(id="strength", name="Força", price=160, max_level=5, effect=0.04),
            dict(id="speed", name="Velocidade", price=120, max_level=4, effect=0.03),
            dict(id="defense", name="Defesa", price=180, max_level=4, effect=0.03),
            dict(id="fame", name="Ganho de fama", price=140, max_level=4, effect=0.05),
            dict(id="special_cost", name="Eficiência dos especiais", price=180, max_level=4, effect=0.04)]),
        story=dict(intro="PARÓDIA FICTÍCIA • A URNA-X transformou os debates da República da Arena em combates. Personagens e artes desta versão são temporários.",
            victory="O debate terminou. A arena escolheu seu vencedor.",
            defeat="Uma derrota não encerra uma carreira. Tente novamente.",
            left_ending="Desfecho roteirizado: o Guardião é invencível nesta rota. A resistência abre uma nova história; esta luta não pode ser vencida."),
        menu=dict(subtitle="REPÚBLICA DA ARENA", accent="#65d6a0", credits="Fundação jogável • Arte e som temporários • Ficção satírica"),
        audio=dict(Music=0.6, Effects=0.7, Voices=0.8, Crowd=0.4, Ambience=0.4, UI=0.6)))

def main():
    content = ROOT / "content" / "project.json"
    content.parent.mkdir(exist_ok=True)
    (content.parent / "assets").mkdir(exist_ok=True)
    if not content.exists():
        content.write_text(json.dumps(seed(), ensure_ascii=False, indent=2), encoding="utf-8")
    migrate_file(content)
    authored = json.loads(content.read_text(encoding="utf-8"))
    if "project_version" not in authored:
        backup = content.parent / "backups/pre-v03"
        backup.mkdir(parents=True, exist_ok=True)
        if not (backup / "project.json").exists():
            shutil.copy2(content, backup / "project.json")
            shutil.copytree(content.parent / "assets", backup / "assets", dirs_exist_ok=True)
        authored["project_version"] = "0.3.0"
        authored.setdefault("release_notes", "Developer Studio: interface, biblioteca, controles e publicação.")
        temporary = content.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(authored, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(content)
    (ROOT / "player" / "data").mkdir(parents=True, exist_ok=True)
    shutil.copy2(content, ROOT / "player" / "data" / "default.json")
    fixture = ROOT / "player" / "tests" / "fixtures" / "project.json"
    fixture.parent.mkdir(parents=True, exist_ok=True)
    fixture.write_text(json.dumps(seed(), ensure_ascii=False, indent=2), encoding="utf-8")
    shutil.copytree(ROOT / "player" / "runtime", ROOT / "studio" / "runtime", dirs_exist_ok=True)
    for project, directories in [("player", ["runtime", "ui", "scenes"]), ("studio", ["runtime", "editor", "scenes"])]:
        files = sorted("res://" + file.relative_to(ROOT / project).as_posix()
                       for directory in directories for file in (ROOT / project / directory).glob("*")
                       if file.suffix in (".gd", ".tscn"))
        preset = ROOT / project / "export_presets.cfg"
        text = preset.read_text(encoding="utf-8")
        text = re.sub(r"export_files=PackedStringArray\([^\n]*\)", "export_files=PackedStringArray(" + ", ".join(json.dumps(f) for f in files) + ")", text)
        preset.write_text(text, encoding="utf-8")
    print("Content prepared; shared runtime synchronized.")

if __name__ == "__main__":
    main()
