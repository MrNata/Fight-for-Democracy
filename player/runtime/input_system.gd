extends RefCounted
const Controls = preload("res://runtime/controls_config.gd")
var config: Dictionary = Controls.defaults()
var previous: Array = [{}, {}]
var key_reader: Callable = Input.is_physical_key_pressed
var device_reader: Callable = Controls.device_for

func configure(value: Dictionary) -> bool:
	if not Controls.validate(value).is_empty():
		return false
	config = value.duplicate(true)
	previous = [{},{}]
	return true

func poll(player_index: int) -> Dictionary:
	var player: Dictionary = config.profiles[config.active_profile].players[player_index]
	var held: Dictionary = {}
	var device = int(device_reader.call(player,player_index))
	for action in Controls.ACTIONS:
		held[action] = key_reader.call(int(player.keyboard[action])) or Controls.held(player.gamepad[action],device)
	var axis = Input.get_joy_axis(device,JOY_AXIS_LEFT_X) if device >= 0 and player.analog else 0.0
	if absf(axis) < float(player.deadzone):
		axis = 0.0
	var actions: Array = []
	var counter_chord = Controls.held(player.gamepad.counter,device) and player.gamepad.counter.kind == "chord"
	for action in ["light_punch","heavy_punch","light_kick","heavy_kick","throw","counter","special_a","special_b","super","finisher"]:
		if held[action] and not previous[player_index].get(action,false):
			if counter_chord and action != "counter" and player.gamepad[action].kind == "button" and int(player.gamepad[action].button) in player.gamepad.counter.buttons.map(func(button): return int(button)) and not key_reader.call(int(player.keyboard[action])):
				continue
			actions.append(action)
	var command = {"axis":clampf(axis+float(held.right)-float(held.left),-1,1),"crouch":held.crouch,"block":held.block,"jump":held.jump and not previous[player_index].get("jump",false),"dodge":held.dodge and not previous[player_index].get("dodge",false),"actions":actions}
	previous[player_index] = held
	return command
