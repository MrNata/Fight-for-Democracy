extends VBoxContainer
## Reusable UI in Studio and Player. The caller decides where configurations are saved.
signal changed(config: Dictionary)
signal save_requested(config: Dictionary)
const Config = preload("res://runtime/controls_config.gd")
const UI = preload("res://runtime/ui_kit.gd")
var config: Dictionary = {}
var default_config: Dictionary = {}
var player_index = 0
var device_kind = "keyboard"
var capture_action = ""
var notice: Label
var devices_label: Label
var rows: VBoxContainer
var profile_select: OptionButton
var player_select: OptionButton
var device_select: OptionButton
var capture_dialog: ConfirmationDialog
var last_event = "Nenhuma entrada recebida."
var monitor_time = 0.0
var device_snapshot = ""

func setup(value: Dictionary, defaults_value: Dictionary) -> void:
	config = value.duplicate(true)
	default_config = defaults_value.duplicate(true)
	build()

func button(text: String, callback: Callable) -> Button:
	var control = UI.button(text,callback)
	control.custom_minimum_size.y = 38
	return control

func build() -> void:
	UI.clear(self)
	add_theme_constant_override("separation",12)
	var top = HBoxContainer.new()
	profile_select = OptionButton.new()
	for name in config.profiles:
		profile_select.add_item(name)
		if name == config.active_profile:
			profile_select.select(profile_select.item_count-1)
	profile_select.item_selected.connect(func(index): config.active_profile = profile_select.get_item_text(index); changed.emit(config.duplicate(true)); build())
	top.add_child(profile_select)
	top.add_child(button("Novo perfil",new_profile))
	top.add_child(button("Restaurar padrões",restore_defaults))
	top.add_child(button("Salvar configurações",save_config))
	add_child(top)
	var selection = HBoxContainer.new()
	player_select = OptionButton.new()
	player_select.add_item("Jogador 1")
	player_select.add_item("Jogador 2")
	player_select.select(player_index)
	player_select.item_selected.connect(func(index): player_index = index; build())
	selection.add_child(player_select)
	var type = OptionButton.new()
	type.add_item("Teclado")
	type.add_item("Controle USB / Bluetooth")
	type.select(0 if device_kind == "keyboard" else 1)
	type.item_selected.connect(func(index): device_kind = "keyboard" if index == 0 else "gamepad"; build())
	selection.add_child(type)
	var player: Dictionary = config.profiles[config.active_profile].players[player_index]
	device_select = OptionButton.new()
	device_select.item_selected.connect(func(index): player.device = device_select.get_item_metadata(index); changed.emit(config.duplicate(true)); refresh_notice())
	selection.add_child(device_select)
	refresh_devices()
	add_child(selection)
	if device_kind == "gamepad":
		var analog = CheckBox.new()
		analog.text = "Usar analógico esquerdo para movimentação"
		analog.button_pressed = player.analog
		analog.toggled.connect(func(value): player.analog = value; changed.emit(config.duplicate(true)))
		add_child(analog)
	devices_label = UI.label("",15,UI.MUTED)
	devices_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(devices_label)
	notice = UI.label("Clique em Alterar e pressione a nova entrada. Esc cancela a captura.",16)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	rows = VBoxContainer.new()
	add_child(rows)
	for index in Config.ACTIONS.size():
		var action: String = Config.ACTIONS[index]
		var row = HBoxContainer.new()
		var name = UI.label(Config.NAMES[index],16)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name)
		var value = UI.label(Config.describe(player[device_kind][action]),16,Color("#8cbcff"))
		value.custom_minimum_size.x = 190
		row.add_child(value)
		var alter = button("Alterar",func(): start_capture(action))
		alter.tooltip_text = "Capturar nova tecla, botão ou eixo para " + Config.NAMES[index]
		row.add_child(alter)
		rows.add_child(row)
	refresh_notice()
	refresh_monitor()

func start_capture(action: String) -> void:
	capture_action = action
	capture_dialog = ConfirmationDialog.new()
	capture_dialog.title = "Alterar comando"
	capture_dialog.dialog_text = "Pressione uma tecla ou botão\n%s · Jogador %d · %s\nEsc cancela. Eixos são capturados ao ultrapassar 65%%." % [Config.NAMES[Config.ACTIONS.find(action)],player_index+1,device_kind]
	capture_dialog.get_ok_button().hide()
	capture_dialog.canceled.connect(cancel_capture)
	add_child(capture_dialog)
	capture_dialog.popup_centered(Vector2i(480,180))

func cancel_capture() -> void:
	capture_action = ""
	if is_instance_valid(capture_dialog):
		capture_dialog.queue_free()
	capture_dialog = null

func capture_event(event: InputEvent) -> bool:
	if capture_action.is_empty():
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_capture()
		return true
	var binding: Variant = null
	if device_kind == "keyboard" and event is InputEventKey and event.pressed and not event.echo:
		binding = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	elif device_kind == "gamepad" and event is InputEventJoypadButton and event.pressed:
		binding = {"kind":"button","button":event.button_index}
	elif device_kind == "gamepad" and event is InputEventJoypadMotion and absf(event.axis_value) > 0.65:
		binding = {"kind":"axis","axis":event.axis,"sign":1 if event.axis_value > 0 else -1}
	if binding == null:
		return false
	var player: Dictionary = config.profiles[config.active_profile].players[player_index]
	if device_kind == "gamepad" and int(player.device) >= 0 and int(player.device) != event.device:
		return true
	player[device_kind][capture_action] = binding
	changed.emit(config.duplicate(true))
	cancel_capture()
	build()
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		last_event = "Teclado · " + OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	elif event is InputEventJoypadButton:
		last_event = "Gamepad %d · %s · %s" % [event.device,Config.button_name(event.button_index),"pressionado" if event.pressed else "solto"]
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.15:
		last_event = "Gamepad %d · eixo %d · %.2f" % [event.device,event.axis,event.axis_value]
	if capture_event(event):
		get_viewport().set_input_as_handled()

func refresh_notice() -> void:
	var errors = Config.validate(config)
	notice.text = "Sem conflitos. Clique em Alterar para capturar uma entrada." if errors.is_empty() else "\n".join(errors.slice(0,4))+"\nCorrija os comandos antes de salvar."
	notice.add_theme_color_override("font_color",Color("#8cbcff") if errors.is_empty() else Color("#efaaaa"))

func refresh_monitor() -> void:
	var names: PackedStringArray = []
	for id in Input.get_connected_joypads():
		names.append("%d · %s" % [id,Input.get_joy_name(id)])
	devices_label.text = ("Nenhum gamepad conectado. Conecte um dispositivo USB ou Bluetooth." if names.is_empty() else "Conectados: " + " | ".join(names))+"\nTeste de entrada: " + last_event
	if device_snapshot != str(Input.get_connected_joypads()):
		refresh_devices()

func refresh_devices() -> void:
	device_snapshot = str(Input.get_connected_joypads())
	device_select.clear()
	device_select.add_item("Gamepad automático")
	device_select.set_item_metadata(0,-1)
	var player: Dictionary = config.profiles[config.active_profile].players[player_index]
	for id in Input.get_connected_joypads():
		device_select.add_item("%d · %s" % [id,Input.get_joy_name(id)])
		device_select.set_item_metadata(device_select.item_count-1,int(id))
		if int(player.device) == id:
			device_select.select(device_select.item_count-1)
	if int(player.device) >= 0 and int(player.device) not in Input.get_connected_joypads():
		device_select.add_item("%d · desconectado" % int(player.device))
		device_select.set_item_metadata(device_select.item_count-1,int(player.device))
		device_select.select(device_select.item_count-1)

func _process(delta: float) -> void:
	monitor_time += delta
	if monitor_time > 0.2:
		monitor_time = 0
		refresh_monitor()

func save_config() -> bool:
	refresh_notice()
	if not Config.validate(config).is_empty():
		return false
	save_requested.emit(config.duplicate(true))
	return true

func restore_defaults() -> void:
	var name: String = config.active_profile
	config.profiles[name] = default_config.profiles[default_config.active_profile].duplicate(true)
	changed.emit(config.duplicate(true))
	build()

func new_profile() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Novo perfil de controles"
	var input = LineEdit.new()
	input.offset_left = 16
	input.offset_top = 16
	input.offset_right = 420
	input.offset_bottom = 56
	input.placeholder_text = "Nome do perfil"
	dialog.add_child(input)
	dialog.confirmed.connect(func():
		var name = input.text.strip_edges()
		if not name.is_empty() and not config.profiles.has(name) and config.profiles.size() < 20:
			config.profiles[name] = config.profiles[config.active_profile].duplicate(true)
			config.active_profile = name
			changed.emit(config.duplicate(true))
			build()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(440,140))
