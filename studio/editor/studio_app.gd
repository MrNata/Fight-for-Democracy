extends Control
const Store = preload("res://runtime/content_store.gd")
const Campaign = preload("res://runtime/campaign_system.gd")
const UI = preload("res://runtime/ui_kit.gd")
const Preview = preload("res://editor/fighter_preview.gd")
const Timeline = preload("res://editor/move_timeline.gd")
const Exporter = preload("res://editor/export_manager.gd")
const Audio = preload("res://runtime/audio_system.gd")
const Importer = preload("res://editor/catalog_importer.gd")
const StudioTheme = preload("res://editor/studio_theme.gd")
const ResourcePanel = preload("res://editor/resource_panel.gd")
const Controls = preload("res://runtime/controls_config.gd")
const ControlsPanel = preload("res://runtime/controls_panel.gd")
const PublicationPanel = preload("res://editor/publication_panel.gd")
var store = Store.new()
var workspace = ""
var engine_path = ""
var dirty = false
var selected = 0
var section = "Dashboard"
var page: VBoxContainer
var status_label: Label
var project_label: Label
var preview: Control
var exporter: Node
var audio: Node
var arguments: Dictionary = {}
var capture_frames = 0
var selected_move = "light_punch"
var route_faction = 0
var route: Array = []
var selected_arena = 0
var undo_stack: Array = []
var redo_stack: Array = []
var last_snapshot: Dictionary = {}
var saved_snapshot = ""
var import_candidate: Dictionary = {}
var import_base = ""
var import_summary = ""
var nav_buttons: Dictionary = {}
var resource_panel: Control
var controls_panel: Control
var character_tab = 0
var quick_search: LineEdit
var errors_text = ""
var settings_file = "user://studio_settings.cfg"
const NAVIGATION = [
	["Dashboard","Painel inicial"],["Personagens","Personagens"],["Golpes","Golpes e combate"],
	["Biblioteca","Biblioteca de recursos"],["Áudio","Áudio e músicas"],["Arenas","Arenas"],
	["Campanha","Campanhas"],["Controles","Configuração de controles"],["Testador","Testes"],
	["Publicação","Publicação e atualizações"],["Configurações","Configurações"]]


func _ready() -> void:
	theme = StudioTheme.create()
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		var pieces = arg.trim_prefix("--").split("=",true,1)
		arguments[pieces[0]] = pieces[1] if pieces.size() > 1 else "true"
	if arguments.has("capture-size"):
		var dimensions = str(arguments["capture-size"]).split("x")
		if dimensions.size() == 2:
			get_window().content_scale_size = Vector2i(int(dimensions[0]),int(dimensions[1]))
			get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	workspace = str(arguments.get("workspace",ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("../..").simplify_path()))
	engine_path = workspace.path_join("tools/godot/Godot_v4.7.2-stable_win64_console.exe")
	store.load_file(str(arguments.get("content",workspace.path_join("content/project.json"))))
	if not store.data.is_empty() and not store.data.has("project_version"):
		store.data.project_version = "0.3.0"
	if not store.data.is_empty() and not store.data.has("release_notes"):
		store.data.release_notes = "Reformulação do Developer Studio, biblioteca, controles e publicação."
	reset_history()
	exporter = Exporter.new()
	add_child(exporter)
	exporter.completed.connect(func(success,message): report(message,not success))
	audio = Audio.new()
	add_child(audio)
	audio.root = store.path.get_base_dir()
	build_shell()
	var settings = ConfigFile.new()
	settings.load(settings_file)
	show_page(str(arguments.get("section",settings.get_value("studio","last_section","Dashboard") if not arguments.has("no-preferences") else "Dashboard")))
	if section == "Biblioteca" and arguments.has("preview-resource"):
		resource_panel.select_file(str(arguments["preview-resource"]))
	if not store.errors.is_empty():
		report("\n".join(store.errors),true)

func build_shell() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = StudioTheme.BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",0)
	add_child(root)
	var header_panel = PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel",StudioTheme.box("#111824","#283348"))
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	var identity = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(studio_label("Fight for Democracy",20))
	project_label = studio_label("",13,UI.MUTED)
	identity.add_child(project_label)
	header.add_child(identity)
	quick_search = LineEdit.new()
	quick_search.placeholder_text = "Buscar personagem · Enter"
	quick_search.custom_minimum_size.x = 250
	quick_search.tooltip_text = "Abra a ficha de um personagem pelo nome ou ID."
	quick_search.text_submitted.connect(quick_find_character)
	header.add_child(quick_search)
	var undo_button = action_button("↶",undo_edit)
	undo_button.tooltip_text = "Desfazer · Ctrl+Z"
	header.add_child(undo_button)
	var redo_button = action_button("↷",redo_edit)
	redo_button.tooltip_text = "Refazer · Ctrl+Y / Ctrl+Shift+Z"
	header.add_child(redo_button)
	var save = action_button("Salvar",save_project)
	save.tooltip_text = "Salvar projeto e preservar backup · Ctrl+S"
	header.add_child(save)
	header.add_child(action_button("▶ Testar Player",test_game))
	var publish = action_button("Gerar versão",func(): show_page("Publicação"))
	publish.add_theme_stylebox_override("normal",StudioTheme.box("#294d7b","#547fac"))
	publish.tooltip_text = "Abrir publicação, validação e histórico de compilações."
	header.add_child(publish)
	header_panel.add_child(UI.margins(header,14))
	root.add_child(header_panel)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",0)
	root.add_child(body)
	var rail_panel = PanelContainer.new()
	rail_panel.custom_minimum_size.x = 240
	rail_panel.add_theme_stylebox_override("panel",StudioTheme.box("#111824","#283348"))
	body.add_child(rail_panel)
	var rail_scroll = ScrollContainer.new()
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_panel.add_child(rail_scroll)
	var rail = VBoxContainer.new()
	rail.custom_minimum_size.x = 214
	rail.add_theme_constant_override("separation",5)
	rail_scroll.add_child(UI.margins(rail,12))
	rail.add_child(studio_label("FFD  /  DEVELOPER STUDIO",14,StudioTheme.ACCENT))
	rail.add_child(studio_label("PROJETO LOCAL",11,UI.MUTED))
	for item in NAVIGATION:
		var control = action_button(item[1],func(): show_page(item[0]))
		control.icon = StudioTheme.icon(item[0])
		control.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		control.alignment = HORIZONTAL_ALIGNMENT_LEFT
		control.add_theme_font_size_override("font_size",14)
		control.custom_minimum_size.y = 42
		control.tooltip_text = item[1]
		control.add_theme_stylebox_override("normal",StudioTheme.box("#111824","#111824"))
		nav_buttons[item[0]] = control
		rail.add_child(control)
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 14
	rail.add_child(spacer)
	rail.add_child(studio_label("STUDIO 0.3  ·  OFFLINE",11,UI.MUTED))
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation",16)
	var content_margin = UI.margins(page,24)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_margin)
	status_label = studio_label("Pronto. Seu projeto permanece neste computador.",14,UI.MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible = 2
	status_label.custom_minimum_size.y = 22
	root.add_child(UI.margins(status_label,10))
	update_title()

func report(message: String, failure: bool = false) -> void:
	status_label.text = message
	status_label.tooltip_text = message
	status_label.add_theme_color_override("font_color",Color("#efaaaa") if failure else StudioTheme.ACCENT)
	if failure:
		errors_text = message
	print(message)

func update_title() -> void:
	project_label.text = "v%s  ·  %s  ·  %s" % [store.data.get("project_version","0.3.0"),store.path.get_file(),"Alterações não salvas" if dirty else "Todas as alterações salvas"]

func modified() -> void:
	if JSON.stringify(last_snapshot) != JSON.stringify(store.data):
		undo_stack.append(last_snapshot.duplicate(true))
		if undo_stack.size() > 30:
			undo_stack.pop_front()
		redo_stack.clear()
		last_snapshot = store.data.duplicate(true)
	dirty = JSON.stringify(store.data) != saved_snapshot
	update_title()

func reset_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	last_snapshot = store.data.duplicate(true)
	saved_snapshot = JSON.stringify(store.data)
	dirty = false

func undo_edit() -> void:
	if undo_stack.is_empty():
		report("Nenhuma alteração para desfazer.")
		return
	redo_stack.append(store.data.duplicate(true))
	store.data = undo_stack.pop_back()
	restore_history_view("Alteração desfeita. Ctrl+Y refaz.")

func redo_edit() -> void:
	if redo_stack.is_empty():
		report("Nenhuma alteração para refazer.")
		return
	undo_stack.append(store.data.duplicate(true))
	store.data = redo_stack.pop_back()
	restore_history_view("Alteração refeita.")

func restore_history_view(message: String) -> void:
	last_snapshot = store.data.duplicate(true)
	dirty = JSON.stringify(store.data) != saved_snapshot
	selected = mini(selected,store.data.characters.size()-1)
	selected_arena = mini(selected_arena,store.data.arenas.size()-1)
	route.clear()
	update_title()
	show_page(section)
	report(message)

func _input(event: InputEvent) -> void:
	if controls_panel != null and is_instance_valid(controls_panel) and not controls_panel.capture_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			if event.shift_pressed:
				redo_edit()
			else:
				undo_edit()
		elif event.keycode == KEY_Y:
			redo_edit()
		elif event.keycode == KEY_S:
			save_project()
		else:
			return
		get_viewport().set_input_as_handled()

func show_page(title: String) -> void:
	var aliases = {"Painel inicial":"Dashboard","Golpes e combate":"Golpes","Biblioteca de recursos":"Biblioteca","Áudio e músicas":"Áudio","Campanhas":"Campanha","Configuração de controles":"Controles","Testes":"Testador","Publicação e atualizações":"Publicação"}
	title = aliases.get(title,title)
	section = title
	UI.clear(page)
	preview = null
	resource_panel = null
	controls_panel = null
	var heading = title
	for item in NAVIGATION:
		if item[0] == title:
			heading = item[1]
	for id in nav_buttons:
		nav_buttons[id].add_theme_stylebox_override("normal",StudioTheme.box("#253c5b","#39577d") if id == title else StudioTheme.box("#111824","#111824"))
	page.add_child(studio_label("PROJETO  /  " + heading.to_upper(),11,UI.MUTED))
	page.add_child(studio_label(heading,28))
	if not arguments.has("no-preferences"):
		var settings = ConfigFile.new()
		settings.set_value("studio","last_section",title)
		settings.save(settings_file)
	if store.data.is_empty():
		page.add_child(studio_label("Abra um projeto para começar.",20))
		page.add_child(action_button("Abrir projeto",open_project))
		return
	match title:
		"Dashboard": dashboard()
		"Personagens": characters_page()
		"Golpes": moves_page()
		"Biblioteca": library_page()
		"Áudio": audio_page()
		"Arenas": arenas_page()
		"Campanha": campaign_page()
		"Chefes": bosses_page()
		"Economia": economy_page()
		"História": story_page()
		"Menus": menus_page()
		"Testador": tester_page()
		"Controles": controls_page()
		"Publicação": publication_page()
		"Configurações": settings_page()

func card(parent: Node) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(UI.margins(box,16))
	return box

func text_field(parent: Node, title: String, object: Dictionary, key: String, multiline: bool = false, refresh: bool = false) -> Control:
	parent.add_child(studio_label(title,17,UI.MUTED))
	if multiline:
		var input = TextEdit.new()
		input.text = str(object.get(key,""))
		input.custom_minimum_size.y = 110
		input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		input.text_changed.connect(func(): object[key] = input.text; modified())
		parent.add_child(input)
		return input
	var input = LineEdit.new()
	input.text = str(object.get(key,""))
	input.text_changed.connect(func(value):
		object[key] = value
		modified()
		if refresh:
			refresh_preview()
	)
	parent.add_child(input)
	return input

func number_field(parent: Node, title: String, object: Dictionary, key: String, low: float, high: float, step: float = 1.0, refresh: bool = false) -> SpinBox:
	var row = HBoxContainer.new()
	var label = studio_label(title,17,UI.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var spin = SpinBox.new()
	spin.custom_minimum_size.x = 144
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = float(object.get(key,low))
	spin.value_changed.connect(func(value):
		object[key] = int(value) if step >= 1.0 else value
		modified()
		if refresh:
			refresh_preview()
	)
	row.add_child(spin)
	parent.add_child(row)
	return spin

func color_field(parent: Node, title: String, object: Dictionary, key: String) -> void:
	var row = HBoxContainer.new()
	var label = studio_label(title,17,UI.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(110,38)
	picker.color = Color(object.get(key,"#65d6a0"))
	picker.color_changed.connect(func(value): object[key] = "#"+value.to_html(false); modified(); refresh_preview())
	row.add_child(picker)
	parent.add_child(row)

func choice_field(parent: Node, title: String, object: Dictionary, key: String, values: Array, names: Array = []) -> OptionButton:
	parent.add_child(studio_label(title,17,UI.MUTED))
	var selector = OptionButton.new()
	for i in values.size():
		selector.add_item(str(values[i]) if names.is_empty() else str(names[i]))
		if values[i] == object.get(key):
			selector.select(i)
	selector.item_selected.connect(func(index): object[key] = values[index]; modified(); refresh_preview())
	parent.add_child(selector)
	return selector

func check_field(parent: Node, title: String, object: Dictionary, key: String) -> void:
	var check = CheckBox.new()
	check.text = title
	check.button_pressed = bool(object.get(key,false))
	check.toggled.connect(func(value): object[key] = value; modified())
	parent.add_child(check)

func dashboard() -> void:
	page.add_child(studio_label("Um espaço para editar, testar e preparar a próxima versão.",17,UI.MUTED))
	var metrics = HBoxContainer.new()
	metrics.add_theme_constant_override("separation",12)
	for item in [[str(store.data.characters.size()),"PERSONAGENS"],[str(store.data.arenas.size()),"ARENAS"],["4","CAMPANHAS"],[str(store.data.get("project_version","0.3.0")),"VERSÃO DO PROJETO"]]:
		var box = card(metrics)
		box.add_child(studio_label(item[0],28,StudioTheme.ACCENT))
		box.add_child(studio_label(item[1],11,UI.MUTED))
	page.add_child(metrics)
	var shortcuts = card(page)
	shortcuts.add_child(studio_label("Continue seu trabalho",21))
	shortcuts.add_child(studio_label("Os dados são preservados ao trocar de seção. Salve antes de testar ou gerar uma versão.",15,UI.MUTED))
	var actions = HFlowContainer.new()
	actions.add_theme_constant_override("separation",10)
	for pair in [["Editar personagens","Personagens"],["Importar recursos","Biblioteca"],["Configurar controles","Controles"],["Gerar nova versão","Publicação"]]:
		actions.add_child(action_button(pair[0],func(): show_page(pair[1])))
	shortcuts.add_child(actions)
	var project = card(page)
	project.add_child(studio_label("Projeto de autoria",21))
	project.add_child(studio_label(store.path,14,UI.MUTED))
	var files = HFlowContainer.new()
	files.add_theme_constant_override("separation",8)
	for pair in [["Abrir projeto",open_project],["Criar projeto",create_project],["Salvar como",save_as],["Backup",backup_project],["Restaurar backup",restore_backup]]:
		files.add_child(action_button(pair[0],pair[1]))
	project.add_child(files)
	project.add_child(action_button("Validar conteúdo e carreiras",validate_all))
	var catalog = card(page)
	catalog.add_child(studio_label("Catálogo e campanhas",21))
	catalog.add_child(studio_label("Importe um pacote de dados com prévia e validação; os IDs existentes permanecem preservados.",15,UI.MUTED))
	catalog.add_child(action_button("Importar catálogo de 156 personagens / quatro rotas",import_catalog))
	catalog.add_child(action_button("Exportar modelo de importação com os IDs atuais",export_import_template))
	var tools_box = card(page)
	tools_box.add_child(studio_label("Estado do desenvolvimento",21))
	var text = studio_label("Arte e golpes de base temporários. Chefes cinematográficos e o catálogo externo completo continuam em desenvolvimento.",15,UI.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_box.add_child(text)

func characters_page() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	page.add_child(row)
	var catalog = VBoxContainer.new()
	catalog.custom_minimum_size.x = 225
	row.add_child(catalog)
	var search = LineEdit.new()
	search.placeholder_text = "Nome, ID ou facção…"
	catalog.add_child(search)
	var list = ItemList.new()
	list.custom_minimum_size = Vector2(225,400)
	catalog.add_child(list)
	var populate = func(filter_text: String):
		list.clear()
		for i in store.data.characters.size():
			var character: Dictionary = store.data.characters[i]
			if not filter_text.is_empty() and not (character.name+" "+character.id+" "+character.faction).to_lower().contains(filter_text.to_lower()):
				continue
			list.add_item(character.name)
			list.set_item_tooltip(list.item_count-1,character.name+"\n"+character.id)
			list.set_item_metadata(list.item_count-1,i)
			if i == selected:
				list.select(list.item_count-1)
	populate.call("")
	search.text_changed.connect(populate)
	list.item_selected.connect(func(index): selected = list.get_item_metadata(index); show_page("Personagens"))
	catalog.add_child(action_button("Duplicar personagem",add_character))
	catalog.add_child(action_button("Excluir personagem…",confirm_remove_character))
	var detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var character: Dictionary = store.data.characters[selected]
	detail.add_child(studio_label(character.name,21))
	detail.add_child(studio_label(character.id+"  ·  "+character.faction,13,StudioTheme.ACCENT))
	var tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 450
	var viewport = get_viewport()
	var resize = func():
		tabs.custom_minimum_size.y = maxf(450,viewport.get_visible_rect().size.y-425)
		list.custom_minimum_size.y = maxf(400,viewport.get_visible_rect().size.y-410)
	viewport.size_changed.connect(resize)
	tabs.tree_exiting.connect(func():
		if viewport.size_changed.is_connected(resize):
			viewport.size_changed.disconnect(resize)
	)
	resize.call()
	detail.add_child(tabs)
	var forms: Dictionary = {}
	for name in ["Aparência","Atributos","Animações","Golpes","Vozes","Finalizações","IA","Pré-visualização"]:
		var scroll = ScrollContainer.new()
		scroll.name = name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation",10)
		var margin = UI.margins(box,14)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(margin)
		tabs.add_child(scroll)
		forms[name] = box
	tabs.current_tab = character_tab
	tabs.tab_changed.connect(func(index): character_tab = index)
	var form: VBoxContainer = forms["Aparência"]
	text_field(form,"Nome",character,"name")
	choice_field(form,"Facção de roteiro",character,"faction",store.data.factions.map(func(f): return f.id),store.data.factions.map(func(f): return f.name))
	text_field(form,"Descrição fictícia",character,"description",true)
	for pair in [["Roupa","clothes"],["Pele","skin"],["Detalhes","accent"]]:
		color_field(form,pair[0],character.palette,pair[1])
	number_field(form,"Variante temporária",character,"appearance",0,3,1,true)
	form.add_child(action_button("Importar sprite / roupa completa",func(): open_library_for("character",character.id,0)))
	form.add_child(action_button("Usar boneco temporário",func(): character.sprite = ""; modified(); refresh_preview()))
	asset_license_fields(form,character,"sprite")
	form = forms["Atributos"]
	for field in [["Vida","health",1,10000,1],["Força","strength",0.1,5,0.05],["Velocidade","speed",50,900,5],["Mobilidade","mobility",0.2,3,0.05],["Defesa","defense",0,0.65,0.01]]:
		number_field(form,field[0],character.stats,field[1],field[2],field[3],field[4],true)
	if not character.has("collision"):
		character.collision = {"width":84,"height":204,"crouch_height":112,"push_width":85}
		modified()
	for field in [["Largura da hurtbox","width"],["Altura da hurtbox","height"],["Altura agachada","crouch_height"],["Colisão corporal","push_width"]]:
		number_field(form,field[0],character.collision,field[1],20,600,1,true)
	check_field(form,"Personagem fictício",character,"fictional")
	check_field(form,"Arte temporária",character,"placeholder")
	check_field(form,"Disponível na campanha",character,"campaign_enabled")
	check_field(form,"Personagem chefe",character,"boss")
	form = forms["Animações"]
	number_field(form,"Colunas do spritesheet",character.animation,"columns",1,64,1,true)
	number_field(form,"Linhas do spritesheet",character.animation,"rows",1,64,1,true)
	number_field(form,"Frames por segundo",character.animation,"fps",1,60,1,true)
	form.add_child(action_button("Importar spritesheet com prévia",func(): open_library_for("character",character.id,1)))
	form.add_child(action_button("Editar trechos por golpe",func(): show_page("Golpes")))
	form = forms["Golpes"]
	for action in Store.ACTIONS:
		var move: Dictionary = character.moves[action]
		form.add_child(action_button(move.name+" · "+str(move.damage)+" de dano",func(): selected_move = action; show_page("Golpes")))
	form = forms["Vozes"]
	var voices_count = 0
	for clips in character.voices.values():
		voices_count += clips.size()
	form.add_child(studio_label("%d arquivos vinculados" % voices_count,17))
	form.add_child(action_button("Editar vozes e bordões",func(): show_page("Áudio")))
	form.add_child(action_button("Importar voz com prévia",func(): open_library_for("character",character.id,4)))
	form = forms["Finalizações"]
	text_field(form,"Nome",character.moves.finisher,"name")
	number_field(form,"Dano",character.moves.finisher,"damage",0,500)
	number_field(form,"Custo de fama",character.moves.finisher,"fame_cost",0,100)
	form.add_child(action_button("Editar frames e colisões",func(): selected_move = "finisher"; show_page("Golpes")))
	form = forms["IA"]
	number_field(form,"Reação em frames",character.ai,"reaction",6,180)
	number_field(form,"Agressividade",character.ai,"aggression",0,1,0.05)
	form.add_child(action_button("Testar contra IA",func(): test_game("ai")))
	form = forms["Pré-visualização"]
	preview = Preview.new()
	form.add_child(preview)
	refresh_preview()
	form.add_child(action_button("▶ Testar golpe na prévia",func(): preview.test_move(selected_move)))
	detail.add_child(action_button("▶ TESTAR PERSONAGEM",func(): test_game("training")))

func asset_license_fields(parent: Node, object: Dictionary, asset_key: String) -> void:
	parent.add_child(studio_label("Licença do recurso: " + asset_key + " (necessária para exportar)",16,UI.MUTED))
	var key = asset_key+"_license"
	var record: Dictionary = object.get(key,{"source":"","license":"","authorization":""})
	for field in [["Origem do recurso","source"],["Licença","license"],["Autorização de distribuição","authorization"]]:
		var input = text_field(parent,field[0],record,field[1])
		input.text_changed.connect(func(_value): object[key] = record; modified())

func refresh_preview() -> void:
	if preview != null and is_instance_valid(preview) and not store.data.is_empty():
		preview.setup(store.data.characters[selected],store.data.arenas[selected_arena if section == "Arenas" else 0],store.path.get_base_dir())

func add_character() -> void:
	var character: Dictionary = store.data.characters[selected].duplicate(true)
	character.id = "custom_%d" % Time.get_ticks_usec()
	character.name = "Novo lutador fictício"
	character.fictional = true
	character.boss = false
	store.data.characters.append(character)
	selected = store.data.characters.size()-1
	modified()
	show_page("Personagens")

func remove_character() -> void:
	var id: String = store.data.characters[selected].id
	for faction in store.data.factions:
		if faction.boss == id:
			report("Troque o chefe na página Campanha antes de remover este personagem.",true)
			return
	for authored in store.data.campaign.routes.values():
		for fight in authored:
			if fight.opponent == id:
				report("Este personagem pertence a uma rota de campanha. Troque o adversário antes de removê-lo.",true)
				return
	if store.data.characters.size() <= 2:
		report("Mantenha pelo menos dois lutadores.",true)
		return
	store.data.characters.remove_at(selected)
	selected = mini(selected,store.data.characters.size()-1)
	modified()
	show_page("Personagens")

func character_selector(parent: Node, target: String) -> void:
	var select = OptionButton.new()
	for character in store.data.characters:
		select.add_item(character.name)
	select.select(selected)
	select.item_selected.connect(func(index): selected = index; show_page(target))
	parent.add_child(select)

func moves_page() -> void:
	character_selector(page,"Golpes")
	var character: Dictionary = store.data.characters[selected]
	var selector = OptionButton.new()
	for key in Store.ACTIONS:
		selector.add_item(character.moves[key].name)
	selector.select(Store.ACTIONS.find(selected_move))
	selector.item_selected.connect(func(index): selected_move = Store.ACTIONS[index]; show_page("Golpes"))
	page.add_child(selector)
	var move: Dictionary = character.moves[selected_move]
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	page.add_child(row)
	var form = card(row)
	text_field(form,"Nome do golpe",move,"name")
	var timeline = Timeline.new()
	timeline.move = move
	form.add_child(timeline)
	for field in [["Início (frames)","startup",1,180],["Atividade (frames)","active",1,120],["Recuperação (frames)","recovery",1,240],["Dano","damage",0,500],["Alcance / hitbox","reach",10,900],["Custo de fama","fame_cost",0,100],["Ganho de fama","fame_gain",0,100],["Stun (frames)","stun",0,120],["Knockback","knockback",0,1500],["Prioridade","priority",0,20],["Recarga (frames)","cooldown",0,600]]:
		var spin = number_field(form,field[0],move,field[1],field[2],field[3])
		spin.value_changed.connect(func(_value): timeline.queue_redraw(); refresh_preview())
	check_field(form,"Projétil",move,"projectile")
	number_field(form,"Velocidade do projétil",move,"projectile_speed",50,1500,10)
	var projectile_width = {"width":move.get("projectile_width",48)}
	var width_spin = number_field(form,"Largura do projétil",projectile_width,"width",8,300)
	width_spin.value_changed.connect(func(value): move.projectile_width = value; modified(); refresh_preview())
	check_field(form,"Ignora defesa (agarrão)",move,"unblockable")
	if not move.has("hitbox"):
		move.hitbox = {"offset_x":25,"offset_y":110 if "kick" in selected_move else 175,"height":65}
		modified()
	form.add_child(studio_label("COLISÃO E ANIMAÇÃO A 60 Hz",18,StudioTheme.ACCENT))
	for field in [["Offset frontal da hitbox","offset_x",0],["Altura da hitbox em relação ao chão","offset_y",0],["Espessura vertical da hitbox","height",1]]:
		number_field(form,field[0],move.hitbox,field[1],field[2],600,1,true)
	check_field(form,"Permitir golpe durante o salto",move,"air_allowed")
	var animation: Dictionary = move.get("animation", {"start":0,"count":int(character.animation.columns)*int(character.animation.rows)})
	for field in [["Primeiro quadro no spritesheet (0 = início)","start",0,4095],["Quantidade de quadros da animação","count",1,4096]]:
		var spin = number_field(form,field[0],animation,field[1],field[2],field[3],1,true)
		spin.value_changed.connect(func(_value): move.animation = animation; modified(); refresh_preview())
	form.add_child(studio_label("O trecho percorre preparação, atividade e recuperação.\nA linha do tempo mostra o mesmo quadro usado no combate.",16,UI.MUTED))
	if not move.has("cancel"):
		move.cancel = {"into":[],"start":0,"end":0,"require_hit":true}
		modified()
	var rules: Dictionary = move.cancel
	form.add_child(studio_label("CANCELAMENTOS PERMITIDOS",18,StudioTheme.ACCENT))
	check_field(form,"Exigir acerto sem defesa",rules,"require_hit")
	number_field(form,"Primeiro frame da recuperação",rules,"start",0,239)
	number_field(form,"Último frame da janela",rules,"end",0,239)
	for action in Store.ACTIONS:
		if action == selected_move:
			continue
		var check = CheckBox.new()
		check.text = character.moves[action].name
		check.button_pressed = action in rules.into
		check.toggled.connect(func(enabled):
			if enabled and action not in rules.into:
				rules.into.append(action)
			elif not enabled:
				rules.into.erase(action)
			modified()
		)
		form.add_child(check)
	var visual = card(row)
	visual.custom_minimum_size.x = 400
	visual.add_child(studio_label("HURTBOX AZUL  /  HITBOX VERMELHA",18,UI.MUTED))
	preview = Preview.new()
	preview.boxes = true
	visual.add_child(preview)
	refresh_preview()
	visual.add_child(action_button("▶ Testar golpe agora",func(): preview.test_move(selected_move)))
	visual.add_child(action_button("Abrir treinamento na Player",func(): test_game("training")))
	timeline.frame_selected.connect(func(frame):
		preview.paused = true
		preview.fighter.fame = 100.0
		preview.fighter.cooldowns.clear()
		preview.fighter.recent_block = preview.fighter.frame
		preview.fighter.begin_attack(selected_move)
		preview.fighter.action_frame = frame
		preview.fighter.queue_redraw()
		report("Linha do tempo: frame %d, a 60 Hz." % frame)
	)
	visual.add_child(studio_label("Modelos reutilizáveis",20))
	for pair in [["Projétil básico","special_a"],["Golpe de alcance","special_b"],["Superespecial","super"]]:
		visual.add_child(action_button("Aplicar modelo: " + pair[0],func():
			character.moves[selected_move] = store.data.characters[0].moves[pair[1]].duplicate(true)
			modified()
			show_page("Golpes")
		))

func audio_page() -> void:
	character_selector(page,"Áudio")
	page.add_child(studio_label("Importe WAV, OGG ou MP3. Registre origem, licença e autorização antes de salvar.",19,UI.MUTED))
	var character: Dictionary = store.data.characters[selected]
	var events = ["entry","intro","attack","special","super","hurt","victory","defeat","finisher","taunt","rival"]
	var event = OptionButton.new()
	for item in events:
		event.add_item(item)
	page.add_child(event)
	var container = VBoxContainer.new()
	page.add_child(container)
	var render = func():
		UI.clear(container)
		var event_id: String = events[event.selected]
		var clips: Array = character.voices.get(event_id,[])
		for index in clips.size():
			var clip: Dictionary = clips[index]
			var form = card(container)
			form.add_child(studio_label(clip.file,16,StudioTheme.ACCENT))
			text_field(form,"Origem",clip,"source")
			text_field(form,"Licença",clip,"license")
			text_field(form,"Autorização de uso",clip,"authorization")
			number_field(form,"Peso de seleção",clip,"weight",0.01,100,0.1)
			number_field(form,"Volume",clip,"volume",0,1,0.01)
			number_field(form,"Intervalo mínimo (segundos)",clip,"interval",0,120,0.1)
			form.add_child(action_button("▶ Ouvir",func(): audio.play_file(clip.file,"Voices",clip.volume)))
			form.add_child(action_button("Remover arquivo do evento…",func(): confirm_change("Remover este áudio do evento? O arquivo continua preservado no projeto.",func(): clips.remove_at(index); modified(); show_page("Áudio"))))
		if clips.is_empty():
			container.add_child(studio_label("Nenhum áudio associado a este evento.",20,UI.MUTED))
	event.item_selected.connect(func(_index): render.call())
	page.add_child(action_button("Importar áudio para o evento selecionado",func():
		var event_id: String = events[event.selected]
		open_library_for("character",character.id,4)
		for index in resource_panel.slot.item_count:
			if resource_panel.slot.get_item_metadata(index) == "voice/"+event_id:
				resource_panel.slot.select(index)
	))
	render.call()

func arenas_page() -> void:
	var selector = OptionButton.new()
	for arena in store.data.arenas:
		selector.add_item(arena.name)
	selector.select(selected_arena)
	page.add_child(selector)
	var content = VBoxContainer.new()
	page.add_child(content)
	var render = func():
		UI.clear(content)
		var arena: Dictionary = store.data.arenas[selector.selected]
		var form = card(content)
		text_field(form,"Nome",arena,"name")
		text_field(form,"Região",arena,"region")
		preview = Preview.new()
		form.add_child(preview)
		preview.setup(store.data.characters[selected],arena,store.path.get_base_dir())
		for pair in [["Céu","sky"],["Piso","floor"],["Detalhe","accent"]]:
			color_field(form,pair[0],arena,pair[1])
		form.add_child(action_button("Importar fundo",func(): open_library_for("arena",arena.id,5)))
		form.add_child(action_button("Importar música",func(): open_library_for("arena",arena.id,2)))
		asset_license_fields(form,arena,"background")
		asset_license_fields(form,arena,"music")
		for layer in arena.get("crowd",[]):
			var box = card(form)
			box.add_child(studio_label("Elemento de plateia · "+str(layer.file).get_file(),14,UI.MUTED))
			for pair in [["Posição X","x"],["Base Y","y"],["Largura","width"],["Altura","height"]]:
				number_field(box,pair[0],layer,pair[1],0 if pair[1] in ["x","y"] else 1,4096,1,true)
		form.add_child(action_button("Importar elemento de plateia",func(): open_library_for("arena",arena.id,6)))
		form.add_child(action_button("Testar arena",func(): test_game("training",arena.id)))
	selector.item_selected.connect(func(index): selected_arena = index; render.call())
	render.call()

func campaign_page() -> void:
	page.add_child(studio_label("Rotas por facção. Uma derrota conserva o adversário; o chefe ocupa o último confronto.",18,UI.MUTED))
	var faction = OptionButton.new()
	for i in store.data.factions.size():
		faction.add_item(store.data.factions[i].name)
	faction.select(route_faction)
	faction.item_selected.connect(func(index): route_faction = index; route.clear(); show_page("Campanha"))
	page.add_child(faction)
	var faction_data: Dictionary = store.data.factions[route_faction]
	text_field(page,"Nome da facção de roteiro",faction_data,"name")
	color_field(page,"Cor da facção",faction_data,"color")
	var boss_select = choice_field(page,"Chefe final da rota",faction_data,"boss",store.data.characters.map(func(c): return c.id),store.data.characters.map(func(c): return c.name))
	boss_select.item_selected.connect(func(_index): store.data.campaign.routes.erase(faction_data.id); route.clear(); show_page("Campanha"))
	var seed_spin = number_field(page,"Semente",store.data.campaign,"seed",0,2147483647)
	seed_spin.value_changed.connect(func(_value): store.data.campaign.routes.clear(); route.clear())
	var rank_row = HFlowContainer.new()
	for rank in store.data.campaign.ranks:
		var box = card(rank_row)
		box.add_child(studio_label(rank.name,13))
		var spin = SpinBox.new()
		spin.min_value = 1
		spin.max_value = 155
		spin.value = rank.fights
		spin.custom_minimum_size.x = 90
		spin.value_changed.connect(func(value): rank.fights = int(value); store.data.campaign.routes.clear(); route.clear(); modified())
		box.add_child(spin)
	page.add_child(rank_row)
	var rank_select = OptionButton.new()
	for rank in store.data.campaign.ranks:
		rank_select.add_item(rank.name)
	page.add_child(rank_select)
	var rank_form = VBoxContainer.new()
	page.add_child(rank_form)
	var render_rank = func():
		UI.clear(rank_form)
		var rank: Dictionary = store.data.campaign.ranks[rank_select.selected]
		text_field(rank_form,"Nome do cargo",rank,"name")
		for definition in [["Dificuldade do cargo","difficulty",7],["Recompensa do cargo","reward",100000]]:
			var field = number_field(rank_form,definition[0],rank,definition[1],0,definition[2])
			field.value_changed.connect(func(_value): store.data.campaign.routes.clear(); route.clear())
	rank_select.item_selected.connect(func(_index): render_rank.call())
	render_rank.call()
	var chosen = ""
	for character in store.data.characters:
		if character.faction == faction_data.id and not character.boss:
			chosen = character.id
			break
	if route.is_empty():
		var generator = Campaign.new()
		route = generator.generate(store.data,chosen,faction_data.id,int(store.data.campaign.seed))
		if route.is_empty():
			page.add_child(studio_label("\n".join(generator.errors),19,Color("#ef8a8a")))
			return
	var list = ItemList.new()
	list.custom_minimum_size.y = 340
	for index in route.size():
		var fight: Dictionary = route[index]
		list.add_item("%03d  %s  /  %s  /  %s  /  IA %d  /  P$ %d" % [index+1,store.data.campaign.ranks[int(fight.rank)].name,store.character(fight.opponent).name,fight.arena,int(fight.difficulty),int(fight.reward)])
	list.select(0)
	page.add_child(list)
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	for pair in [["Mover acima",-1],["Mover abaixo",1]]:
		controls.add_child(action_button(pair[0],func():
			var index = list.get_selected_items()[0]
			var target = index+pair[1]
			if target >= 0 and target < route.size()-1 and index < route.size()-1 and route[index].rank == route[target].rank:
				var previous = route[index]
				route[index] = route[target]
				route[target] = previous
				route_changed()
				show_page("Campanha")
		))
	controls.add_child(action_button("Aplicar rota e validar",func():
		var generator = Campaign.new()
		var problems = generator.validate_schedule(route,store.data,chosen,faction_data.id)
		if problems.is_empty():
			store.data.campaign.routes[faction_data.id] = route.duplicate(true)
			modified()
			report("Rota aplicada e validada.")
		else:
			report("\n".join(problems),true)
	))
	controls.add_child(action_button("Voltar à geração por semente",func(): store.data.campaign.routes.erase(faction_data.id); route.clear(); modified(); show_page("Campanha")))
	page.add_child(controls)
	var edit = card(page)
	var render = func():
		UI.clear(edit)
		var fight: Dictionary = route[list.get_selected_items()[0]]
		if fight.boss:
			edit.add_child(studio_label("Chefe reservado: " + store.character(faction_data.boss).name,20,StudioTheme.ACCENT))
		else:
			var candidates: Array = store.data.characters.filter(func(c): return c.id == fight.opponent or (c.faction != faction_data.id and not c.boss and c.campaign_enabled and not route.any(func(other): return other.opponent == c.id)))
			var opponent = choice_field(edit,"Adversário (sem duplicatas ou chefes)",fight,"opponent",candidates.map(func(c): return c.id),candidates.map(func(c): return c.name))
			opponent.item_selected.connect(func(_index): route_changed())
		var arena = choice_field(edit,"Arena",fight,"arena",store.data.arenas.map(func(a): return a.id),store.data.arenas.map(func(a): return a.name))
		arena.item_selected.connect(func(_index): route_changed())
		var difficulty = number_field(edit,"Dificuldade",fight,"difficulty",0,7)
		difficulty.value_changed.connect(func(_value): route_changed())
		var reward = number_field(edit,"Recompensa",fight,"reward",0,100000)
		reward.value_changed.connect(func(_value): route_changed())
	list.item_selected.connect(func(_index): render.call())
	render.call()

func route_changed() -> void:
	store.data.campaign.routes[store.data.factions[route_faction].id] = route.duplicate(true)
	modified()

func bosses_page() -> void:
	page.add_child(studio_label("Configuração da batalha final e atributos do personagem. Arte e mecânicas cinematográficas ainda temporárias.",19,UI.MUTED))
	var select = OptionButton.new()
	for faction in store.data.factions:
		select.add_item(faction.name)
	select.select(route_faction)
	select.item_selected.connect(func(index): route_faction = index; show_page("Chefes"))
	page.add_child(select)
	var faction: Dictionary = store.data.factions[route_faction]
	var boss: Dictionary = store.character(faction.boss)
	var form = card(page)
	form.add_child(studio_label(boss.name,26,StudioTheme.ACCENT))
	form.add_child(studio_label("ID preservado: " + boss.id,16,UI.MUTED))
	text_field(form,"Nome satírico",boss,"name")
	text_field(form,"Descrição fictícia",boss,"description",true)
	number_field(form,"Vida (também usada no Versus)",boss.stats,"health",1,10000)
	number_field(form,"Força",boss.stats,"strength",0.1,5,0.05)
	number_field(form,"Reação da IA",boss.ai,"reaction",6,180)
	number_field(form,"Agressividade",boss.ai,"aggression",0,1,0.05)
	var arena = choice_field(form,"Arena final da rota",faction,"boss_arena",store.data.arenas.map(func(a): return a.id),store.data.arenas.map(func(a): return a.name))
	arena.item_selected.connect(func(_index):
		if store.data.campaign.routes.has(faction.id):
			store.data.campaign.routes[faction.id][-1].arena = faction.boss_arena
			route.clear()
			modified()
	)
	form.add_child(studio_label("PARADOXO DA URNA-X: invencibilidade somente no último confronto da história da Esquerda.\nNo teste livre e no Versus, dano e KO continuam normais.",19,Color("#ecc96c")))
	form.add_child(action_button("Editar golpes e colisões do chefe",func(): selected = store.data.characters.find(boss); show_page("Golpes")))
	form.add_child(action_button("Testar chefe no modo livre",func(): test_game("ai",str(faction.get("boss_arena",store.data.arenas[-1].id)),boss.id,7)))
	text_field(form,"Encerramento explícito do Paradoxo",store.data.story,"left_ending",true)

func import_catalog() -> void:
	file_picker(FileDialog.FILE_MODE_OPEN_FILE,["*.json ; Catálogo ou campanhas FFD"],func(path):
		if not prepare_import_file(path):
			return
		var dialog = ConfirmationDialog.new()
		dialog.title = "Prévia de importação"
		dialog.dialog_text = import_summary
		dialog.get_ok_button().text = "Aplicar ao projeto"
		add_child(dialog)
		dialog.confirmed.connect(func(): apply_import(); dialog.queue_free())
		dialog.canceled.connect(func(): import_candidate.clear(); dialog.queue_free())
		dialog.popup_centered(Vector2i(720,300))
	)

func prepare_import_file(source: String) -> bool:
	import_candidate.clear()
	var importer = Importer.new()
	if not importer.prepare_file(source,store):
		report("Importação rejeitada; projeto preservado:\n"+"\n".join(importer.errors.slice(0,8)),true)
		return false
	import_candidate = importer.candidate
	import_base = JSON.stringify(store.data)
	import_summary = importer.summary
	report(import_summary)
	return true

func apply_import() -> bool:
	if import_candidate.is_empty() or JSON.stringify(store.data) != import_base:
		report("A prévia expirou. Prepare o pacote novamente para preservar as edições recentes.",true)
		return false
	var problems = store.validate(import_candidate)
	if not problems.is_empty():
		report("Importação rejeitada:\n"+"\n".join(problems.slice(0,8)),true)
		return false
	store.data = import_candidate.duplicate(true)
	import_candidate.clear()
	route.clear()
	modified()
	show_page(section)
	report("Importação aplicada. Desfazer restaura a versão anterior; Salvar grava e cria backup.")
	return true

func export_import_template() -> void:
	if store.data.characters.size() != 156 or not validate_all():
		report("O modelo de importação exige um projeto válido com exatamente 156 registros.",true)
		return
	var routes: Dictionary = {}
	for faction in store.data.factions:
		var chosen = ""
		for character in store.data.characters:
			if character.faction == faction.id and not character.boss and character.campaign_enabled:
				chosen = character.id
				break
		routes[faction.id] = Campaign.new().generate(store.data,chosen,faction.id,int(store.data.campaign.seed))
	file_picker(FileDialog.FILE_MODE_SAVE_FILE,["*.json ; Modelo de catálogo e quatro rotas"],func(path):
		var packet = {"format":"ffd.catalog","version":1,"characters":store.data.characters.duplicate(true),"routes":routes}
		var status = Store.write_atomic(path,packet)
		report("Modelo exportado: "+path if status == OK else "Falha ao exportar modelo: "+error_string(status),status != OK)
	)

func economy_page() -> void:
	var form = card(page)
	number_field(form,"Recompensa base de vitória",store.data.economy,"win_reward",0,100000)
	number_field(form,"Recompensa de derrota",store.data.economy,"loss_reward",0,100000)
	for upgrade in store.data.economy.upgrades:
		var box = card(page)
		text_field(box,"Nome",upgrade,"name")
		number_field(box,"Preço inicial (cresce por nível)",upgrade,"price",1,100000)
		number_field(box,"Limite de níveis",upgrade,"max_level",1,10)
		number_field(box,"Benefício por nível (0.05 = 5%)",upgrade,"effect",0,0.1,0.01)

func story_page() -> void:
	page.add_child(studio_label("Textos consumidos pelo jogo. Paródia fictícia da República da Arena.",20,UI.MUTED))
	for pair in [["Introdução","intro"],["Vitória","victory"],["Derrota","defeat"],["Desfecho especial da Esquerda","left_ending"]]:
		text_field(page,pair[0],store.data.story,pair[1],true)

func menus_page() -> void:
	text_field(page,"Nome do jogo",store.data,"title")
	text_field(page,"Subtítulo",store.data.menu,"subtitle")
	text_field(page,"Créditos",store.data.menu,"credits",true)
	color_field(page,"Cor de destaque",store.data.menu,"accent")
	page.add_child(studio_label("Mixagem inicial da Player Edition",22))
	for bus in Audio.CHANNELS:
		number_field(page,bus,store.data.audio,bus,0,1,0.01)

func tester_page() -> void:
	character_selector(page,"Testador")
	page.add_child(studio_label("Testes abrem outra instância. Treinamento não altera os perfis de carreira.",20,UI.MUTED))
	for pair in [["Testar personagem e hitboxes","training"],["Luta contra IA","ai"],["Multiplayer local","local"],["Simular IA contra IA","simulation"]]:
		page.add_child(action_button(pair[0],func(): test_game(pair[1])))
	page.add_child(action_button("Testar chefe da rota (modo livre)",func():
		var boss: String = store.data.factions[route_faction].boss
		test_game("ai",store.data.arenas[-1].id,boss,7)
	))
	page.add_child(action_button("Validar conteúdo",validate_all))
	page.add_child(studio_label("F1 exibe hitboxes. Esc permite reiniciar. Dados de frame aparecem no treinamento.\nFPS e memória do Studio: %d FPS / %.1f MB" % [Engine.get_frames_per_second(),Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0],20,UI.MUTED))

func save_project() -> bool:
	if not store.save_file():
		report("Salvamento rejeitado:\n"+"\n".join(store.errors),true)
		return false
	dirty = false
	saved_snapshot = JSON.stringify(store.data)
	update_title()
	report("Projeto salvo. Backup anterior: " + store.path + ".bak")
	return true

func validate_all() -> bool:
	var problems = store.validate(store.data)
	if problems.is_empty():
		for i in store.data.factions.size():
			var faction: Dictionary = store.data.factions[i]
			for character in store.data.characters:
				if character.faction != faction.id or character.boss or not character.campaign_enabled:
					continue
				var generator = Campaign.new()
				generator.generate(store.data,character.id,faction.id,int(store.data.campaign.seed))
				for issue in generator.errors:
					problems.append(character.id+": "+issue)
	if not problems.is_empty():
		report("Validação falhou:\n"+"\n".join(problems.slice(0,8)),true)
		return false
	report("Conteúdo válido. Todas as carreiras jogáveis das quatro facções foram verificadas.")
	return true

func test_game(mode: String = "training", arena: String = "praca", opponent: String = "", difficulty: int = 0) -> void:
	if not save_project():
		return
	if not FileAccess.file_exists(engine_path):
		report("Godot não encontrado. Selecione o executável no Dashboard.",true)
		return
	if opponent.is_empty():
		opponent = store.data.characters[40 if selected != 40 else 0].id
	var pid = OS.create_process(engine_path,["--path",workspace.path_join("player"),"--","--content="+store.path,"--controls-file="+workspace.path_join("build/studio-test-controls.json"),"--test-fight","--left="+store.data.characters[selected].id,"--right="+opponent,"--mode="+mode,"--arena="+arena,"--difficulty="+str(difficulty)])
	report("Sessão de teste iniciada, PID %d." % pid if pid > 0 else "Não foi possível iniciar a Godot.",pid <= 0)

func export_game(omit_unlicensed: bool = false) -> void:
	if exporter.busy:
		report("Exportação em andamento.")
		return
	if validate_all() and save_project():
		report("Exportando Player Edition. Aguarde a confirmação do executável.")
		exporter.export_player(store,workspace,engine_path,omit_unlicensed)

func file_picker(mode: int, filters: Array, callback: Callable) -> void:
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(filters)
	dialog.current_dir = store.path.get_base_dir()
	add_child(dialog)
	if mode == FileDialog.FILE_MODE_OPEN_DIR:
		dialog.dir_selected.connect(func(path): callback.call(path); dialog.queue_free())
	else:
		dialog.file_selected.connect(func(path): callback.call(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)

func open_project() -> void:
	file_picker(FileDialog.FILE_MODE_OPEN_FILE,["*.json ; Projeto de conteúdo"],func(path):
		var candidate = Store.new()
		if candidate.load_file(path):
			store = candidate
			reset_history()
			audio.root = path.get_base_dir()
			dirty = false
			selected = 0
			route.clear()
			update_title()
			show_page(section)
		else:
			report("\n".join(candidate.errors),true)
	)

func create_project() -> void:
	file_picker(FileDialog.FILE_MODE_SAVE_FILE,["*.json ; Novo projeto"],func(path):
		var source = Store.new()
		if not source.load_file(workspace.path_join("player/data/default.json")):
			report("Modelo inicial ausente ou inválido.",true)
			return
		if FileAccess.file_exists(path):
			report("Escolha um nome de arquivo novo para preservar o projeto existente.",true)
			return
		var previous_data: Dictionary = store.data
		store.data = source.data
		var copied = copy_assets(source.path.get_base_dir(),path.get_base_dir())
		store.data = previous_data
		if not copied:
			return
		source.path = path
		if source.save_file():
			store = source
			reset_history()
			dirty = false
			selected = 0
			update_title()
			show_page("Dashboard")
			report("Novo projeto criado: "+path)
		else:
			report("\n".join(source.errors),true)
	)

func save_as() -> void:
	file_picker(FileDialog.FILE_MODE_SAVE_FILE,["*.json ; Projeto"],func(path):
		var original = store.path
		var previous = store.path.get_base_dir()
		var target = path.get_base_dir()
		if previous != target:
			if not copy_assets(previous,target):
				return
		store.path = path
		if save_project():
			audio.root = target
		else:
			store.path = original
	)

func copy_assets(source: String, target: String) -> bool:
	var resources: Array = []
	for character in store.data.characters:
		resources.append(character.sprite)
		for clips in character.voices.values():
			for clip in clips:
				resources.append(clip.file)
	for arena in store.data.arenas:
		resources.append(arena.background)
		resources.append(arena.music)
		for layer in arena.get("crowd",[]):
			resources.append(layer.file)
	for entry in store.data.get("library",[]):
		resources.append(entry.file)
	for field in ["background","music"]:
		resources.append(store.data.menu.get(field,""))
	resources.append(store.data.get("resource_audio",{}).get("effects",""))
	for resource in resources:
		if str(resource).is_empty():
			continue
		var destination = target.path_join(resource)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) != FileAccess.get_sha256(source.path_join(resource)):
			report("Existe outro recurso no destino: "+resource,true)
			return false
		if DirAccess.copy_absolute(source.path_join(resource),destination) != OK:
			report("Não foi possível copiar o recurso: "+resource,true)
			return false
	return true

func backup_project() -> void:
	if not save_project():
		return
	var path = store.path.get_base_dir().path_join("backups/%s/project.json" % str(Time.get_unix_time_from_system()).replace(".","_"))
	if copy_assets(store.path.get_base_dir(),path.get_base_dir()) and Store.write_atomic(path,store.data) == OK:
		report("Backup completo criado: "+path)
	else:
		report("Falha ao criar backup.",true)

func restore_backup() -> void:
	file_picker(FileDialog.FILE_MODE_OPEN_FILE,["*.json,*.bak ; Backup de conteúdo"],func(path):
		var candidate = Store.new()
		if not candidate.load_file(path):
			report("Backup rejeitado:\n"+"\n".join(candidate.errors),true)
			return
		var previous_data: Dictionary = store.data
		store.data = candidate.data
		if not copy_assets(path.get_base_dir(),store.path.get_base_dir()):
			store.data = previous_data
			return
		modified()
		if save_project():
			selected = 0
			route.clear()
			show_page(section)
			report("Backup restaurado. A versão anterior está preservada em .bak.")
	)

func import_asset(filters: Array, callback: Callable) -> void:
	file_picker(FileDialog.FILE_MODE_OPEN_FILE,filters,func(path):
		var extension = path.get_extension().to_lower()
		if extension in ["png","jpg","webp"]:
			if Image.load_from_file(path) == null:
				report("Imagem inválida.",true)
				return
		elif audio.load_stream(path) == null:
			report("Arquivo de áudio inválido ou incompatível.",true)
			return
		var relative = "assets/%d_%s" % [Time.get_ticks_usec(),path.get_file().validate_filename()]
		var destination = store.path.get_base_dir().path_join(relative)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var status = DirAccess.copy_absolute(path,destination)
		if status != OK:
			report("Falha na importação: "+error_string(status),true)
			return
		callback.call(relative)
		report("Recurso importado: "+relative)
	)

func _process(_delta: float) -> void:
	if arguments.has("capture"):
		capture_frames += 1
		if capture_frames == 20:
			get_viewport().get_texture().get_image().save_png(arguments.capture)
			get_tree().quit()


func action_button(text: String, callback: Callable) -> Button:
	var control = UI.button(text,callback)
	control.custom_minimum_size.y = 38
	return control

func quick_find_character(query: String) -> void:
	for index in store.data.characters.size():
		var character: Dictionary = store.data.characters[index]
		if (character.name+" "+character.id).to_lower().contains(query.to_lower()):
			selected = index
			show_page("Personagens")
			return
	report("Nenhum personagem encontrado. Tente parte do nome ou o ID.",true)

func library_page() -> void:
	page.add_child(studio_label("Prévia, licença e vínculos em um único lugar. Arraste arquivos para a janela para começar.",16,UI.MUTED))
	resource_panel = ResourcePanel.new()
	if resource_panel.library.index_existing(store.data,store.path.get_base_dir()) > 0:
		modified()
	page.add_child(resource_panel)
	resource_panel.setup(store,audio)
	resource_panel.changed.connect(modified)
	resource_panel.message.connect(report)
	page.add_child(action_button("Importar pacote de catálogo / campanhas",import_catalog))

func open_library_for(type: String, id: String, category_index: int) -> void:
	show_page("Biblioteca")
	resource_panel.category.select(category_index)
	resource_panel.refresh_targets()
	for index in resource_panel.target.item_count:
		var value: Dictionary = resource_panel.target.get_item_metadata(index)
		if value.type == type and value.id == id:
			resource_panel.target.select(index)
			resource_panel.refresh_slots()
			break
	report("Selecione o arquivo, confira a prévia e confirme Importar e vincular.")

func controls_page() -> void:
	page.add_child(studio_label("Defina os padrões da Player Edition. Preferências individuais ficam no computador de cada jogador.",16,UI.MUTED))
	controls_panel = ControlsPanel.new()
	page.add_child(controls_panel)
	controls_panel.setup(Controls.project_defaults(store.data),Controls.defaults())
	controls_panel.changed.connect(func(value): store.data.controls = value; modified())
	controls_panel.save_requested.connect(func(value): store.data.controls = value; modified(); save_project())

func settings_page() -> void:
	page.add_child(studio_label("Configurações do projeto e ferramentas de autoria.",16,UI.MUTED))
	var box = card(page)
	box.add_child(studio_label("Ferramentas de desenvolvimento",20))
	box.add_child(studio_label(engine_path,14,UI.MUTED))
	box.add_child(action_button("Selecionar executável Godot",func(): file_picker(FileDialog.FILE_MODE_OPEN_FILE,["*.exe ; Godot"],func(path): engine_path = path; show_page("Configurações"))))
	for pair in [["Chefes","Chefes"],["Economia","Economia"],["História","História"],["Menus e interface","Menus"]]:
		box.add_child(action_button(pair[0],func(): show_page(pair[1])))

func confirm_remove_character() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Excluir personagem"
	dialog.dialog_text = "Excluir %s? Referências de campanha serão verificadas. A alteração pode ser desfeita." % store.data.characters[selected].name
	dialog.confirmed.connect(func(): remove_character(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,180))

func request_close() -> void:
	if exporter.busy:
		report("Há uma compilação em andamento. Aguarde o resultado antes de fechar.",true)
		return
	if not dirty:
		get_tree().quit()
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "Alterações não salvas"
	dialog.dialog_text = "Salve o projeto antes de fechar para preservar as últimas alterações."
	dialog.get_ok_button().text = "Salvar e fechar"
	dialog.add_button("Fechar sem salvar",false,"discard")
	dialog.confirmed.connect(func():
		if save_project():
			get_tree().quit()
		dialog.queue_free()
	)
	dialog.custom_action.connect(func(action):
		if action == "discard":
			get_tree().quit()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,180))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_close()

func publication_page() -> void:
	var hub = PublicationPanel.new()
	page.add_child(hub)
	hub.setup(self)


func studio_label(text: String, size: int = 22, color: Color = UI.INK) -> Label:
	var label = UI.label(text,size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.tooltip_text = text
	return label

func confirm_change(text: String, callback: Callable) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirmar remoção"
	dialog.dialog_text = text
	dialog.confirmed.connect(func(): callback.call(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(560,200))
