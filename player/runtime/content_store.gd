extends RefCounted
## Versioned data boundary. All editor and runtime consumers use this validator.
const VERSION = 1
const STAT_LIMITS = {"health": [1, 10000], "strength": [0.1, 5], "speed": [50, 900], "mobility": [0.2, 3], "defense": [0, 0.65]}
const MOVE_LIMITS = {"damage": [0, 500], "startup": [1, 180], "active": [1, 120], "recovery": [1, 240], "reach": [10, 900], "fame_cost": [0, 100], "fame_gain": [0, 100], "stun": [0, 120], "knockback": [0, 1500], "priority": [0, 20], "cooldown": [0, 600]}
const Campaign = preload("res://runtime/campaign_system.gd")
const Controls = preload("res://runtime/controls_config.gd")
const ACTIONS = ["light_punch", "heavy_punch", "light_kick", "heavy_kick", "throw", "counter", "special_a", "special_b", "super", "finisher"]
var data: Dictionary = {}
var path: String = ""
var errors: PackedStringArray = []

func load_file(source: String) -> bool:
	path = source
	errors.clear()
	if not FileAccess.file_exists(source):
		errors.append("Arquivo ausente: " + source)
		return false
	var json = JSON.new()
	var status = json.parse(FileAccess.get_file_as_string(source))
	if status != OK:
		errors.append("JSON inválido na linha %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false
	if not json.data is Dictionary:
		errors.append("A raiz do conteúdo deve ser um objeto JSON.")
		return false
	var candidate: Dictionary = json.data
	errors = validate(candidate)
	if not errors.is_empty():
		return false
	data = candidate
	return true

func validate(candidate: Dictionary, check_files: bool = true) -> PackedStringArray:
	var result: PackedStringArray = []
	if candidate.get("schema_version") != VERSION:
		result.append("Versão de esquema incompatível; esperado: 1.")
	for key in ["characters", "factions", "arenas"]:
		if not candidate.get(key) is Array or candidate.get(key, []).is_empty():
			result.append("Coleção obrigatória ausente ou inválida: " + key)
	if not result.is_empty():
		return result
	if candidate.has("controls"):
		if not candidate.controls is Dictionary:
			result.append("Controles devem ser um objeto.")
		else:
			result.append_array(Controls.validate(candidate.controls))
	if not result.is_empty():
		return result
	var factions = validate_factions(candidate.factions,result)
	var ids = validate_characters(candidate.characters,factions,result,check_files)
	validate_arenas(candidate.arenas,result,check_files)
	if result.is_empty():
		validate_metadata(candidate,ids,result,check_files)
	if result.is_empty():
		validate_upgrades(candidate.economy.get("upgrades"),result)
	if result.is_empty():
		validate_careers(candidate,result)
	return result

func validate_factions(collection: Array, result: PackedStringArray) -> Dictionary:
	var factions: Dictionary = {}
	for faction in collection:
		if not faction is Dictionary or str(faction.get("id", "")).is_empty():
			result.append("Facção sem ID válido.")
			continue
		if factions.has(faction.id):
			result.append("Facção duplicada: " + str(faction.id))
		factions[faction.id] = faction
		for field in ["id","name","boss"]:
			if not faction.get(field) is String or str(faction.get(field,"")).is_empty():
				result.append("Facção: campo obrigatório inválido: "+field)
	return factions

func validate_characters(collection: Array, factions: Dictionary, result: PackedStringArray, check_files: bool) -> Dictionary:
	var ids: Dictionary = {}
	for character in collection:
		if not character is Dictionary:
			result.append("Personagem deve ser um objeto.")
			continue
		var id = str(character.get("id", ""))
		if id.is_empty() or ids.has(id):
			result.append("ID de personagem vazio ou duplicado: " + id)
		ids[id] = true
		if str(character.get("name", "")).strip_edges().is_empty():
			result.append(id + ": nome obrigatório.")
		for field in ["id","name","description"]:
			if not character.get(field) is String:
				result.append(id + ": texto inválido: "+field)
		if not factions.has(character.get("faction", "")):
			result.append(id + ": facção desconhecida.")
		if not character.get("stats") is Dictionary or not character.get("moves") is Dictionary:
			result.append(id + ": atributos ou golpes ausentes.")
			continue
		validate_character_details(character,id,result)
		validate_moves(character,id,result)
		if character.get("voices") is Dictionary:
			validate_voices(character,id,result,check_files)
	return ids

func validate_character_details(character: Dictionary, id: String, result: PackedStringArray) -> void:
	for stat in STAT_LIMITS:
		var limits: Array = STAT_LIMITS[stat]
		check_number(character.stats, stat, limits[0], limits[1], id, result)
	if not character.get("palette") is Dictionary or not character.get("animation") is Dictionary or not character.get("voices") is Dictionary:
		result.append(id + ": paleta, animação ou vozes inválidas.")
		return
	if not character.get("ai") is Dictionary:
		result.append(id + ": perfil de IA deve ser um objeto.")
	else:
		check_number(character.ai,"reaction",6,180,id,result)
		check_number(character.ai,"aggression",0,1,id,result)
	for flag in ["fictional","placeholder","campaign_enabled","boss"]:
		if not character.get(flag) is bool:
			result.append(id + ": opção inválida: " + flag)
	check_number(character.animation, "columns", 1, 64, id, result)
	check_number(character.animation, "rows", 1, 64, id, result)
	check_number(character.animation, "fps", 1, 60, id, result)
	for color in ["clothes","skin","accent"]:
		if not Color.html_is_valid(str(character.palette.get(color,""))):
			result.append(id + ": cor inválida: " + color)
	if character.has("collision"):
		if not character.collision is Dictionary:
			result.append(id + ": colisão deve ser um objeto.")
		else:
			for key in ["width","height","crouch_height","push_width"]:
				check_number(character.collision,key,20,600,id+"/colisão",result)
			if (character.collision.get("crouch_height") is int or character.collision.get("crouch_height") is float) and (character.collision.get("height") is int or character.collision.get("height") is float) and character.collision.crouch_height > character.collision.height:
				result.append(id + ": hurtbox agachada deve caber na hurtbox em pé.")

func validate_moves(character: Dictionary, id: String, result: PackedStringArray) -> void:
	for action in ACTIONS:
		if not character.moves.get(action) is Dictionary:
			result.append(id + ": golpe ausente: " + action)
			continue
		var move: Dictionary = character.moves[action]
		if not move.get("name") is String or str(move.get("name","")).is_empty():
			result.append(id + ": nome obrigatório do golpe: " + action)
		for flag in ["projectile","unblockable"]:
			if move.has(flag) and not move[flag] is bool:
				result.append(id + ": opção de golpe inválida: " + flag)
		if move.get("projectile",false):
			check_number(move,"projectile_speed",50,1500,id,result)
		if move.has("projectile_width"):
			check_number(move,"projectile_width",8,300,id,result)
		for field in MOVE_LIMITS:
			var limits: Array = MOVE_LIMITS[field]
			check_number(move, field, limits[0], limits[1], id + "/" + action, result)
		validate_move_extensions(move,character,id+"/"+action,result)

func validate_move_extensions(move: Dictionary, character: Dictionary, label: String, result: PackedStringArray) -> void:
	if move.has("air_allowed") and not move.air_allowed is bool:
		result.append(label + ": permissão aérea deve ser booleana.")
	if move.has("hitbox"):
		if not move.hitbox is Dictionary:
			result.append(label + ": hitbox deve ser um objeto.")
		else:
			check_number(move.hitbox,"offset_x",0,600,label,result)
			check_number(move.hitbox,"offset_y",0,600,label,result)
			check_number(move.hitbox,"height",1,600,label,result)
	if move.has("cancel"):
		if not move.cancel is Dictionary:
			result.append(label + ": regras de cancelamento inválidas.")
		else:
			var rules: Dictionary = move.cancel
			if not rules.get("into") is Array or not rules.get("require_hit") is bool:
				result.append(label + ": destinos e confirmação do cancelamento inválidos.")
			else:
				var seen: Array = []
				for target in rules.into:
					if not target is String or target not in ACTIONS or target in seen or not character.moves.has(target):
						result.append(label + ": destino de cancelamento inexistente ou duplicado.")
					seen.append(target)
			check_number(rules,"start",0,239,label,result)
			check_number(rules,"end",0,239,label,result)
			if (rules.get("start") is int or rules.get("start") is float) and (rules.get("end") is int or rules.get("end") is float) and (move.get("recovery") is int or move.get("recovery") is float):
				if rules.start > rules.end or rules.end >= move.recovery:
					result.append(label + ": janela de cancelamento deve caber na recuperação.")
	if move.has("animation"):
		if not move.animation is Dictionary:
			result.append(label + ": trecho de animação inválido.")
		elif character.get("animation") is Dictionary:
			check_number(move.animation,"start",0,4095,label,result)
			check_number(move.animation,"count",1,4096,label,result)
			if (move.animation.get("start") is int or move.animation.get("start") is float) and (move.animation.get("count") is int or move.animation.get("count") is float):
				var columns = character.animation.get("columns",1)
				var rows = character.animation.get("rows",1)
				if (columns is int or columns is float) and (rows is int or rows is float) and move.animation.start+move.animation.count > float(columns)*float(rows):
					result.append(label + ": trecho de animação ultrapassa o spritesheet.")

func validate_voices(character: Dictionary, id: String, result: PackedStringArray, check_files: bool) -> void:
	if check_files:
		check_asset(character.get("sprite", ""), id, result)
	for event in character.voices:
		if not character.voices[event] is Array:
			result.append(id + ": lista de vozes inválida: " + str(event))
			continue
		for clip in character.voices[event]:
			if not clip is Dictionary:
				result.append(id + ": evento de áudio inválido.")
				continue
			if check_files:
				check_asset(clip.get("file", ""), id, result)
			check_number(clip, "weight", 0.01, 100, id, result)
			check_number(clip, "volume", 0, 1, id, result)
			check_number(clip, "interval", 0, 120, id, result)
			for attribution in ["source", "license", "authorization"]:
				if not clip.get(attribution) is String or str(clip.get(attribution, "")).strip_edges().is_empty():
					result.append(id + ": registrar " + attribution + " do áudio.")

func validate_arenas(collection: Array, result: PackedStringArray, check_files: bool) -> void:
	var arena_ids: Dictionary = {}
	for arena in collection:
		if not arena is Dictionary or str(arena.get("id", "")).is_empty():
			result.append("Arena sem ID.")
			continue
		if arena_ids.has(arena.id):
			result.append("Arena duplicada: " + str(arena.id))
		arena_ids[arena.id] = true
		for color in ["sky","floor","accent"]:
			if not Color.html_is_valid(str(arena.get(color,""))):
				result.append(str(arena.id) + ": cor inválida: " + color)
		for field in ["id","name","region"]:
			if not arena.get(field) is String:
				result.append("Arena: texto inválido: " + field)
		if arena.has("crowd"):
			if not arena.crowd is Array or arena.crowd.size() > 32:
				result.append("Plateia precisa de uma lista de até 32 imagens.")
			else:
				for layer in arena.crowd:
					if not layer is Dictionary or not layer.get("license") is Dictionary:
						result.append("Elemento de plateia inválido.")
						continue
					for key in ["x","y","width","height"]:
						check_number(layer,key,1 if key in ["width","height"] else 0,4096,"Plateia",result)
					if check_files:
						check_asset(layer.get("file"),"Plateia",result)
		if check_files:
			check_asset(arena.get("background", ""), str(arena.id), result)
			check_asset(arena.get("music", ""), str(arena.id), result)

func validate_metadata(candidate: Dictionary, ids: Dictionary, result: PackedStringArray, check_files: bool = true) -> void:
	for section in ["campaign", "economy", "story", "menu", "audio"]:
		if not candidate.get(section) is Dictionary:
			result.append("Seção obrigatória inválida: " + section)
	if not result.is_empty():
		return
	for key in ["intro","victory","defeat","left_ending"]:
		if not candidate.story.get(key) is String:
			result.append("Texto obrigatório inválido: " + key)
	for key in ["subtitle","credits","accent"]:
		if not candidate.menu.get(key) is String:
			result.append("Menu: campo inválido: " + key)
	if not Color.html_is_valid(str(candidate.menu.get("accent",""))):
		result.append("Menu: cor de destaque inválida.")
	for field in ["background","music"]:
		if check_files and candidate.menu.has(field):
			check_asset(candidate.menu[field],"Menu",result)
	if candidate.has("resource_audio"):
		if not candidate.resource_audio is Dictionary:
			result.append("Recursos de áudio inválidos.")
		elif check_files:
			check_asset(candidate.resource_audio.get("effects",""),"Impactos",result)
	if candidate.has("library"):
		if not candidate.library is Array:
			result.append("Biblioteca deve ser uma lista.")
		else:
			var library_ids: Dictionary = {}
			for entry in candidate.library:
				if not entry is Dictionary or not entry.get("id") is String or not entry.get("file") is String or not entry.get("name") is String or not entry.get("category") is String or not entry.get("format") is String or not entry.get("kind") is String or not entry.get("license") is Dictionary or not entry.get("imported_at") is String:
					result.append("Entrada de biblioteca inválida.")
					continue
				if library_ids.has(entry.id):
					result.append("ID duplicado na biblioteca: "+entry.id)
				library_ids[entry.id] = true
				for key in ["bytes","width","height","seconds"]:
					check_number(entry,key,0,100000000,"Biblioteca",result)
				if check_files:
					check_asset(entry.file,"Biblioteca",result)
	if not candidate.get("title") is String or str(candidate.get("title","")).is_empty():
		result.append("Título do jogo obrigatório.")
	for channel in ["Music","Effects","Voices","Crowd","Ambience","UI"]:
		check_number(candidate.audio,channel,0,1,"Áudio",result)
	for key in ["win_reward","loss_reward"]:
		check_number(candidate.economy,key,0,100000,"Economia",result)
	check_number(candidate.campaign,"seed",0,2147483647,"Campanha",result)
	if not candidate.campaign.get("routes") is Dictionary:
		result.append("Rotas de campanha devem ser um objeto.")
	else:
		for route in candidate.campaign.routes:
			if not candidate.campaign.routes[route] is Array:
				result.append("Rota deve ser uma lista: " + str(route))
	if not candidate.campaign.get("ranks") is Array or candidate.campaign.ranks.is_empty():
		result.append("Campanha precisa de cargos.")
	else:
		for rank in candidate.campaign.ranks:
			if not rank is Dictionary:
				result.append("Cargo inválido.")
				continue
			check_number(rank, "fights", 1, 155, "Cargo", result)
			check_number(rank, "difficulty", 0, 7, "Cargo", result)
			check_number(rank, "reward", 0, 100000, "Cargo", result)
			if not rank.get("name") is String or str(rank.get("name","")).is_empty():
				result.append("Nome de cargo obrigatório.")
	for faction in candidate.factions:
		if not ids.has(faction.get("boss", "")):
			result.append("Chefe inexistente na facção: " + str(faction.get("id", "")))
		elif not candidate.characters.any(func(character): return character.id == faction.boss and character.boss):
			result.append("O personagem reservado como chefe precisa da opção Personagem chefe: " + str(faction.boss))
		if faction.has("boss_arena") and not candidate.arenas.any(func(arena): return arena.id == faction.boss_arena):
			result.append("Arena final inexistente: " + str(faction.get("boss_arena")))
	if candidate.campaign.get("narrative_invincible_route") != "esquerda":
		result.append("O Paradoxo da URNA-X é exclusivo da história da Esquerda.")
	if candidate.campaign.has("narrative_boss_id") and not ids.has(candidate.campaign.narrative_boss_id):
		result.append("Chefe narrativo inexistente.")

func validate_upgrades(collection: Variant, result: PackedStringArray) -> void:
	if not collection is Array:
		result.append("Lista de melhorias inválida.")
	else:
		var upgrade_ids: Dictionary = {}
		for upgrade in collection:
			if not upgrade is Dictionary:
				result.append("Melhoria inválida.")
				continue
			var uid = str(upgrade.get("id", ""))
			if uid.is_empty() or upgrade_ids.has(uid):
				result.append("Melhoria vazia ou duplicada: " + uid)
			upgrade_ids[uid] = true
			check_number(upgrade, "price", 1, 100000, uid, result)
			check_number(upgrade, "max_level", 1, 10, uid, result)
			check_number(upgrade, "effect", 0, 0.1, uid, result)

func validate_careers(candidate: Dictionary, result: PackedStringArray) -> void:
	for faction in candidate.factions:
		for character in candidate.characters:
			if character.faction != faction.id or character.get("boss",false) or not character.get("campaign_enabled",true):
				continue
			var generator = Campaign.new()
			generator.generate(candidate,character.id,faction.id,int(candidate.campaign.seed))
			if not generator.errors.is_empty():
				result.append(character.id + ": " + generator.errors[0])
				break

func check_number(object: Dictionary, key: String, low: float, high: float, label: String, result: PackedStringArray) -> void:
	var value = object.get(key)
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) < low or float(value) > high:
		result.append("%s: %s deve estar entre %s e %s." % [label, key, low, high])
	elif key in ["startup","active","recovery","stun","priority","cooldown","columns","rows","fights","difficulty","reward","price","max_level","seed","start","end","count"] and float(value) != floor(float(value)):
		result.append(label + ": " + key + " deve ser inteiro.")

func asset_path(relative: String) -> String:
	return path.get_base_dir().path_join(relative)

func check_asset(value: Variant, label: String, result: PackedStringArray) -> void:
	if not value is String:
		result.append(label + ": caminho de recurso inválido.")
		return
	if value.is_empty():
		return
	if not value.begins_with("assets/") or ".." in value or value.is_absolute_path():
		result.append(label + ": recursos devem ficar em assets/ do projeto.")
	elif not FileAccess.file_exists(asset_path(value)) and not ResourceLoader.exists(asset_path(value)):
		result.append(label + ": recurso ausente: " + value)

func save_file(destination: String = "") -> bool:
	if destination.is_empty():
		destination = path
	errors = validate(data)
	if not errors.is_empty():
		return false
	var status = write_atomic(destination, data)
	if status != OK:
		errors.append("Não foi possível salvar: " + error_string(status))
		return false
	path = destination
	return true

func validate_distribution() -> PackedStringArray:
	var result = validate(data)
	if not result.is_empty():
		return result
	for character in data.characters:
		if not str(character.get("sprite","")).is_empty():
			check_license(character.get("sprite_license"),character.sprite,result)
	for arena in data.arenas:
		for layer in arena.get("crowd",[]):
			check_license(layer.get("license"),layer.file,result)
		for field in ["background","music"]:
			if not str(arena.get(field,"")).is_empty():
				check_license(arena.get(field+"_license"),arena[field],result)
	for section in ["menu","resource_audio"]:
		for field in ["background","music","effects"]:
			if not str(data.get(section,{}).get(field,"")).is_empty():
				check_license(data[section].get(field+"_license"),data[section][field],result)
	return result

func check_license(record: Variant, asset: String, result: PackedStringArray) -> void:
	if not record is Dictionary:
		result.append(asset + ": registre origem, licença e autorização antes de distribuir.")
		return
	for field in ["source","license","authorization"]:
		if not record.get(field) is String or str(record.get(field,"")).strip_edges().is_empty():
			result.append(asset + ": registrar " + field + " do recurso.")

func distribution_snapshot(omit_unlicensed: bool = false) -> Dictionary:
	var snapshot = data.duplicate(true)
	var omitted: Array = []
	if omit_unlicensed:
		for character in snapshot.characters:
			var issues: PackedStringArray = []
			if not str(character.get("sprite","")).is_empty():
				check_license(character.get("sprite_license"),character.sprite,issues)
				if not issues.is_empty():
					omitted.append({"target":character.id,"field":"sprite","file":character.sprite})
					character.sprite = ""
		for arena in snapshot.arenas:
			for field in ["background","music"]:
				var issues: PackedStringArray = []
				if not str(arena.get(field,"")).is_empty():
					check_license(arena.get(field+"_license"),arena[field],issues)
					if not issues.is_empty():
						omitted.append({"target":arena.id,"field":field,"file":arena[field]})
						arena[field] = ""
			var layers: Array = []
			for layer in arena.get("crowd",[]):
				var issues: PackedStringArray = []
				check_license(layer.get("license"),layer.file,issues)
				if issues.is_empty():
					layers.append(layer)
				else:
					omitted.append({"target":arena.id,"field":"crowd","file":layer.file})
			if arena.has("crowd"):
				arena.crowd = layers
		for section in ["menu","resource_audio"]:
			for field in ["background","music","effects"]:
				var issues: PackedStringArray = []
				if not str(snapshot.get(section,{}).get(field,"")).is_empty():
					check_license(snapshot[section].get(field+"_license"),snapshot[section][field],issues)
					if not issues.is_empty():
						omitted.append({"target":section,"field":field,"file":snapshot[section][field]})
						snapshot[section][field] = ""
	snapshot.erase("library")
	snapshot.erase("resource_placements")
	return {"data":snapshot,"omitted":omitted}

static func write_atomic(destination: String, value: Dictionary) -> Error:
	var status = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if status != OK:
		return status
	var temp = destination + ".tmp"
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(destination):
		if FileAccess.file_exists(destination + ".bak"):
			status = DirAccess.remove_absolute(destination + ".bak")
			if status != OK:
				return status
		status = DirAccess.rename_absolute(destination, destination + ".bak")
		if status != OK:
			return status
	status = DirAccess.rename_absolute(temp, destination)
	if status != OK and FileAccess.file_exists(destination + ".bak"):
		DirAccess.rename_absolute(destination + ".bak", destination)
	return status

func character(id: String) -> Dictionary:
	for entry in data.get("characters", []):
		if entry.id == id:
			return entry
	return {}
