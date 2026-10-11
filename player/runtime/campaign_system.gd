extends RefCounted
## Stable seeded schedule. Losses retry the same index; the boss is never shuffled.
var errors: PackedStringArray = []

func generate(content: Dictionary, chosen: String, faction_id: String, seed_value: int) -> Array:
	errors.clear()
	var boss = ""
	var boss_arena = content.arenas[-1].id
	for faction in content.factions:
		if faction.id == faction_id:
			boss = faction.boss
			boss_arena = faction.get("boss_arena",boss_arena)
	if boss.is_empty() or boss == chosen:
		errors.append("Chefe inválido ou igual ao personagem escolhido.")
		return []
	var pool: Array = []
	var chosen_valid = false
	for character in content.characters:
		if character.id == chosen and character.faction == faction_id and character.get("campaign_enabled", true) and not character.get("boss", false):
			chosen_valid = true
		if character.id != chosen and character.id != boss and not character.get("boss", false) and character.faction != faction_id and character.get("campaign_enabled", true):
			pool.append(character.id)
	if not chosen_valid:
		errors.append("Personagem não pertence à facção da campanha.")
		return []
	var total = 0
	for rank in content.campaign.ranks:
		total += int(rank.fights)
	if pool.size() < total:
		errors.append("Adversários elegíveis insuficientes: %d; necessários: %d." % [pool.size(), total])
		return []
	pool.sort()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(pool.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var value = pool[i]
		pool[i] = pool[j]
		pool[j] = value
	var schedule: Array = []
	var normal_arenas: Array = content.arenas.filter(func(arena): return not arena.get("boss_only",false))
	if normal_arenas.is_empty():
		errors.append("Campanha precisa de uma arena para confrontos comuns.")
		return []
	for rank_index in content.campaign.ranks.size():
		var rank: Dictionary = content.campaign.ranks[rank_index]
		for _fight in int(rank.fights):
			var index = schedule.size()
			schedule.append({"opponent": pool[index], "rank": rank_index, "arena": normal_arenas[index % normal_arenas.size()].id, "difficulty": rank.difficulty, "reward": rank.reward, "boss": false})
	schedule.append({"opponent": boss, "rank": content.campaign.ranks.size() - 1, "arena": boss_arena, "difficulty": 7, "reward": 1000, "boss": true})
	var authored: Array = content.campaign.get("routes", {}).get(faction_id, [])
	if not authored.is_empty():
		schedule = authored.duplicate(true)
	errors = validate_schedule(schedule, content, chosen, faction_id)
	return schedule if errors.is_empty() else []

func validate_schedule(schedule: Array, content: Dictionary, chosen: String, faction_id: String, legacy: bool = false) -> PackedStringArray:
	var result: PackedStringArray = []
	var total = 1
	for rank in content.campaign.ranks:
		total += int(rank.fights)
	if schedule.size() != total:
		result.append("Quantidade de confrontos inválida: esperado %d." % total)
	var boss = ""
	for faction in content.factions:
		if faction.id == faction_id:
			boss = faction.boss
	var ids: Dictionary = {}
	var arenas: Dictionary = {}
	for character in content.characters:
		ids[character.id] = character
	for arena in content.arenas:
		arenas[arena.id] = true
	var seen: Dictionary = {}
	var rank_counts: Dictionary = {}
	var expected_ranks: Array = []
	for rank_index in content.campaign.ranks.size():
		for _fight in int(content.campaign.ranks[rank_index].fights):
			expected_ranks.append(rank_index)
	expected_ranks.append(content.campaign.ranks.size()-1)
	if boss.is_empty() or not ids.has(chosen) or ids.get(chosen, {}).get("faction", "") != faction_id:
		result.append("Personagem ou facção da carreira inválidos.")
	for index in schedule.size():
		var fight = schedule[index]
		if not fight is Dictionary:
			result.append("Confronto %d inválido." % (index+1))
			continue
		var id = str(fight.get("opponent", ""))
		if not ids.has(id) or id == chosen or seen.has(id):
			result.append("Confronto %d: adversário inexistente, repetido ou igual ao jogador." % (index+1))
		elif (ids[id].faction == faction_id and index < schedule.size()-1) or not ids[id].get("campaign_enabled", true):
			result.append("Confronto %d: adversário incompatível com a rota." % (index+1))
		elif not legacy and index < schedule.size()-1 and ids[id].get("boss", false):
			result.append("Confronto %d: chefe reservado para a batalha final." % (index+1))
		seen[id] = true
		if (index == schedule.size()-1 and id != boss) or (index < schedule.size()-1 and id == boss):
			result.append("Chefe deve ocupar exclusivamente o último confronto.")
		if not fight.get("boss") is bool or fight.get("boss") != (index == schedule.size()-1):
			result.append("Indicador de chefe inválido no confronto %d." % (index+1))
		if not arenas.has(fight.get("arena", "")):
			result.append("Arena inválida no confronto %d." % (index+1))
		for key in ["difficulty","reward","rank"]:
			var value = fight.get(key)
			if not (value is int or value is float) or float(value) != floor(float(value)) or float(value) < 0:
				result.append("Confronto %d: %s deve ser inteiro não negativo." % [index+1,key])
		if not (fight.get("rank") is int or fight.get("rank") is float) or not (fight.get("difficulty") is int or fight.get("difficulty") is float) or not (fight.get("reward") is int or fight.get("reward") is float):
			continue
		if float(fight.get("difficulty",0)) > 7:
			result.append("Dificuldade deve estar entre 0 e 7.")
		var rank = int(fight.get("rank", -1))
		if index < expected_ranks.size() and rank != expected_ranks[index]:
			result.append("Ordem de cargos inválida no confronto %d." % (index+1))
		if rank < 0 or rank >= content.campaign.ranks.size():
			result.append("Cargo inválido no confronto %d." % (index+1))
		elif index < schedule.size()-1:
			rank_counts[rank] = rank_counts.get(rank, 0) + 1
	for index in content.campaign.ranks.size():
		if rank_counts.get(index, 0) != int(content.campaign.ranks[index].fights):
			result.append("Quantidade de lutas incorreta no cargo %d." % index)
	return result
