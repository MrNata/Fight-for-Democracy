extends VBoxContainer
signal changed
signal message(text: String, failure: bool)
const Library = preload("res://editor/resource_library.gd")
const UI = preload("res://runtime/ui_kit.gd")
var library = Library.new()
var store: RefCounted
var audio: Node
var picked_file = ""
var info: Dictionary = {}
var metadata = {"name":"","source":"","license":"","authorization":""}
var category: OptionButton
var target: OptionButton
var slot: OptionButton
var preview_image: TextureRect
var preview_hint: Label
var detail: Label
var progress: ProgressBar
var search: LineEdit
var filter: OptionButton
var order: OptionButton
var list: ItemList
var inspector: VBoxContainer
var import_button: Button
var selected_id = ""
var importing = false
var import_queued = false

func setup(value: RefCounted, audio_value: Node) -> void:
	store = value
	audio = audio_value
	build()

func label(text: String, size: int = 16) -> Label:
	var result = UI.label(text,size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func button(text: String, callback: Callable) -> Button:
	var value = UI.button(text,callback)
	value.custom_minimum_size.y = 38
	return value

func panel(parent: Node) -> VBoxContainer:
	var container = PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(container)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	container.add_child(UI.margins(box,14))
	return box

func build() -> void:
	add_theme_constant_override("separation",18)
	var importer = panel(self)
	importer.add_child(label("IMPORTAR RECURSOS",20))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	importer.add_child(row)
	var preview = VBoxContainer.new()
	preview.custom_minimum_size.x = 270
	row.add_child(preview)
	var drop = PanelContainer.new()
	drop.custom_minimum_size = Vector2(270,150)
	preview.add_child(drop)
	preview_image = TextureRect.new()
	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drop.add_child(preview_image)
	preview_hint = label("Prévia do recurso\nPNG · JPG · WebP · Áudio",15)
	preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drop.add_child(preview_hint)
	var tip = label("Arraste arquivos para esta janela\nou selecione no computador.",15)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(tip)
	preview.add_child(button("Selecionar arquivo…",choose_file))
	var audio_actions = HBoxContainer.new()
	audio_actions.add_child(button("▶ Ouvir",play_preview))
	audio_actions.add_child(button("■ Parar",stop_audio))
	preview.add_child(audio_actions)
	var form = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(form)
	detail = label("PNG · JPG · WebP · WAV · OGG · MP3\nSelecione um arquivo para ver a prévia, tamanho e formato.")
	form.add_child(detail)
	category = OptionButton.new()
	for name in Library.CATEGORIES:
		category.add_item(name)
	category.item_selected.connect(func(_index): refresh_targets())
	form.add_child(category)
	target = OptionButton.new()
	target.item_selected.connect(func(_index): refresh_slots())
	form.add_child(target)
	slot = OptionButton.new()
	form.add_child(slot)
	refresh_targets()
	var metadata_grid = GridContainer.new()
	metadata_grid.columns = 2
	metadata_grid.add_theme_constant_override("h_separation",12)
	metadata_grid.add_theme_constant_override("v_separation",8)
	metadata_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(metadata_grid)
	for pair in [["Nome na biblioteca","name"],["Origem do recurso","source"],["Licença","license"],["Autorização de distribuição","authorization"]]:
		var field = VBoxContainer.new()
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metadata_grid.add_child(field)
		field.add_child(label(pair[0],14))
		var input = LineEdit.new()
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.set_meta("metadata_key",pair[1])
		input.text_changed.connect(func(value): metadata[pair[1]] = value)
		field.add_child(input)
	progress = ProgressBar.new()
	progress.max_value = 100
	progress.value = 0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 10
	for pair in [["background",Color("#253147")],["fill",Color("#648cc5")]]:
		var style = StyleBoxFlat.new()
		style.bg_color = pair[1]
		style.set_corner_radius_all(3)
		progress.add_theme_stylebox_override(pair[0],style)
	preview.add_child(progress)
	import_button = button("IMPORTAR E VINCULAR",begin_import)
	import_button.disabled = true
	preview.add_child(import_button)
	var catalog = panel(self)
	catalog.add_child(label("BIBLIOTECA DO PROJETO",20))
	var toolbar = HBoxContainer.new()
	search = LineEdit.new()
	search.placeholder_text = "Pesquisar nome ou arquivo…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value): populate())
	toolbar.add_child(search)
	filter = OptionButton.new()
	filter.add_item("Todas as categorias")
	for name in Library.CATEGORIES:
		filter.add_item(name)
	filter.item_selected.connect(func(_index): populate())
	toolbar.add_child(filter)
	order = OptionButton.new()
	for name in ["Nome A–Z","Mais recentes","Tamanho"]:
		order.add_item(name)
	order.item_selected.connect(func(_index): populate())
	toolbar.add_child(order)
	catalog.add_child(toolbar)
	list = ItemList.new()
	list.custom_minimum_size.y = 230
	list.item_selected.connect(select_entry)
	catalog.add_child(list)
	inspector = VBoxContainer.new()
	catalog.add_child(inspector)
	populate()
	get_viewport().files_dropped.connect(files_dropped)

func choose_file() -> void:
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Imagens e animações","*.wav,*.ogg,*.mp3 ; Áudio","*.png,*.jpg,*.jpeg,*.webp,*.wav,*.ogg,*.mp3 ; Todos os recursos suportados"])
	dialog.file_selected.connect(func(path): select_file(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.8)

func select_file(path: String) -> bool:
	info = library.inspect(path)
	preview_image.texture = null
	preview_hint.show()
	import_button.disabled = true
	if info.is_empty():
		picked_file = ""
		detail.text = library.error
		message.emit(library.error,true)
		return false
	picked_file = path
	metadata.name = info.name
	for input in find_children("*","LineEdit",true,false):
		if input.get_meta("metadata_key","") == "name":
			input.text = metadata.name
	if info.kind == "image":
		preview_hint.hide()
		preview_image.texture = ImageTexture.create_from_image(Image.load_from_file(path))
		detail.text = "%s\n%s · %.1f KB · %d × %d pixels" % [path.get_file(),str(info.format).to_upper(),info.bytes/1024.0,info.width,info.height]
		if category.selected in [2,3,4]:
			category.select(0)
			refresh_targets()
	else:
		preview_hint.text = "♫\nPrévia de áudio\nUse Ouvir para reproduzir"
		detail.text = "%s\n%s · %.1f KB · %.1f segundos\nUse Ouvir áudio antes de importar." % [path.get_file(),str(info.format).to_upper(),info.bytes/1024.0,info.seconds]
		if category.selected not in [2,3,4]:
			category.select(2)
			refresh_targets()
	progress.value = 0
	import_button.disabled = false
	return true

func play_preview() -> void:
	if not picked_file.is_empty() and info.get("kind") == "audio":
		audio.play_file(picked_file,"Music",0.7)
	else:
		message.emit("Selecione um arquivo de áudio para ouvir a prévia.",true)

func stop_audio() -> void:
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()

func refresh_targets() -> void:
	target.clear()
	target.add_item("Somente na biblioteca")
	target.set_item_metadata(0,{"type":"none","id":""})
	var is_audio = category.selected in [2,3,4]
	if not is_audio or category.selected in [3,4]:
		for character in store.data.characters:
			target.add_item("Personagem · " + character.name)
			target.set_item_metadata(target.item_count-1,{"type":"character","id":character.id})
	if category.selected in [2,5,6]:
		for arena in store.data.arenas:
			target.add_item("Arena · " + arena.name)
			target.set_item_metadata(target.item_count-1,{"type":"arena","id":arena.id})
	if category.selected in [2,7]:
		target.add_item("Menu principal")
		target.set_item_metadata(target.item_count-1,{"type":"interface","id":"menu"})
	if category.selected == 3:
		target.add_item("Impactos da luta")
		target.set_item_metadata(target.item_count-1,{"type":"audio","id":"effects"})
	refresh_slots()

func refresh_slots() -> void:
	slot.clear()
	var value: Dictionary = target.get_item_metadata(target.selected)
	var options: Array = []
	match value.type:
		"none": options = [["Disponível para uso posterior","none"]]
		"character": options = [["Sprite / roupa completa","sprite"]] if category.selected not in [3,4] else [["Entrada","voice/entry"],["Introdução","voice/intro"],["Ataques","voice/attack"],["Especiais","voice/special"],["Superespecial","voice/super"],["Ferimento","voice/hurt"],["Vitória","voice/victory"],["Derrota","voice/defeat"],["Finalização","voice/finisher"],["Provocação","voice/taunt"],["Rival","voice/rival"]]
		"arena": options = [["Música da arena","music"]] if category.selected == 2 else [["Elemento de plateia","crowd"]] if category.selected == 6 else [["Cenário completo","background"]]
		"interface": options = [["Música do menu","music"]] if category.selected == 2 else [["Fundo do menu","background"]]
		"audio": options = [["Som de impacto","effects"]]
	for pair in options:
		slot.add_item(pair[0])
		slot.set_item_metadata(slot.item_count-1,pair[1])

func import_selected() -> bool:
	if importing or picked_file.is_empty():
		return false
	importing = true
	progress.value = 20
	var entry = library.import_file(picked_file,store.path.get_base_dir(),category.get_item_text(category.selected),metadata,store.data)
	if entry.is_empty():
		progress.value = 0
		importing = false
		message.emit(library.error,true)
		return false
	progress.value = 70
	var destination: Dictionary = target.get_item_metadata(target.selected)
	if not library.link(store.data,entry,destination.type,destination.id,slot.get_item_metadata(slot.selected)):
		changed.emit()
		message.emit("Arquivo na biblioteca; vínculo rejeitado: "+library.error,true)
		importing = false
		populate()
		return false
	progress.value = 100
	selected_id = entry.id
	changed.emit()
	populate()
	progress.value = 100
	message.emit("Importação concluída: "+entry.name+". Salve o projeto para persistir a biblioteca.",false)
	importing = false
	return true

func begin_import() -> void:
	if importing or import_queued or picked_file.is_empty():
		return
	import_queued = true
	import_button.disabled = true
	progress.value = 10
	await get_tree().process_frame
	import_selected()
	import_queued = false
	import_button.disabled = picked_file.is_empty()

func files_dropped(files: PackedStringArray) -> void:
	if not is_visible_in_tree():
		return
	if files.size() == 1:
		select_file(files[0])
	elif files.size() > 1:
		message.emit("Importando %d arquivos para a biblioteca, sem vínculos automáticos." % files.size(),false)
		for index in files.size():
			if select_file(files[index]):
				target.select(0)
				refresh_slots()
				import_selected()
			await get_tree().process_frame

func populate() -> void:
	list.clear()
	UI.clear(inspector)
	var entries: Array = store.data.get("library",[]).filter(func(entry): return (filter.selected == 0 or entry.category == filter.get_item_text(filter.selected)) and (search.text.is_empty() or str(entry.name).to_lower().contains(search.text.to_lower()) or str(entry.file).contains(search.text)))
	entries.sort_custom(func(a,b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0 if order.selected == 0 else a.imported_at > b.imported_at if order.selected == 1 else a.bytes > b.bytes)
	for entry in entries:
		list.add_item("%s  ·  %s  ·  %s  ·  %.1f KB" % [entry.name,entry.category,str(entry.format).to_upper(),entry.bytes/1024.0])
		list.set_item_metadata(list.item_count-1,entry.id)
		if entry.id == selected_id:
			list.select(list.item_count-1)
	if entries.is_empty():
		inspector.add_child(label("Nenhum recurso nesta seleção. Importe um arquivo acima ou ajuste a pesquisa.",16))
	elif not list.get_selected_items().is_empty():
		select_entry(list.get_selected_items()[0])

func select_entry(index: int) -> void:
	selected_id = list.get_item_metadata(index)
	UI.clear(inspector)
	for entry in store.data.get("library",[]):
		if entry.id != selected_id:
			continue
		select_file(store.asset_path(entry.file))
		metadata = entry.license.duplicate(true)
		metadata.name = entry.name
		category.select(Library.CATEGORIES.find(entry.category))
		refresh_targets()
		for input in find_children("*","LineEdit",true,false):
			var key = str(input.get_meta("metadata_key",""))
			if not key.is_empty():
				input.text = str(metadata.get(key,""))
		var name = LineEdit.new()
		name.text = entry.name
		name.placeholder_text = "Nome na biblioteca"
		name.text_changed.connect(func(value): entry.name = value; changed.emit())
		inspector.add_child(name)
		for pair in [["Origem","source"],["Licença","license"],["Autorização","authorization"]]:
			inspector.add_child(label(pair[0],14))
			var input = LineEdit.new()
			input.text = str(entry.license.get(pair[1],""))
			input.text_changed.connect(func(value): entry.license[pair[1]] = value; Library.sync_license(store.data,entry); changed.emit())
			inspector.add_child(input)
		var uses = Library.dependencies(store.data,entry.file)
		inspector.add_child(label("Onde é usado:\n"+("Ainda sem vínculos." if uses.is_empty() else "\n".join(uses)),15))
		if not uses.is_empty():
			inspector.add_child(button("Desvincular dos locais acima…",func(): request_unlink(entry)))
		inspector.add_child(button("Excluir da biblioteca…",func(): request_remove(entry)))
		inspector.add_child(button("Aplicar vínculo escolhido acima",func():
			var destination: Dictionary = target.get_item_metadata(target.selected)
			if library.link(store.data,entry,destination.type,destination.id,slot.get_item_metadata(slot.selected)):
				changed.emit()
				populate()
				message.emit("Vínculo atualizado. Salve o projeto.",false)
			else:
				message.emit(library.error,true)
		))

func request_remove(entry: Dictionary) -> void:
	var uses = Library.dependencies(store.data,entry.file)
	var dialog = ConfirmationDialog.new()
	dialog.title = "Excluir recurso"
	dialog.dialog_text = "Excluir %s da biblioteca? Os bytes são preservados para backups e desfazer." % entry.name if uses.is_empty() else "Este recurso está em uso:\n"+"\n".join(uses)+"\nRemova os vínculos antes de excluir."
	dialog.get_ok_button().disabled = not uses.is_empty()
	dialog.confirmed.connect(func():
		if library.remove(store.data,entry.id):
			changed.emit()
			populate()
			message.emit("Recurso removido da biblioteca. Pode ser recuperado com Desfazer.",false)
		else:
			message.emit(library.error,true)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(540,220))

func request_unlink(entry: Dictionary) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Desvincular recurso"
	dialog.dialog_text = "Remover os usos de %s?\n%s\nO recurso continuará na biblioteca. Desfazer recupera os vínculos." % [entry.name,"\n".join(Library.dependencies(store.data,entry.file))]
	dialog.confirmed.connect(func(): Library.unlink(store.data,entry.file); changed.emit(); populate(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(580,260))
