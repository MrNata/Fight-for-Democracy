extends RefCounted
## Shared project defaults and private player preferences. No gameplay state is stored here.
const ACTIONS = ["left","right","jump","crouch","light_punch","heavy_punch","light_kick","heavy_kick","block","dodge","throw","counter","special_a","special_b","super","finisher","pause","menu_up","menu_down","menu_left","menu_right","menu_accept","menu_cancel"]
const NAMES = ["Mover à esquerda","Mover à direita","Pular","Agachar","Soco leve","Soco forte","Chute leve","Chute forte","Defender","Esquivar","Agarrar","Contra-ataque","Especial A","Especial B","Superespecial","Finalização","Pausar","Menu: acima","Menu: abaixo","Menu: esquerda","Menu: direita","Menu: confirmar","Menu: voltar"]
const BUTTON_NAMES = ["A / Cross","B / Circle","X / Square","Y / Triangle","Back","Guide","Start","L3","R3","LB","RB","Direcional ↑","Direcional ↓","Direcional ←","Direcional →"]

static func defaults() -> Dictionary:
	var keys = [
		[KEY_A,KEY_D,KEY_W,KEY_S,KEY_J,KEY_K,KEY_U,KEY_I,KEY_G,KEY_H,KEY_L,KEY_T,KEY_Q,KEY_E,KEY_R,KEY_F,KEY_ESCAPE,KEY_W,KEY_S,KEY_A,KEY_D,KEY_ENTER,KEY_ESCAPE],
		[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_KP_1,KEY_KP_2,KEY_KP_4,KEY_KP_5,KEY_KP_0,KEY_KP_PERIOD,KEY_KP_3,KEY_KP_6,KEY_KP_7,KEY_KP_8,KEY_KP_9,KEY_KP_ADD,KEY_ESCAPE,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_KP_ENTER,KEY_ESCAPE]]
	var buttons = [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_A,JOY_BUTTON_X,JOY_BUTTON_B,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_LEFT_STICK,JOY_BUTTON_RIGHT_SHOULDER,-1,-1,-1,JOY_BUTTON_RIGHT_STICK,JOY_BUTTON_BACK,JOY_BUTTON_START,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_A,JOY_BUTTON_B]
	var players: Array = []
	for player in 2:
		var keyboard: Dictionary = {}
		var gamepad: Dictionary = {}
		for i in ACTIONS.size():
			keyboard[ACTIONS[i]] = keys[player][i]
			gamepad[ACTIONS[i]] = {"kind":"button","button":buttons[i]}
		gamepad.counter = {"kind":"chord","buttons":[JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_X]}
		gamepad.special_a = {"kind":"axis","axis":JOY_AXIS_TRIGGER_LEFT,"sign":1}
		gamepad.special_b = {"kind":"axis","axis":JOY_AXIS_TRIGGER_RIGHT,"sign":1}
		players.append({"keyboard":keyboard,"gamepad":gamepad,"device":-1,"deadzone":0.2,"analog":true})
	return {"schema_version":1,"active_profile":"Padrão","profiles":{"Padrão":{"players":players}}}

static func project_defaults(content: Dictionary) -> Dictionary:
	return content.get("controls",defaults()).duplicate(true)

static func numeric(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high

static func validate(config: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if config.get("schema_version") != 1 or not config.get("profiles") is Dictionary or not config.get("active_profile") is String:
		return ["Configuração de controles incompatível."]
	if config.profiles.is_empty() or config.profiles.size() > 20 or not config.profiles.has(config.active_profile):
		return ["Selecione um perfil existente; limite de 20 perfis."]
	for profile_name in config.profiles:
		var profile = config.profiles[profile_name]
		if not profile_name is String or str(profile_name).strip_edges().is_empty() or not profile is Dictionary or not profile.get("players") is Array or profile.players.size() != 2:
			errors.append("Perfil precisa de nome e exatamente dois jogadores.")
			continue
		var keyboard_seen: Dictionary = {}
		for index in 2:
			var player = profile.players[index]
			if not player is Dictionary or not player.get("keyboard") is Dictionary or not player.get("gamepad") is Dictionary:
				errors.append("Mapeamentos inválidos no jogador %d." % (index+1))
				continue
			if not numeric(player.get("device"),-1,31) or not player.get("analog") is bool or not (player.get("deadzone") is int or player.get("deadzone") is float) or not is_finite(float(player.deadzone)) or player.deadzone < 0.1 or player.deadzone > 0.8:
				errors.append("Dispositivo ou zona morta inválida no jogador %d." % (index+1))
			var pad_seen: Dictionary = {}
			for action in ACTIONS:
				var context = "menu" if action.begins_with("menu_") else "combat"
				var key = player.keyboard.get(action)
				if not numeric(key,1,0x1ffffff):
					errors.append("Tecla inválida: " + action)
				else:
					var signature = context+"/"+str(int(key))
					if keyboard_seen.has(signature) and keyboard_seen[signature].action != action:
						errors.append("Conflito de teclado: %s e %s (jogador %d)." % [keyboard_seen[signature].action,action,index+1])
					elif keyboard_seen.has(signature) and context == "combat" and action != "pause":
						errors.append("Tecla compartilhada pelos dois jogadores: " + action)
					keyboard_seen[signature] = {"action":action,"player":index}
				var binding = player.gamepad.get(action)
				if not valid_binding(binding):
					errors.append("Botão/eixo inválido: " + action)
					continue
				if context == "menu" and binding.kind == "chord":
					errors.append("Navegação de menu requer um botão ou eixo: "+action)
				var signature = context+"/"+binding_signature(binding)
				if pad_seen.has(signature):
					errors.append("Comando duplicado no gamepad: %s e %s." % [pad_seen[signature],action])
				pad_seen[signature] = action
		if profile.players[0] is Dictionary and profile.players[1] is Dictionary and numeric(profile.players[0].get("device"),0,31) and profile.players[0].device == profile.players[1].get("device"):
			errors.append("Os dois jogadores precisam de gamepads independentes; use Automático ou dispositivos diferentes.")
	return errors

static func valid_binding(binding: Variant) -> bool:
	if not binding is Dictionary:
		return false
	match binding.get("kind"):
		"button": return numeric(binding.get("button"),0,127)
		"axis": return numeric(binding.get("axis"),0,9) and (binding.get("sign") == -1 or binding.get("sign") == 1)
		"chord":
			if not binding.get("buttons") is Array or binding.buttons.size() < 2 or binding.buttons.size() > 4:
				return false
			var seen: Array = []
			for button in binding.buttons:
				if not numeric(button,0,127) or int(button) in seen:
					return false
				seen.append(int(button))
			return true
	return false

static func binding_signature(binding: Dictionary) -> String:
	if binding.kind == "chord":
		var buttons: Array = binding.buttons.map(func(button): return int(button))
		buttons.sort()
		return "chord/"+str(buttons)
	return "button/"+str(int(binding.button)) if binding.kind == "button" else "axis/%d/%d" % [int(binding.axis),int(binding.sign)]

static func button_name(index: int) -> String:
	return BUTTON_NAMES[index] if index < BUTTON_NAMES.size() else "Botão %d" % index

static func describe(binding: Variant) -> String:
	if binding is int or binding is float:
		return OS.get_keycode_string(int(binding))
	if not valid_binding(binding):
		return "Não configurado"
	if binding.kind == "button":
		return button_name(int(binding.button))
	if binding.kind == "axis":
		return "Eixo %d %s" % [int(binding.axis),"+" if binding.sign > 0 else "−"]
	return " + ".join(binding.buttons.map(func(button): return button_name(int(button))))

static func device_for(player: Dictionary, index: int) -> int:
	var connected = Input.get_connected_joypads()
	if int(player.device) >= 0:
		return int(player.device) if int(player.device) in connected else -1
	return int(connected[index]) if index < connected.size() else -1

static func held(binding: Dictionary, device: int) -> bool:
	if device < 0:
		return false
	match binding.kind:
		"button": return Input.is_joy_button_pressed(device,int(binding.button))
		"axis": return Input.get_joy_axis(device,int(binding.axis))*float(binding.sign) > 0.5
		"chord": return binding.buttons.all(func(button): return Input.is_joy_button_pressed(device,int(button)))
	return false

static func event_matches(event: InputEvent, player: Dictionary, action: String, index: int) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and int(player.keyboard[action]) == (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	var binding: Dictionary = player.gamepad[action]
	if device_for(player,index) != event.device:
		return false
	if event is InputEventJoypadButton:
		return event.pressed and binding.kind == "button" and int(binding.button) == event.button_index
	return event is InputEventJoypadMotion and binding.kind == "axis" and int(binding.axis) == event.axis and event.axis_value*float(binding.sign) > 0.65

static func install_menu_bindings(config: Dictionary) -> void:
	var profile: Dictionary = config.profiles[config.active_profile]
	for action in ["up","down","left","right","accept","cancel"]:
		var target = "ui_"+action
		InputMap.action_erase_events(target)
		for player in profile.players:
			var key = InputEventKey.new()
			key.physical_keycode = int(player.keyboard["menu_"+action])
			InputMap.action_add_event(target,key)
			var binding: Dictionary = player.gamepad["menu_"+action]
			if binding.kind == "button":
				var button = InputEventJoypadButton.new()
				button.device = int(player.device)
				button.button_index = int(binding.button)
				InputMap.action_add_event(target,button)
			elif binding.kind == "axis":
				var axis = InputEventJoypadMotion.new()
				axis.device = int(player.device)
				axis.axis = int(binding.axis)
				axis.axis_value = float(binding.sign)
				InputMap.action_add_event(target,axis)

static func load_preferences(path: String, fallback: Dictionary) -> Dictionary:
	for source in [path,path+".bak"]:
		if not FileAccess.file_exists(source):
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(source)) == OK and parser.data is Dictionary and validate(parser.data).is_empty():
			return parser.data
	return fallback.duplicate(true)
