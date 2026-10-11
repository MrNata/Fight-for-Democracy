extends Control
const Store = preload("res://runtime/content_store.gd")
const Match = preload("res://runtime/combat_match.gd")
const Campaign = preload("res://runtime/campaign_system.gd")
const Saves = preload("res://runtime/save_system.gd")
const Economy = preload("res://runtime/economy_system.gd")
const Audio = preload("res://runtime/audio_system.gd")
const Controls = preload("res://runtime/controls_config.gd")
const ControlsPanel = preload("res://runtime/controls_panel.gd")
const Arena = preload("res://runtime/arena_system.gd")
const UI = preload("res://runtime/ui_kit.gd")
var store = Store.new()
var saves = Saves.new()
var economy = Economy.new()
var audio: Node
var screen: Control
var combat: Node2D
var hud: Control
var overlay: Control
var health_bars: Array = []
var fame_bars: Array = []
var state_labels: Array = []
var clock_label: Label
var center_label: Label
var profile = "Perfil 1"
var career: Dictionary = {}
var career_active = false
var last_match: Dictionary = {}
var arguments: Dictionary = {}
var capture_frames = 0
var control_settings: Dictionary = {}
var control_preferences_path = "user://controls.json"
var screen_kind = "menu"

func _ready() -> void:
	theme = UI.theme(25)
	for arg in OS.get_cmdline_user_args():
		var pieces = arg.trim_prefix("--").split("=",true,1)
		arguments[pieces[0]] = pieces[1] if pieces.size() > 1 else "true"
	var content = str(arguments.get("content", "res://data/default.json"))
	if OS.has_feature("editor") and not arguments.has("content"):
		var authoring = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("content/project.json")
		if FileAccess.file_exists(authoring):
			content = authoring
	if not store.load_file(content):
		screen = full_screen()
		var box = VBoxContainer.new()
		box.add_child(UI.label("Conteúdo inválido",44))
		box.add_child(UI.label("\n".join(store.errors),24))
		screen.add_child(UI.margins(box,80))
		return
	theme = UI.theme(25,Color(store.data.menu.accent))
	control_preferences_path = str(arguments.get("controls-file",control_preferences_path))
	control_settings = Controls.load_preferences(control_preferences_path,Controls.project_defaults(store.data))
	Controls.install_menu_bindings(control_settings)
	audio = Audio.new()
	add_child(audio)
	audio.root = store.path.get_base_dir()
	audio.impact_file = store.data.get("resource_audio",{}).get("effects","")
	for bus in store.data.audio:
		audio.set_volume(bus,store.data.audio[bus])
	if arguments.has("test-fight"):
		start_match(str(arguments.get("left","teste_aurora")),str(arguments.get("right","teste_torquato")),str(arguments.get("mode","training")),str(arguments.get("arena","praca")),int(arguments.get("difficulty",0)))
	else:
		main_menu()

func full_screen() -> Control:
	var control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(control)
	return control

func reset_screen() -> void:
	if audio != null:
		audio.music.stop()
	if combat != null:
		remove_child(combat)
		combat.queue_free()
		combat = null
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	if overlay != null:
		overlay.queue_free()
		overlay = null
	screen = full_screen()
	health_bars.clear()
	fame_bars.clear()
	state_labels.clear()

func main_menu() -> void:
	screen_kind = "menu"
	career_active = false
	reset_screen()
	var background = Arena.new()
	background.setup(store.data.arenas[0],store.path.get_base_dir())
	screen.add_child(background)
	var custom_background = str(store.data.menu.get("background",""))
	if not custom_background.is_empty():
		var texture = TextureRect.new()
		texture.texture = load(store.asset_path(custom_background)) if store.asset_path(custom_background).begins_with("res://") else ImageTexture.create_from_image(Image.load_from_file(store.asset_path(custom_background)))
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.add_child(texture)
	var menu_music = str(store.data.menu.get("music",""))
	if not menu_music.is_empty():
		audio.music.stream = audio.load_stream(store.asset_path(menu_music))
		audio.music.play()
	var tint = ColorRect.new()
	tint.color = Color(0.02,0.04,0.08,0.72)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(tint)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",120)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var intro = VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_theme_constant_override("separation",24)
	intro.add_child(UI.label("URNA-X  /  PROJETO 001",23,UI.GREEN))
	intro.add_child(UI.label(store.data.title.replace(" FOR "," FOR\n"),100))
	intro.add_child(UI.label(store.data.menu.subtitle,30,Color(store.data.menu.accent)))
	var text = UI.label(store.data.story.intro,25,UI.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 850
	intro.add_child(text)
	intro.add_child(UI.label("FUNDAÇÃO JOGÁVEL  •  ARTE TEMPORÁRIA",20,Color("#ecc96c")))
	var menu = VBoxContainer.new()
	menu.custom_minimum_size.x = 520
	menu.add_theme_constant_override("separation",16)
	menu.add_child(UI.label("ENTRE NA ARENA",35))
	menu.add_child(UI.button("Luta rápida  /  contra IA",func(): selection("ai")))
	menu.add_child(UI.button("Versus local  /  2 jogadores",func(): selection("local")))
	menu.add_child(UI.button("Treinamento  /  hitboxes",func(): selection("training")))
	menu.add_child(UI.button("Nova carreira",func(): selection("career")))
	menu.add_child(UI.button("Continuar carreira",continue_career))
	menu.add_child(UI.button("Recordes locais",rankings))
	menu.add_child(UI.button("Áudio e controles",settings))
	menu.add_child(UI.button("Configuração de controles",controls_page))
	var profile_select = OptionButton.new()
	for i in 3:
		profile_select.add_item("Perfil %d" % (i+1))
	profile_select.select(int(profile.trim_prefix("Perfil "))-1)
	profile_select.item_selected.connect(func(index): profile = "Perfil %d" % (index+1))
	menu.add_child(profile_select)
	menu.add_child(UI.button("Sair",func(): get_tree().quit()))
	row.add_child(intro)
	row.add_child(menu)
	screen.add_child(UI.margins(row,110))
	menu.get_child(1).grab_focus()

func simple_page(title: String) -> VBoxContainer:
	screen_kind = "page"
	reset_screen()
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",20)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(UI.label(title,52))
	screen.add_child(UI.margins(box,80))
	return box

func selection(mode: String) -> void:
	var box = simple_page("ESCOLHA SEU LUTADOR")
	box.add_child(UI.label("156 slots de autoria • Personagens fictícios e arte temporária",24,UI.MUTED))
	var faction = OptionButton.new()
	for i in store.data.factions.size():
		faction.add_item(store.data.factions[i].name)
	box.add_child(faction)
	faction.visible = mode == "career"
	var choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation",40)
	var left = ItemList.new()
	var right: ItemList = null
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.y = 590
	choices.add_child(left)
	if mode != "career":
		right = ItemList.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.custom_minimum_size.y = 590
		choices.add_child(right)
	var populate = func():
		left.clear()
		for character in store.data.characters:
			if mode == "career" and (character.faction != store.data.factions[faction.selected].id or character.boss or not character.campaign_enabled):
				continue
			left.add_item(character.name)
			left.set_item_metadata(left.item_count-1,character.id)
		if left.item_count > 0:
			left.select(0)
	populate.call()
	if right != null:
		for character in store.data.characters:
			right.add_item(character.name)
			right.set_item_metadata(right.item_count-1,character.id)
		right.select(40)
	faction.item_selected.connect(func(_index): populate.call())
	box.add_child(choices)
	var message = UI.label("",24,Color("#ef8a8a"))
	box.add_child(message)
	box.add_child(UI.button("ENTRAR NA ARENA",func():
		if left.get_selected_items().is_empty():
			return
		var id = left.get_item_metadata(left.get_selected_items()[0])
		if mode == "career":
			var generator = Campaign.new()
			var fid: String = store.data.factions[faction.selected].id
			var schedule = generator.generate(store.data,id,fid,int(store.data.campaign.seed))
			if schedule.is_empty():
				message.text = "\n".join(generator.errors)
				return
			career = saves.new_career(id,fid,schedule,int(store.data.campaign.seed))
			if not saves.save(profile,career):
				message.text = saves.error
				return
			career_active = true
			career_map()
		else:
			start_match(id,right.get_item_metadata(right.get_selected_items()[0]),mode)
	))
	box.add_child(UI.button("Voltar",main_menu))

func start_match(left_id: String, right_id: String, mode: String = "ai", arena_id: String = "praca", difficulty: int = 0) -> void:
	var left = store.character(left_id)
	var right = store.character(right_id)
	if left.is_empty() or right.is_empty():
		return
	last_match = {"left": left_id, "right": right_id, "mode": mode, "arena": arena_id, "difficulty": difficulty}
	reset_screen()
	if career_active:
		left = economy.apply(left,career,store.data)
	var arena: Dictionary = store.data.arenas[0]
	for entry in store.data.arenas:
		if entry.id == arena_id:
			arena = entry
	combat = Match.new()
	combat.narrative_boss = career_active and career.faction == "esquerda" and career.faction == store.data.campaign.narrative_invincible_route and right_id == store.data.campaign.get("narrative_boss_id", "teste_guardiao") and career.schedule[int(career.next_fight)].boss
	add_child(combat)
	move_child(combat,0)
	combat.setup(left,right,arena,store.path.get_base_dir(),mode,difficulty)
	combat.input_system.configure(control_settings)
	combat.finished.connect(match_finished)
	combat.impact.connect(func(blocked): audio.tone(310 if blocked else 150))
	for fighter in combat.fighters:
		fighter.voice_event.connect(func(event): audio.voice(fighter.config,event))
		audio.voice(fighter.config,"entry")
	if not str(arena.get("music", "")).is_empty():
		audio.music.stream = audio.load_stream(store.asset_path(arena.music))
		audio.music.play()
	hud = screen
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bars = HBoxContainer.new()
	bars.add_theme_constant_override("separation",55)
	for index in 2:
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(combat.fighters[index].config.name,27))
		var health_bar = ProgressBar.new()
		health_bar.max_value = float(combat.fighters[index].config.stats.health)
		health_bar.custom_minimum_size.y = 32
		health_bar.show_percentage = false
		info.add_child(health_bar)
		health_bars.append(health_bar)
		var fame_bar = ProgressBar.new()
		fame_bar.custom_minimum_size.y = 14
		fame_bar.show_percentage = false
		fame_bar.add_theme_stylebox_override("fill", UI.style(Color("#b79cec"),4))
		info.add_child(fame_bar)
		fame_bars.append(fame_bar)
		var status = UI.label("FAMA 0",19,UI.MUTED)
		info.add_child(status)
		state_labels.append(status)
		if index == 1:
			clock_label = UI.label("99",60,Color("#ecc96c"))
			bars.add_child(clock_label)
		bars.add_child(info)
	var margin = UI.margins(bars,48)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.add_child(margin)
	center_label = UI.label("PREPARE-SE",58)
	center_label.position = Vector2(650,285)
	center_label.size = Vector2(620,110)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(center_label)
	var keys: Dictionary = control_settings.profiles[control_settings.active_profile].players[0].keyboard
	var footer = UI.label("P1: %s/%s mover · %s salto · %s/%s socos · %s/%s chutes\n%s defesa · %s esquiva · %s/%s especiais · %s super · %s pausa · F1 hitboxes" % [Controls.describe(keys.left),Controls.describe(keys.right),Controls.describe(keys.jump),Controls.describe(keys.light_punch),Controls.describe(keys.heavy_punch),Controls.describe(keys.light_kick),Controls.describe(keys.heavy_kick),Controls.describe(keys.block),Controls.describe(keys.dodge),Controls.describe(keys.special_a),Controls.describe(keys.special_b),Controls.describe(keys.super),Controls.describe(keys.pause)],20,UI.MUTED)
	footer.position = Vector2(55,975)
	hud.add_child(footer)
	if combat.narrative_boss:
		var warning = UI.label("PARADOXO DA URNA-X • Enéas invencível nesta história. Encerramento inevitável em até 30 s.",24,Color("#ecc96c"))
		warning.position = Vector2(240,215)
		hud.add_child(warning)

func _process(_delta: float) -> void:
	if combat != null and not health_bars.is_empty():
		for index in 2:
			var fighter = combat.fighters[index]
			health_bars[index].value = fighter.health
			fame_bars[index].value = fighter.fame
			state_labels[index].text = "FAMA %03d   |   %s   |   COMBO %d" % [int(fighter.fame),fighter.state_label(),fighter.combo]
			if combat.mode == "training" and fighter.state == fighter.State.ATTACK:
				state_labels[index].text += "   %s  %d/%d/%d  f:%d" % [fighter.attack.name,int(fighter.attack.startup),int(fighter.attack.active),int(fighter.attack.recovery),fighter.action_frame]
		clock_label.text = "∞" if combat.mode == "training" else "%02d" % int(ceil(combat.remaining_frames/60.0))
		center_label.text = "PREPARE-SE" if combat.intro_frames > 40 else "LUTE!" if combat.intro_frames > 0 else ""
	if arguments.has("capture"):
		capture_frames += 1
		if capture_frames == 20:
			get_viewport().get_texture().get_image().save_png(arguments.capture)
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if combat == null and screen_kind != "menu" and event.is_action_pressed("ui_cancel"):
		main_menu()
		get_viewport().set_input_as_handled()
		return
	if combat != null and not combat.ended:
		var players: Array = control_settings.profiles[control_settings.active_profile].players
		for index in 2:
			if Controls.event_matches(event,players[index],"pause",index):
				pause_match()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and combat != null:
			for fighter in combat.fighters:
				fighter.show_boxes = not fighter.show_boxes

func modal(title: String, message: String) -> VBoxContainer:
	overlay = full_screen()
	var dim = ColorRect.new()
	dim.color = Color(0.02,0.03,0.06,0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 780
	center.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",22)
	panel.add_child(UI.margins(box,40))
	box.add_child(UI.label(title,50,UI.GREEN))
	var text = UI.label(message,25)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 690
	box.add_child(text)
	return box

func pause_match() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
		combat.paused = false
		return
	combat.paused = true
	var box = modal("PAUSA", "O cronômetro e a física estão pausados.")
	box.add_child(UI.button("Continuar",pause_match))
	box.add_child(UI.button("Reiniciar confronto",restart_match))
	box.add_child(UI.button("Menu principal",main_menu))

func restart_match() -> void:
	start_match(last_match.left,last_match.right,last_match.mode,last_match.arena,last_match.difficulty)

func controls_page() -> void:
	var box = simple_page("CONFIGURAÇÃO DE CONTROLES")
	box.add_child(UI.label("Preferências deste jogador • os padrões do projeto permanecem preservados",22,UI.MUTED))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var panel = ControlsPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	panel.setup(control_settings,Controls.project_defaults(store.data))
	panel.save_requested.connect(func(value):
		if Store.write_atomic(control_preferences_path,value) == OK:
			control_settings = value.duplicate(true)
			Controls.install_menu_bindings(control_settings)
			panel.notice.text = "Configurações pessoais salvas. Padrões do projeto preservados."
		else:
			panel.notice.text = "Não foi possível salvar as preferências de controles."
	)
	box.add_child(UI.button("Voltar ao menu",main_menu))

func match_finished(result: Dictionary) -> void:
	var won = result.winner == 0
	var title = "VITÓRIA" if won else "EMPATE" if result.winner == -1 else "DERROTA"
	var message: String = store.data.story.victory if won else store.data.story.defeat
	if result.narrative:
		title = "FIM DA ROTA"
		message = store.data.story.left_ending
	if career_active:
		var fight: Dictionary = career.schedule[int(career.next_fight)]
		career.campaign_seconds += result.seconds
		career.max_combo = maxi(int(career.max_combo),int(result.max_combo))
		if won:
			career.wins += 1
			career.defeated.append(fight.opponent)
			career.next_fight += 1
			var reward = int(fight.reward) + int(store.data.economy.win_reward) + int(result.health) + int(result.max_combo)*10
			career.propina += reward
			career.score += reward*10
			career.remaining_health.append(result.health)
			message += "\nRecompensa: P$ %d" % reward
		else:
			career.losses += 1
			career.propina += int(store.data.economy.loss_reward)
		if result.narrative:
			career.next_fight = career.schedule.size()
		career.completed = int(career.next_fight) >= career.schedule.size()
		if won and not career.completed:
			var next: Dictionary = career.schedule[int(career.next_fight)]
			if int(next.rank) != int(fight.rank):
				message += "\nPROMOÇÃO: " + store.data.campaign.ranks[int(next.rank)].name
		if not saves.save(profile,career):
			message += "\n" + saves.error
	var box = modal(title,message)
	if career_active:
		box.add_child(UI.button("Mapa da carreira e loja",career_map))
	else:
		box.add_child(UI.button("Revanche",restart_match))
	box.add_child(UI.button("Menu principal",main_menu))

func continue_career() -> void:
	career = saves.load_profile(profile)
	if career.is_empty():
		var box = modal("CARREIRA",saves.error if not saves.error.is_empty() else "Este perfil ainda não possui carreira.")
		box.add_child(UI.button("Voltar",func(): overlay.queue_free(); overlay = null))
		return
	var generator = Campaign.new()
	var problems = generator.validate_schedule(career.schedule,store.data,career.character,career.faction,int(career.get("schedule_rules",1)) < 2)
	if not problems.is_empty():
		var box = modal("CONTEÚDO ALTERADO","A carreira salva não corresponde ao conteúdo atual.\n"+"\n".join(problems))
		box.add_child(UI.button("Voltar",main_menu))
		return
	career_active = true
	career_map()

func career_map() -> void:
	var box = simple_page("CARREIRA  /  " + profile)
	box.add_child(UI.label("%s  •  %s  •  P$ %d  •  %dV / %dD" % [store.character(career.character).name,career.faction,int(career.propina),int(career.wins),int(career.losses)],26,UI.GREEN))
	if career.completed:
		box.add_child(UI.label("Campanha encerrada. Pontuação: %d" % int(career.score),34))
	else:
		var fight: Dictionary = career.schedule[int(career.next_fight)]
		box.add_child(UI.label("%s  •  Confronto %d / %d\nPróximo: %s  •  Arena: %s" % [store.data.campaign.ranks[int(fight.rank)].name,int(career.next_fight)+1,career.schedule.size(),store.character(fight.opponent).name,fight.arena],30))
		box.add_child(UI.button("LUTAR",func(): start_match(career.character,fight.opponent,"ai",fight.arena,int(fight.difficulty))))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",35)
	var list = ItemList.new()
	list.custom_minimum_size = Vector2(850,510)
	for index in career.schedule.size():
		var fight: Dictionary = career.schedule[index]
		var mark = "✓" if index < int(career.next_fight) else "→" if index == int(career.next_fight) else "·"
		list.add_item("%s %03d  %s  /  %s" % [mark,index+1,store.data.campaign.ranks[int(fight.rank)].name,store.character(fight.opponent).name])
	if not career.completed:
		list.select(int(career.next_fight))
		list.ensure_current_is_visible()
	row.add_child(list)
	var shop = VBoxContainer.new()
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.add_child(UI.label("LOJA DE PROPINA  /  moeda fictícia",26,Color("#ecc96c")))
	for upgrade in store.data.economy.upgrades:
		var level = int(career.upgrades.get(upgrade.id,0))
		var button = UI.button("%s  %d/%d  +%d%%  /  P$ %d" % [upgrade.name,level,int(upgrade.max_level),int(upgrade.effect*100),int(upgrade.price)*(level+1)],func():
			var previous = career.duplicate(true)
			if economy.purchase(career,upgrade):
				if not saves.save(profile,career):
					career = previous
				career_map()
		)
		button.disabled = level >= int(upgrade.max_level) or career.propina < int(upgrade.price)*(level+1) or career.completed
		shop.add_child(button)
	row.add_child(shop)
	box.add_child(row)
	box.add_child(UI.button("Menu principal",main_menu))

func rankings() -> void:
	var box = simple_page("RECORDES LOCAIS")
	for i in 3:
		var name = "Perfil %d" % (i+1)
		var progress = saves.load_profile(name)
		box.add_child(UI.label(name + "  •  sem carreira" if progress.is_empty() else "%s  •  %d pontos  •  %d vitórias  •  combo %d" % [name,int(progress.score),int(progress.wins),int(progress.max_combo)],30))
	box.add_child(UI.label(store.data.menu.credits,25,UI.MUTED))
	box.add_child(UI.button("Voltar",main_menu))

func settings() -> void:
	var box = simple_page("ÁUDIO E CONTROLES")
	for bus in Audio.CHANNELS:
		var row = HBoxContainer.new()
		var text = UI.label(bus,26)
		text.custom_minimum_size.x = 200
		row.add_child(text)
		var slider = HSlider.new()
		slider.custom_minimum_size.x = 850
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))
		slider.value_changed.connect(func(value): audio.set_volume(bus,value))
		row.add_child(slider)
		box.add_child(row)
	box.add_child(UI.label("Consulte Configuração de controles para ver os comandos atuais dos dois jogadores.",25,UI.MUTED))
	box.add_child(UI.button("Configuração de controles",controls_page))
	box.add_child(UI.label("Os efeitos desta versão são sons temporários originais. Não há clonagem de voz.",23,Color("#ecc96c")))
	box.add_child(UI.button("Voltar",main_menu))
