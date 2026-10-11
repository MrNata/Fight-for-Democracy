extends RefCounted
## Library operations never delete disk files. Referenced bytes remain available to history/backups.
const Audio = preload("res://runtime/audio_system.gd")
const CATEGORIES = ["Personagens e sprites","Animações","Músicas","Efeitos sonoros","Vozes e bordões","Cenários","Elementos de plateia","Interface"]
var error = ""

func index_existing(data: Dictionary, content_root: String) -> int:
	var references: Dictionary = {}
	for character in data.characters:
		if not str(character.get("sprite","")).is_empty():
			references[character.sprite] = {"category":CATEGORIES[0],"license":character.get("sprite_license",{})}
		for clips in character.voices.values():
			for clip in clips:
				references[clip.file] = {"category":CATEGORIES[4],"license":{"source":clip.get("source",""),"license":clip.get("license",""),"authorization":clip.get("authorization","")}}
	for arena in data.arenas:
		for layer in arena.get("crowd",[]):
			references[layer.file] = {"category":CATEGORIES[6],"license":layer.get("license",{})}
		for field in ["background","music"]:
			if not str(arena.get(field,"")).is_empty():
				references[arena[field]] = {"category":CATEGORIES[5] if field == "background" else CATEGORIES[2],"license":arena.get(field+"_license",{})}
	if not data.has("library"):
		data.library = []
	var count = 0
	for relative in references:
		if data.library.any(func(entry): return entry.file == relative):
			continue
		var info = inspect(content_root.path_join(relative))
		if info.is_empty():
			continue
		var entry = {"id":str(relative).sha256_text(),"file":relative,"name":info.name,"category":references[relative].category,"format":info.format,"bytes":info.bytes,"width":info.width,"height":info.height,"seconds":info.seconds,"kind":info.kind,"license":references[relative].license.duplicate(true),"imported_at":Time.get_datetime_string_from_system(true)}
		data.library.append(entry)
		count += 1
	return count

func inspect(path: String) -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path):
		error = "Arquivo não encontrado: " + path.get_file()
		return {}
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		error = "Não foi possível abrir o arquivo. Verifique o acesso à pasta."
		return {}
	var size = file.get_length()
	file.close()
	if size == 0 or size > 64*1024*1024:
		error = "Use arquivos não vazios de até 64 MB."
		return {}
	var extension = path.get_extension().to_lower()
	var result = {"name":path.get_file().get_basename(),"format":extension,"bytes":size,"source_path":path,"width":0,"height":0,"seconds":0.0}
	if extension in ["png","jpg","jpeg","webp"]:
		var image = Image.load_from_file(path)
		if image == null or image.get_width() > 8192 or image.get_height() > 8192:
			error = "Imagem inválida ou maior que 8192 × 8192 pixels."
			return {}
		result.width = image.get_width()
		result.height = image.get_height()
		result.kind = "image"
	elif extension in ["wav","ogg","mp3"]:
		var decoder = Audio.new()
		var stream = decoder.load_stream(path)
		decoder.free()
		if stream == null:
			error = "Áudio inválido. Use WAV, OGG ou MP3 com codificação compatível."
			return {}
		result.seconds = stream.get_length()
		result.kind = "audio"
	else:
		error = "Formato .%s não suportado. Use PNG, JPG, WebP, WAV, OGG ou MP3." % extension
		return {}
	return result

func import_file(path: String, content_root: String, category: String, metadata: Dictionary, data: Dictionary) -> Dictionary:
	var info = inspect(path)
	if info.is_empty():
		return {}
	if category not in CATEGORIES:
		error = "Escolha uma categoria válida."
		return {}
	if (info.kind == "image" and category in ["Músicas","Efeitos sonoros","Vozes e bordões"]) or (info.kind == "audio" and category not in ["Músicas","Efeitos sonoros","Vozes e bordões"]):
		error = "A categoria escolhida não corresponde ao tipo do arquivo."
		return {}
	var hash_value = FileAccess.get_sha256(path)
	var relative = "assets/%s.%s" % [hash_value,info.format]
	var destination = content_root.path_join(relative)
	var status = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if status != OK:
		error = "Não foi possível criar a pasta de recursos: " + error_string(status)
		return {}
	if FileAccess.file_exists(destination):
		if FileAccess.get_sha256(destination) != hash_value:
			error = "Um arquivo diferente ocupa o destino; nenhum conteúdo foi substituído."
			return {}
	elif DirAccess.copy_absolute(path,destination) != OK:
		error = "Falha ao copiar o arquivo para o projeto."
		return {}
	if not data.has("library"):
		data.library = []
	for entry in data.library:
		if entry.file == relative:
			return entry
	var entry = {"id":hash_value,"file":relative,"name":str(metadata.get("name",info.name)),"category":category,"format":info.format,"bytes":info.bytes,"width":info.width,"height":info.height,"seconds":info.seconds,"kind":info.kind,"license":metadata.duplicate(true),"imported_at":Time.get_datetime_string_from_system(true)}
	data.library.append(entry)
	return entry

static func dependencies(data: Dictionary, relative: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for character in data.characters:
		if character.get("sprite","") == relative:
			result.append(character.name+" · sprite")
		for event in character.voices:
			for clip in character.voices[event]:
				if clip.file == relative:
					result.append(character.name+" · voz/"+event)
	for arena in data.arenas:
		for layer in arena.get("crowd",[]):
			if layer.file == relative:
				result.append(arena.name+" · elemento de plateia")
		for field in ["background","music"]:
			if arena.get(field,"") == relative:
				result.append(arena.name+" · "+field)
	for section in ["menu","audio"]:
		for key in data[section]:
			if data[section][key] is String and data[section][key] == relative:
				result.append(section+" · "+key)
	if data.get("resource_audio",{}).get("effects") == relative:
		result.append("Luta · sons de impacto")
	for placement in data.get("resource_placements",[]):
		if placement.get("file") == relative:
			result.append(str(placement.get("target",""))+" · referência de autoria/"+str(placement.get("slot","")))
	return result

static func unlink(data: Dictionary, relative: String) -> void:
	for character in data.characters:
		if character.get("sprite") == relative:
			character.sprite = ""
		for event in character.voices:
			character.voices[event] = character.voices[event].filter(func(clip): return clip.file != relative)
	for arena in data.arenas:
		for field in ["background","music"]:
			if arena.get(field) == relative:
				arena[field] = ""
		if arena.has("crowd"):
			arena.crowd = arena.crowd.filter(func(layer): return layer.file != relative)
	for section in ["menu","resource_audio"]:
		for field in ["background","music","effects"]:
			if data.get(section,{}).get(field) == relative:
				data[section][field] = ""

func remove(data: Dictionary, entry_id: String) -> bool:
	error = ""
	for entry in data.get("library",[]):
		if entry.id != entry_id:
			continue
		var used = dependencies(data,entry.file)
		if not used.is_empty():
			error = "Recurso em uso:\n"+"\n".join(used)+"\nRemova os vínculos antes de excluir."
			return false
		data.library.erase(entry)
		return true
	error = "Recurso não encontrado na biblioteca."
	return false

func link(data: Dictionary, entry: Dictionary, target_type: String, target_id: String, slot: String) -> bool:
	error = ""
	if target_type == "none":
		return true
	if target_type == "interface" and slot in ["background","music"] and entry.kind == ("image" if slot == "background" else "audio"):
		data.menu[slot] = entry.file
		data.menu[slot+"_license"] = entry.license.duplicate(true)
		return true
	if target_type == "audio" and slot == "effects" and entry.kind == "audio":
		data["resource_audio"] = {"effects":entry.file,"effects_license":entry.license.duplicate(true)}
		return true
	var collection: Array = data.characters if target_type == "character" else data.arenas
	for target in collection:
		if target.id != target_id:
			continue
		if slot == "crowd" and target_type == "arena" and entry.kind == "image":
			if not target.has("crowd"):
				target.crowd = []
			if not target.crowd.any(func(layer): return layer.file == entry.file):
				target.crowd.append({"file":entry.file,"license":entry.license.duplicate(true),"x":960,"y":740,"width":500,"height":180})
			return true
		if slot == "sprite" and target_type == "character" and entry.kind == "image":
			target.sprite = entry.file
			target.sprite_license = entry.license.duplicate(true)
			return true
		if slot in ["background","music"] and target_type == "arena" and entry.kind == ("image" if slot == "background" else "audio"):
			target[slot] = entry.file
			target[slot+"_license"] = entry.license.duplicate(true)
			return true
		if slot.begins_with("voice/") and target_type == "character" and entry.kind == "audio":
			var event = slot.trim_prefix("voice/")
			if not target.voices.has(event):
				target.voices[event] = []
			if not target.voices[event].any(func(clip): return clip.file == entry.file):
				var clip: Dictionary = entry.license.duplicate(true)
				clip.merge({"file":entry.file,"weight":1.0,"volume":0.8,"interval":2.0},true)
				target.voices[event].append(clip)
			return true
		error = "O vínculo escolhido não corresponde a este recurso."
		return false
	error = "Personagem ou arena não encontrado."
	return false

static func sync_license(data: Dictionary, entry: Dictionary) -> void:
	for character in data.characters:
		if character.get("sprite") == entry.file:
			character.sprite_license = entry.license.duplicate(true)
		for clips in character.voices.values():
			for clip in clips:
				if clip.file == entry.file:
					for key in ["source","license","authorization"]:
						clip[key] = entry.license.get(key,"")
	for arena in data.arenas:
		for layer in arena.get("crowd",[]):
			if layer.file == entry.file:
				layer.license = entry.license.duplicate(true)
		for field in ["background","music"]:
			if arena.get(field) == entry.file:
				arena[field+"_license"] = entry.license.duplicate(true)
	for section in ["menu","resource_audio"]:
		for field in ["background","music","effects"]:
			if data.get(section,{}).get(field) == entry.file:
				data[section][field+"_license"] = entry.license.duplicate(true)
