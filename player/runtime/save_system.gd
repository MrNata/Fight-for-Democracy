extends RefCounted
const Store = preload("res://runtime/content_store.gd")
var error: String = ""
var base_path: String = "user://profiles"

func profile_path(profile: String) -> String:
	return base_path.path_join(profile.validate_filename() + ".json")

func save(profile: String, progress: Dictionary) -> bool:
	error = ""
	if not valid(progress):
		error = "Progresso inválido; salvamento rejeitado."
		return false
	var status = Store.write_atomic(profile_path(profile), progress)
	if status != OK:
		error = "Falha ao salvar: " + error_string(status)
	return status == OK

func load_profile(profile: String) -> Dictionary:
	error = ""
	var path = profile_path(profile)
	for source in [path, path + ".bak"]:
		if not FileAccess.file_exists(source):
			continue
		var json = JSON.new()
		if json.parse(FileAccess.get_file_as_string(source)) == OK and json.data is Dictionary and valid(json.data):
			if source.ends_with(".bak"):
				error = "Backup recuperado; o arquivo principal estava inválido."
			return json.data
	if FileAccess.file_exists(path):
		error = "Salvamento e backup inválidos."
	return {}

func valid(progress: Dictionary) -> bool:
	if progress.get("schema_version") != 1 or not progress.get("schedule") is Array:
		return false
	if progress.has("schedule_rules"):
		var rules = progress.schedule_rules
		if not (rules is int or rules is float) or rules != floor(rules) or rules < 1 or rules > 2:
			return false
	if not progress.get("upgrades") is Dictionary or not progress.get("defeated") is Array:
		return false
	if not progress.get("remaining_health") is Array or not progress.get("achievements") is Array or not progress.get("completed") is bool:
		return false
	var seconds = progress.get("campaign_seconds")
	if not (seconds is float or seconds is int) or seconds < 0 or not is_finite(float(seconds)):
		return false
	for level in progress.upgrades.values():
		if not (level is int or level is float) or level < 0 or level > 10 or level != floor(level):
			return false
	for key in ["next_fight", "propina", "wins", "losses", "score", "max_combo", "seed"]:
		var value = progress.get(key)
		if not (value is float or value is int) or value < 0 or value != floor(value):
			return false
	if int(progress.next_fight) > progress.schedule.size() or not progress.get("character") is String or not progress.get("faction") is String:
		return false
	var seen: Dictionary = {}
	for fight in progress.schedule:
		if not fight is Dictionary or not fight.get("opponent") is String or fight.opponent == progress.character or seen.has(fight.opponent):
			return false
		seen[fight.opponent] = true
	return not progress.character.is_empty()

func new_career(character: String, faction: String, schedule: Array, seed_value: int) -> Dictionary:
	return {"schema_version": 1, "schedule_rules": 2, "character": character, "faction": faction, "seed": seed_value, "schedule": schedule, "next_fight": 0, "defeated": [], "wins": 0, "losses": 0, "score": 0, "propina": 0, "upgrades": {}, "remaining_health": [], "max_combo": 0, "campaign_seconds": 0.0, "achievements": [], "completed": false}
