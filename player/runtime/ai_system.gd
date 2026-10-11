extends RefCounted
## Observes current positions/states at reaction intervals. Never reads player input.
var level = 0
var next_decision = 0
var command: Dictionary = {}
var rng = RandomNumberGenerator.new()
var aggression = 0.5

func setup(difficulty: int, seed_value: int) -> void:
	level = clampi(difficulty, 0, 7)
	rng.seed = seed_value

func decide(fighter: Node2D, opponent: Node2D, tick: int) -> Dictionary:
	if tick < next_decision:
		return {"axis": command.get("axis", 0), "block": command.get("block", false), "actions": []}
	var reaction = maxi(6, int(fighter.config.get("ai", {}).get("reaction", 24)) - level * 2)
	next_decision = tick + reaction + rng.randi_range(0, 12)
	var distance = absf(opponent.position.x - fighter.position.x)
	var towards = signf(opponent.position.x - fighter.position.x)
	command = {"axis": towards if distance > 155 else 0.0, "block": false, "actions": []}
	if level >= 1 and distance < 260 and opponent.state == opponent.State.ATTACK and rng.randf() < 0.25 + level * 0.08:
		command.block = true
		command.axis = 0.0
		return command
	if level >= 3 and fighter.fame >= 35 and distance < 650 and rng.randf() < 0.45:
		command.actions.append("super" if fighter.fame >= 80 and level >= 6 else "special_a")
	elif distance < 185 and rng.randf() < float(fighter.config.get("ai", {}).get("aggression", aggression)) + level * 0.05:
		var attacks = ["light_punch", "light_kick"]
		if level >= 2:
			attacks.append_array(["heavy_punch", "heavy_kick"])
		if level >= 4 and opponent.state == opponent.State.BLOCK:
			attacks.append("throw")
		command.actions.append(attacks[rng.randi_range(0, attacks.size()-1)])
	if level >= 3 and distance < 95 and not command.block:
		command.axis = -towards
	if level >= 5 and fighter.health < float(fighter.config.stats.health) * 0.5:
		command.jump = rng.randf() < 0.15
	if level == 7 and fighter.health < float(fighter.config.stats.health) * 0.35:
		next_decision = tick + maxi(6, reaction - 3)
	return command
