extends RefCounted

func purchase(wallet: Dictionary, upgrade: Dictionary) -> bool:
	var levels: Dictionary = wallet.get("upgrades", {})
	var level = int(levels.get(upgrade.id, 0))
	var price = int(upgrade.price) * (level + 1)
	if level >= int(upgrade.max_level) or int(wallet.get("propina", 0)) < price:
		return false
	wallet.propina = int(wallet.propina) - price
	levels[upgrade.id] = level + 1
	wallet.upgrades = levels
	return true

func apply(character: Dictionary, wallet: Dictionary, content: Dictionary) -> Dictionary:
	var result = character.duplicate(true)
	for upgrade in content.economy.upgrades:
		var bonus = float(upgrade.effect) * int(wallet.get("upgrades", {}).get(upgrade.id, 0))
		match upgrade.id:
			"health", "strength", "speed": result.stats[upgrade.id] *= 1.0 + bonus
			"defense": result.stats.defense = minf(0.65, float(result.stats.defense) + bonus)
			"fame":
				for move in result.moves.values():
					move.fame_gain *= 1.0 + bonus
			"special_cost":
				for move in result.moves.values():
					move.fame_cost *= maxf(0.5, 1.0 - bonus)
	return result
