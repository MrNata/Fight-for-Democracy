extends VBoxContainer
const History = preload("res://editor/release_history.gd")
const UI = preload("res://runtime/ui_kit.gd")
var app: Control
var summary: Label
var phase: Label
var progress: ProgressBar
var log_view: TextEdit
var history_list: ItemList
var actions: Array[Button] = []
var validation = "Ainda não executada nesta sessão"
var elapsed = 0.0
var omit_unlicensed: CheckBox

func setup(owner_app: Control) -> void:
	app = owner_app
	add_theme_constant_override("separation",12)
	add_child(UI.label("EDITAR  →  SALVAR  →  VALIDAR  →  TESTAR  →  GERAR",16,Color("#8ab7ff")))
	app.text_field(self,"Versão atual do projeto",app.store.data,"project_version")
	app.text_field(self,"Notas desta atualização",app.store.data,"release_notes",true)
	omit_unlicensed = CheckBox.new()
	omit_unlicensed.text = "Omitir recursos com licença pendente somente nesta compilação"
	omit_unlicensed.tooltip_text = "Opção explícita. Preserva arquivos e vínculos no projeto; o manifesto lista os recursos omitidos. Sem esta seleção, a exportação rejeita licenças incompletas."
	add_child(omit_unlicensed)
	summary = UI.label("",16)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	var toolbar = HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation",10)
	toolbar.add_theme_constant_override("v_separation",10)
	add_child(toolbar)
	for pair in [["Salvar alterações",func(): app.save_project()],["Testar Player Edition",func(): app.test_game()],["Validar projeto",validate_project],["Gerar nova versão",func(): app.export_game(omit_unlicensed.button_pressed)],["Abrir pasta do jogo",open_folder],["Visualizar erros",show_errors]]:
		var button = app.action_button(pair[0],pair[1])
		toolbar.add_child(button)
		actions.append(button)
	phase = UI.label("Pronto para gerar uma versão local.",15,UI.MUTED)
	add_child(phase)
	progress = ProgressBar.new()
	add_child(progress)
	add_child(UI.label("HISTÓRICO DE VERSÕES VERIFICADAS",18))
	history_list = ItemList.new()
	history_list.custom_minimum_size.y = 150
	history_list.item_selected.connect(show_build)
	add_child(history_list)
	add_child(UI.label("LOG DE COMPILAÇÃO",18))
	log_view = TextEdit.new()
	log_view.editable = false
	log_view.custom_minimum_size.y = 190
	log_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(log_view)
	add_child(UI.label("PREPARAR PUBLICAÇÃO NA STEAM",18))
	var note = UI.label("Sem integração Steamworks. Este botão prepara arquivos locais, notas e modelos SteamPipe. O upload e a publicação são feitos manualmente pela sua conta Steamworks.",15,UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	var steam = app.action_button("Preparar pacote Steam…",prepare_steam)
	add_child(steam)
	actions.append(steam)
	refresh()

func validate_project() -> void:
	var distribution_errors = app.store.validate_distribution()
	var valid = app.validate_all() and distribution_errors.is_empty()
	validation = "Projeto e licenças válidos para distribuição" if valid else "Falhou; veja Visualizar erros"
	if not distribution_errors.is_empty():
		app.report("\n".join(distribution_errors),true)
	refresh()

func refresh() -> void:
	var builds = History.read_history(app.workspace)
	var last = builds[-1] if not builds.is_empty() else {}
	summary.text = "Última compilação: %s\nData: %s UTC\nAlterações pendentes: %s\nValidação: %s\nExecutável: %s" % [last.get("version","Nenhuma"),last.get("date","—"),"Sim" if last.get("content_hash","") != History.fingerprint(app.store.data) else "Não",validation,last.get("executable","Gere a primeira versão para criar o executável.")]
	if not last.get("omitted_resources",[]).is_empty():
		summary.text += "\nRecursos omitidos nesta compilação: "+str(last.omitted_resources.size())+" (consulte manifest.json)."
	history_list.clear()
	var descending = builds.duplicate()
	descending.reverse()
	for record in descending:
		history_list.add_item("%s  ·  %s UTC  ·  Verificada" % [record.version,record.date])
		history_list.set_item_metadata(history_list.item_count-1,record)
	phase.text = app.exporter.phase
	progress.value = app.exporter.progress
	if app.exporter.phase == "Concluído e verificado":
		validation = "Compilação validada e executável verificado"
	if app.exporter.phase == "Falha":
		log_view.text = app.errors_text
	for button in actions:
		button.disabled = app.exporter.busy
	if not app.exporter.output.is_empty() and app.exporter.phase != "Falha":
		var path = app.exporter.output.get_base_dir().path_join("export.log")
		if FileAccess.file_exists(path):
			log_view.text = FileAccess.get_file_as_string(path)

func show_build(index: int) -> void:
	var record: Dictionary = history_list.get_item_metadata(index)
	var path = str(record.executable).get_base_dir().path_join("export.log")
	log_view.text = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "Log não disponível."
	app.report("Executável desta versão: "+record.executable)

func open_folder() -> void:
	var record = History.latest(app.workspace)
	var directory = str(record.get("executable",app.workspace.path_join("dist/player/FightForDemocracy.exe"))).get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var status = OS.shell_open(directory)
	if status != OK:
		app.report("Não foi possível abrir a pasta: "+error_string(status),true)

func show_errors() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Erros e validação"
	dialog.dialog_text = app.errors_text if not app.errors_text.is_empty() else "Nenhum erro registrado nesta sessão."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(680,360))

func prepare_steam() -> void:
	if not app.save_project():
		return
	var result = History.prepare_steam(app.workspace,app.store.data)
	app.report(result.message,not result.success)
	if result.success:
		OS.shell_open(result.folder)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.4:
		elapsed = 0
		if app.exporter.busy:
			phase.text = app.exporter.phase
			progress.value = app.exporter.progress
			for button in actions:
				button.disabled = true
		elif actions[0].disabled:
			refresh()
