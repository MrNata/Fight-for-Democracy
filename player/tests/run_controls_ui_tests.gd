extends SceneTree
const App = preload("res://ui/player_app.gd")
const Controls = preload("res://runtime/controls_config.gd")
var passed = 0
var failed = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: "+title)

func run() -> void:
	var app = App.new()
	root.add_child(app)
	app.control_preferences_path = "user://controls_ui_test_%d/preferences.json" % Time.get_ticks_usec()
	app.control_settings = Controls.project_defaults(app.store.data)
	var original = JSON.stringify(app.store.data)
	app.controls_page()
	var panel = app.screen.find_children("*","VBoxContainer",true,false).filter(func(node): return node.has_method("start_capture"))[0]
	check(panel.config.profiles[panel.config.active_profile].players.size() == 2,"Player tem a mesma interface para dois jogadores")
	var event = InputEventKey.new()
	event.keycode = KEY_Z
	event.physical_keycode = KEY_Z
	event.pressed = true
	panel.start_capture("heavy_punch")
	check(panel.capture_event(event),"Player captura novo comando")
	var pause_event = InputEventKey.new()
	pause_event.keycode = KEY_P
	pause_event.physical_keycode = KEY_P
	pause_event.pressed = true
	panel.start_capture("pause")
	panel.capture_event(pause_event)
	check(panel.save_config() and FileAccess.file_exists(app.control_preferences_path),"Salvar Player escreve preferências pessoais")
	check(JSON.stringify(app.store.data) == original,"Preferências não alteram padrões globais do projeto")
	var saved = Controls.load_preferences(app.control_preferences_path,Controls.defaults())
	check(saved.profiles[saved.active_profile].players[0].keyboard.heavy_punch == KEY_Z and saved.profiles[saved.active_profile].players[0].keyboard.pause == KEY_P,"Preferências persistem no formato compartilhado")
	app.control_settings = saved
	app.start_match("teste_aurora","teste_torquato","training")
	app.combat.set_physics_process(false)
	check(app.combat.input_system.config.profiles[saved.active_profile].players[0].keyboard.heavy_punch == KEY_Z,"Treinamento usa o comando personalizado")
	app._unhandled_input(pause_event)
	check(app.combat.paused and app.overlay != null,"Nova tecla abre pausa na luta real")
	app.pause_match()
	check(not app.combat.paused,"Retomar mantém funcionamento anterior")
	app.main_menu()
	app.controls_page()
	panel = app.screen.find_children("*","VBoxContainer",true,false).filter(func(node): return node.has_method("start_capture"))[0]
	check(panel.config.profiles[panel.config.active_profile].players[0].keyboard.heavy_punch == KEY_Z,"Reabrir configurações exibe o comando salvo")
	panel.restore_defaults()
	panel.save_config()
	check(FileAccess.file_exists(app.control_preferences_path+".bak"),"Preferências conservam backup anterior")
	var file = FileAccess.open(app.control_preferences_path,FileAccess.WRITE)
	file.store_string("{corrompido")
	file.close()
	check(Controls.load_preferences(app.control_preferences_path,Controls.defaults()).profiles[saved.active_profile].players[0].keyboard.heavy_punch == KEY_Z,"Arquivo pessoal inválido recupera último backup válido")
	app.queue_free()
	await process_frame
	print("PLAYER CONTROLS UI TESTS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
