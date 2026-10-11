extends SceneTree
const App = preload("res://tests/dialog_fixture.gd")
const Store = preload("res://runtime/content_store.gd")
const Controls = preload("res://runtime/controls_config.gd")
const ControlsPanel = preload("res://runtime/controls_panel.gd")
const InputSystem = preload("res://runtime/input_system.gd")
const Library = preload("res://editor/resource_library.gd")
const History = preload("res://editor/release_history.gd")
var passed = 0
var failed = 0
var app: Control

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: "+title)

func key(code: int, pressed: bool = true) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func run() -> void:
	app = App.new()
	root.add_child(app)
	root.size = Vector2i(1366,768)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.store.load_file(app.workspace.path_join("player/tests/fixtures/project.json"))
	app.store.path = "user://ux_test_%d/project.json" % Time.get_ticks_usec()
	app.store.data = app.store.data.duplicate(true)
	app.store.data.project_version = "0.3.0"
	app.reset_history()
	for entry in app.NAVIGATION:
		app.show_page(entry[0])
		await process_frame
		await process_frame
		check(app.page.get_child_count() > 2,"Módulo principal: "+entry[1])
		var shell = app.get_children().filter(func(node): return node is VBoxContainer)[0]
		check(shell.get_combined_minimum_size().x <= 1366,"Layout cabe em 1366 pixels: "+entry[1])
	root.size = Vector2i(1920,1080)
	app.show_page("Dashboard")
	await process_frame
	await process_frame
	check(app.page.size.x > 1400,"Layout utiliza o espaço adicional em 1920 pixels")
	root.size = Vector2i(1366,768)
	check(app.nav_buttons.size() == 11,"Onze módulos diretamente acessíveis")
	app.show_page("Personagens")
	var tabs = app.page.find_children("*","TabContainer",true,false)[0]
	check(tabs.get_tab_count() == 8,"Oito abas de personagem")
	app.store.data.characters[0].description += " trabalho em curso"
	app.modified()
	app.show_page("Biblioteca")
	check(app.dirty and app.store.data.characters[0].description.ends_with("trabalho em curso"),"Navegação preserva edição pendente")
	app.request_close()
	var dialogs = app.find_children("*","ConfirmationDialog",true,false)
	check(dialogs.size() == 1 and dialogs[0].title == "Alterações não salvas","Fechar solicita preservação do trabalho")
	dialogs[0].canceled.emit()
	await process_frame
	await test_controls()
	await test_library()
	app.queue_free()
	await process_frame
	print("UX TESTS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)

func test_controls() -> void:
	var config = Controls.defaults()
	check(Controls.validate(config).is_empty(),"Padrões de teclado e gamepad válidos")
	check(Controls.validate(JSON.parse_string(JSON.stringify(config))).is_empty(),"Controles compatíveis com números de JSON")
	var invalid = config.duplicate(true)
	invalid.profiles[invalid.active_profile].players[1].keyboard.light_punch = KEY_J
	check(not Controls.validate(invalid).is_empty(),"Conflito de teclado entre jogadores é detectado")
	invalid = config.duplicate(true)
	invalid.profiles[invalid.active_profile].players[0].gamepad.light_punch = invalid.profiles[invalid.active_profile].players[0].gamepad.heavy_punch
	check(not Controls.validate(invalid).is_empty(),"Comando gamepad duplicado é rejeitado")
	invalid = config.duplicate(true)
	invalid.profiles[invalid.active_profile].players[0].deadzone = NAN
	check(not Controls.validate(invalid).is_empty(),"Zona morta não finita é rejeitada")
	app.show_page("Controles")
	var panel = app.controls_panel
	panel.start_capture("heavy_punch")
	check(panel.capture_event(key(KEY_Z)),"Captura de tecla real pelo formulário")
	check(app.store.data.controls.profiles[config.active_profile].players[0].keyboard.heavy_punch == KEY_Z,"Studio recebe remapeamento P1")
	panel.player_index = 1
	panel.build()
	panel.start_capture("heavy_punch")
	panel.capture_event(key(KEY_C))
	check(panel.config.profiles[config.active_profile].players[0].keyboard.heavy_punch == KEY_Z and panel.config.profiles[config.active_profile].players[1].keyboard.heavy_punch == KEY_C,"P2 independente de P1")
	check(panel.save_config() and FileAccess.file_exists(app.store.path),"Salvar controles persiste no projeto")
	var loaded = Store.new()
	check(loaded.load_file(app.store.path) and int(loaded.data.controls.profiles[config.active_profile].players[0].keyboard.heavy_punch) == KEY_Z and int(loaded.data.controls.profiles[config.active_profile].players[1].keyboard.heavy_punch) == KEY_C,"Leitura compartilhada mantém o remapeamento")
	var system = InputSystem.new()
	system.key_reader = Input.is_key_pressed # Headless lacks the desktop physical-layout adapter.
	check(system.configure(panel.config),"Sistema de entrada usa configuração do Studio")
	Input.parse_input_event(key(KEY_Z))
	Input.flush_buffered_events()
	check("heavy_punch" in system.poll(0).actions and system.poll(0).actions.is_empty(),"Tecla remapeada gera ataque uma vez por pressão")
	Input.parse_input_event(key(KEY_Z,false))
	Input.flush_buffered_events()
	system.poll(0)
	Input.parse_input_event(key(KEY_C))
	Input.flush_buffered_events()
	check("heavy_punch" in system.poll(1).actions and system.poll(0).actions.is_empty(),"Entrada P2 não dispara P1")
	Input.parse_input_event(key(KEY_C,false))
	Input.flush_buffered_events()
	Controls.install_menu_bindings(panel.config)
	check(InputMap.action_get_events("ui_accept").size() >= 3,"Teclado e gamepad habilitam navegação dos menus")
	var player: Dictionary = panel.config.profiles[config.active_profile].players[0]
	player.keyboard.pause = KEY_P
	check(Controls.event_matches(key(KEY_P),player,"pause",0) and not Controls.event_matches(key(KEY_ESCAPE),player,"pause",0),"Pausa acompanha remapeamento")
	panel.restore_defaults()
	check(panel.config.profiles[config.active_profile].players[0].keyboard.heavy_punch == KEY_K,"Restaurar padrões recupera comandos")
	panel.new_profile()
	var profile_dialog = panel.find_children("*","ConfirmationDialog",true,false).filter(func(d): return d.title == "Novo perfil de controles")[0]
	profile_dialog.find_children("*","LineEdit",true,false)[0].text = "Arcade de teste"
	profile_dialog.confirmed.emit()
	check(panel.config.active_profile == "Arcade de teste" and panel.config.profiles.size() == 2,"Novo perfil funcional")
	await process_frame
	panel.device_kind = "gamepad"
	panel.build()
	panel.refresh_monitor()
	check(panel.devices_label.text.contains("Nenhum gamepad") if Input.get_connected_joypads().is_empty() else panel.devices_label.text.contains("Conectados:"),"Monitor descreve os dispositivos realmente conectados")
	panel.start_capture("heavy_punch")
	var event = InputEventJoypadButton.new()
	event.device = 31
	event.button_index = 16
	event.pressed = true
	panel.capture_event(event)
	check(panel.config.profiles[panel.config.active_profile].players[1].gamepad.heavy_punch.button == 16,"Captura de evento de gamepad para P2")
	panel.config.profiles[panel.config.active_profile].players[1].device = 31
	system.configure(panel.config)
	system.device_reader = func(_player,index): return 31 if index == 1 else -1
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	check("heavy_punch" in system.poll(1).actions,"Evento sintético de gamepad configurado produz comando de combate")
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	Input.flush_buffered_events()
	check(Controls.device_for(panel.config.profiles[panel.config.active_profile].players[1],1) == -1 if 31 not in Input.get_connected_joypads() else true,"Dispositivo desconectado não é atribuído automaticamente")
	panel.restore_defaults()
	panel.save_config()
	print("Hardware físico conectado: "+str(Input.get_connected_joypads())+"; teste virtual não certifica USB/Bluetooth físico.")

func test_library() -> void:
	var folder = ProjectSettings.globalize_path(app.store.path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(folder)
	var image = Image.create(64,32,false,Image.FORMAT_RGBA8)
	image.fill(Color("#8ab7ff"))
	var image_path = folder.path_join("arte-original.png")
	image.save_png(image_path)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes = PackedByteArray()
	bytes.resize(4410)
	stream.data = bytes
	var audio_path = folder.path_join("som-original.wav")
	stream.save_to_wav(audio_path)
	app.open_library_for("character",app.store.data.characters[0].id,1)
	var panel = app.resource_panel
	check(panel.select_file(image_path) and panel.preview_image.texture != null and panel.info.width == 64 and panel.info.height == 32,"Prévia visual e dimensões reais")
	check(panel.category.selected == 1 and panel.target.get_item_metadata(panel.target.selected).id == app.store.data.characters[0].id,"Seleção de arquivo mantém categoria e vínculo pré-selecionados")
	panel.metadata = {"name":"Arte de teste","source":"Fixture original","license":"Autoria própria","authorization":"Uso nos testes"}
	check(panel.import_selected() and panel.progress.value == 100,"Importação completa sinaliza progresso real")
	var entry: Dictionary = app.store.data.library[0]
	check(app.store.data.characters[0].sprite == entry.file and FileAccess.file_exists(app.store.asset_path(entry.file)),"Vínculo de sprite corresponde ao arquivo copiado")
	check(Library.dependencies(app.store.data,entry.file).size() == 1,"Biblioteca identifica dependência de personagem")
	check(not panel.library.remove(app.store.data,entry.id),"Recurso em uso não pode ser excluído")
	panel.request_remove(entry)
	var dialog = panel.find_children("*","ConfirmationDialog",true,false)[0]
	check(dialog.get_ok_button().disabled and "em uso" in dialog.dialog_text,"Exclusão mostra dependências e bloqueia confirmação")
	dialog.canceled.emit()
	await process_frame
	panel.search.text = "inexistente"
	panel.populate()
	check(panel.list.item_count == 0,"Pesquisa filtra biblioteca sem perder recursos")
	panel.search.text = "Arte"
	panel.populate()
	check(panel.list.item_count == 1,"Pesquisa localiza recurso pelo nome")
	panel.search.text = ""
	panel.select_file(audio_path)
	panel.play_preview()
	check(app.audio.get_children().any(func(node): return node is AudioStreamPlayer and node.stream != null),"Prévia de áudio utiliza stream decodificado")
	panel.stop_audio()
	panel.category.select(2)
	panel.refresh_targets()
	for index in panel.target.item_count:
		if panel.target.get_item_metadata(index).type == "arena":
			panel.target.select(index)
			break
	panel.refresh_slots()
	panel.metadata = {"name":"Música de teste","source":"PCM original","license":"Autoria própria","authorization":"Uso nos testes"}
	check(panel.import_selected(),"Importação e associação de música a uma arena")
	check(not app.store.data.arenas[0].music.is_empty() and app.store.validate_distribution().is_empty(),"Imagem e áudio licenciados passam na validação de distribuição")
	var before = app.store.data.library.size()
	check(panel.library.import_file(audio_path,app.store.path.get_base_dir(),"Músicas",panel.metadata,app.store.data).size() > 0 and app.store.data.library.size() == before,"Importar os mesmos bytes não duplica arquivo")
	var file = FileAccess.open(folder.path_join("rejeitado.txt"),FileAccess.WRITE)
	file.store_string("Formato incompatível")
	file.close()
	check(not panel.select_file(folder.path_join("rejeitado.txt")) and not panel.library.error.is_empty(),"Formato incompatível apresenta erro e não entra na biblioteca")
	check(app.save_project(),"Biblioteca, licenças e vínculos persistem")
	var loaded = Store.new()
	check(loaded.load_file(app.store.path) and loaded.data.library.size() == 2,"Biblioteca sobrevive à reabertura do projeto")
	var sprite_license = app.store.data.characters[0].sprite_license.duplicate(true)
	app.store.data.characters[0].sprite_license = {}
	var before_snapshot = JSON.stringify(app.store.data)
	var snapshot = app.store.distribution_snapshot(true)
	check(snapshot.data.characters[0].sprite.is_empty() and snapshot.omitted.size() == 1,"Opção explícita omite imagem sem licença da compilação")
	check(JSON.stringify(app.store.data) == before_snapshot,"Omissão não altera arquivo nem vínculo no projeto")
	check(app.store.distribution_snapshot().data.characters[0].sprite == entry.file,"Exportação padrão mantém recurso e exige licença")
	app.store.data.characters[0].sprite_license = sprite_license
	check(panel.library.link(app.store.data,entry,"arena",app.store.data.arenas[0].id,"crowd"),"Imagem pode ser vinculada como elemento de plateia")
	var arena_view = load("res://runtime/arena_system.gd").new()
	arena_view.setup(app.store.data.arenas[0],app.store.path.get_base_dir())
	check(arena_view.crowd_textures.size() == 1,"Plateia importada é carregada pelo renderer real")
	arena_view.free()
	check(Library.dependencies(app.store.data,entry.file).size() == 2,"Dependência de plateia aparece na biblioteca")
	var uses = JSON.stringify(app.store.data)
	Library.unlink(app.store.data,entry.file)
	check(app.store.data.characters[0].sprite.is_empty() and app.store.data.arenas[0].crowd.is_empty() and Library.dependencies(app.store.data,entry.file).is_empty(),"Desvinculação libera usos sem excluir os bytes")
	app.store.data = JSON.parse_string(uses)
	var sound: Dictionary = app.store.data.library[1]
	app.store.data.arenas[0].music = ""
	check(panel.library.remove(app.store.data,sound.id) and FileAccess.file_exists(app.store.asset_path(sound.file)),"Remoção sem dependências mantém bytes para backups")
	check(History.prepare_steam(folder,app.store.data).success == false,"Preparação Steam exige compilação atual verificada")
