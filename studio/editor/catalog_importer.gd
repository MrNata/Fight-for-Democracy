extends RefCounted
## Transactional patches by ID. No disk writes and no mutation of the open project.
const Store = preload("res://runtime/content_store.gd")
var errors: PackedStringArray = []
var candidate: Dictionary = {}
var summary = ""

func prepare_file(source: String, store: RefCounted) -> bool:
	errors.clear()
	candidate = {}
	summary = ""
	if not FileAccess.file_exists(source):
		errors.append("Pacote ausente: " + source)
		return false
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(source)) != OK:
		errors.append("JSON inválido na linha %d: %s" % [parser.get_error_line(),parser.get_error_message()])
		return false
	if not parser.data is Dictionary:
		errors.append("Pacote deve ser um objeto JSON com format e version.")
		return false
	return prepare(parser.data,store)

func prepare(packet: Dictionary, store: RefCounted) -> bool:
	errors.clear()
	candidate = {}
	summary = ""
	if packet.get("version") != 1 or packet.get("format") not in ["ffd.catalog","ffd.campaigns"]:
		errors.append("Formato incompatível. Consulte docs/IMPORTACAO.md (ffd.catalog / ffd.campaigns, version 1).")
		return false
	var draft: Dictionary = store.data.duplicate(true)
	var mapping = packet.get("id_map",{})
	if not mapping is Dictionary:
		errors.append("id_map deve ser um objeto de ID externo para ID existente.")
		return false
	if packet.format == "ffd.catalog":
		if not packet.get("characters") is Array or packet.characters.size() != 156 or draft.characters.size() != 156:
			errors.append("Importação exige 156 registros no pacote e no projeto; nenhum registro será apagado ou criado implicitamente.")
			return false
		var existing: Dictionary = {}
		for character in draft.characters:
			existing[character.id] = character
		var seen: Dictionary = {}
		for patch in packet.characters:
			if not patch is Dictionary or not patch.get("id") is String:
				errors.append("Cada registro deve ser um objeto com ID textual.")
				continue
			var target = mapping.get(patch.id,patch.id)
			if not target is String or not existing.has(target) or seen.has(target):
				errors.append("ID inexistente ou duplicado: %s. Para IDs externos, forneça id_map explícito." % str(target))
				continue
			seen[target] = true
			var translated: Dictionary = patch.duplicate(true)
			translated.id = target
			merge(existing[target],translated)
		if seen.size() != 156:
			errors.append("O pacote deve cobrir todos os 156 IDs existentes uma única vez.")
		var counts = {"direita":0,"esquerda":0,"centrao":0,"independente":0}
		for character in draft.characters:
			if counts.has(character.get("faction")):
				counts[character.faction] += 1
		if counts.values() != [40,40,40,36]:
			errors.append("Distribuição obrigatória: Direita 40, Esquerda 40, Centrão 40, Independentes 36.")
	if packet.has("routes") or packet.format == "ffd.campaigns":
		if not packet.get("routes") is Dictionary:
			errors.append("routes deve conter quatro sequências de 114 confrontos.")
		else:
			var routes: Dictionary = packet.routes.duplicate(true)
			for faction in ["direita","esquerda","centrao","independente"]:
				if not routes.get(faction) is Array or routes.get(faction,[]).size() != 114:
					errors.append(faction + ": exige uma rota completa com 114 confrontos.")
					continue
				for fight in routes[faction]:
					if fight is Dictionary and fight.get("opponent") is String:
						fight.opponent = mapping.get(fight.opponent,fight.opponent)
			for key in routes:
				if key not in ["direita","esquerda","centrao","independente"]:
					errors.append("Facção desconhecida no pacote: " + str(key))
			draft.campaign.routes = routes
	if not errors.is_empty():
		return false
	errors = store.validate(draft)
	if not errors.is_empty():
		return false
	candidate = draft
	summary = "Prévia validada: %d personagens, 156 IDs preservados, quatro carreiras verificadas.\nCampos omitidos mantêm os valores atuais, incluindo golpes.\nRotas importadas: %d. A aplicação altera o projeto aberto; Salvar cria backup em .bak." % [draft.characters.size(),draft.campaign.routes.size()]
	return true

static func merge(target: Dictionary, patch: Dictionary) -> void:
	for key in patch:
		if patch[key] is Dictionary and target.get(key) is Dictionary:
			merge(target[key],patch[key])
		else:
			target[key] = patch[key].duplicate(true) if patch[key] is Array or patch[key] is Dictionary else patch[key]
