extends SceneTree
const App = preload("res://tests/dialog_fixture.gd")
const Store = preload("res://runtime/content_store.gd")
const Exporter = preload("res://editor/export_manager.gd")
const Importer = preload("res://editor/catalog_importer.gd")
const Campaign = preload("res://runtime/campaign_system.gd")
var passed = 0
var failed = 0
var app: Control
var original_path = ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + title)

func collect(node: Node, kind: String) -> Array:
	var result: Array = []
	if node.is_class(kind):
		result.append(node)
	for child in node.get_children():
		result.append_array(collect(child,kind))
	return result

func run() -> void:
	app = App.new()
	root.add_child(app)
	original_path = app.store.path
	check(app.store.load_file(app.workspace.path_join("player/tests/fixtures/project.json")),"Fixture independente do conteúdo de autoria")
	app.store.data = app.store.data.duplicate(true)
	app.store.path = "user://studio_test_%d/project.json" % Time.get_ticks_usec()
	app.reset_history()
	for section in ["Dashboard","Personagens","Golpes","Áudio","Arenas","Campanha","Chefes","Economia","História","Menus","Testador"]:
		app.show_page(section)
		await process_frame
		check(app.page.get_child_count() > 1,"Página funcional: " + section)
	app.show_page("Personagens")
	var inputs = collect(app.page,"LineEdit")
	var name = inputs.filter(func(node): return node.text == app.store.data.characters[0].name)[0]
	name.text = "Aurora editada no Studio"
	name.text_changed.emit(name.text)
	check(app.store.data.characters[0].name == name.text and app.dirty,"Editor de nome altera dados")
	var health = collect(app.page,"SpinBox").filter(func(node): return node.value == 100)[0]
	health.value = 145
	check(app.store.data.characters[0].stats.health == 145,"Editor de atributos")
	var picker = collect(app.page,"ColorPickerButton")[0]
	picker.color = Color("#123abc")
	picker.color_changed.emit(picker.color)
	check(app.store.data.characters[0].palette.clothes == "#123abc","Paleta visual altera dados")
	check(app.save_project(),"Studio salva projeto editado")
	var runtime = Store.new()
	check(runtime.load_file(app.store.path) and runtime.character("teste_aurora").stats.health == 145 and runtime.character("teste_aurora").name == name.text,"Edição visual chega aos dados do Player")
	var previous_size = app.store.data.characters.size()
	app.add_character()
	check(app.store.data.characters.size() == previous_size+1,"Adicionar personagem")
	app.remove_character()
	check(app.store.data.characters.size() == previous_size,"Remover personagem")
	app.selected = 0
	app.show_page("Golpes")
	app.preview.test_move("special_a")
	app.preview.fighter.step({},1500)
	check(app.preview.fighter.attack_id == "special_a" and app.preview.fighter.fame == 65,"Testador de golpe usa motor real")
	check(app.validate_all(),"Validação de todas as rotas")
	app.store.data.characters[0].stats.health = -5
	check(not app.save_project() and "rejeitado" in app.status_label.text,"Salvamento inválido rejeitado pela interface")
	app.store.data.characters[0].stats.health = 145
	test_catalog_and_history()
	test_imports()
	var exporter = Exporter.new()
	root.add_child(exporter)
	var outcome: Array = []
	exporter.completed.connect(func(success,message): outcome.append([success,message]))
	exporter.export_player(app.store,app.workspace,"missing_godot.exe")
	check(outcome.size() == 1 and outcome[0][0] == false and "Godot ausente" in outcome[0][1],"Exportação sem Godot nunca anuncia sucesso")
	check(original_path != app.store.path,"Testes isolados do conteúdo oficial")
	app.queue_free()
	exporter.queue_free()
	await process_frame
	print("STUDIO TESTS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed > 0 else 0)

func test_catalog_and_history() -> void:
	app.show_page("Dashboard")
	app.reset_history()
	var original = app.store.data.duplicate(true)
	var packet = {"format":"ffd.catalog","version":1,"characters":[]}
	for character in app.store.data.characters:
		packet.characters.append({"id":character.id,"name":character.name+" importado","stats":{"health":character.stats.health+1}})
	var source = app.store.path.get_base_dir().path_join("catalog.json")
	check(Store.write_atomic(source,packet) == OK and app.prepare_import_file(source),"Prévia de catálogo real valida 156 registros")
	check(JSON.stringify(app.store.data) == JSON.stringify(original),"Prévia não modifica o projeto aberto")
	check(app.apply_import() and app.store.data.characters[0].name.ends_with("importado"),"Aplicar importa dados e registra histórico")
	check(JSON.stringify(app.store.data.characters[0].moves) == JSON.stringify(original.characters[0].moves) and app.store.data.characters.map(func(c): return c.id) == original.characters.map(func(c): return c.id),"Importação parcial preserva golpes e todos os IDs")
	app.undo_edit()
	check(JSON.stringify(app.store.data) == JSON.stringify(original) and not app.dirty,"Desfazer restaura o catálogo e o estado salvo")
	app.redo_edit()
	check(app.store.data.characters[0].name.ends_with("importado") and app.dirty,"Refazer reaplica a importação")
	app.undo_edit()
	var importer = Importer.new()
	var bad: Dictionary = packet.duplicate(true)
	bad.characters[1].id = bad.characters[0].id
	check(not importer.prepare(bad,app.store) and importer.candidate.is_empty() and JSON.stringify(app.store.data) == JSON.stringify(original),"IDs duplicados rejeitados sem alteração parcial")
	bad = packet.duplicate(true)
	bad.characters[0].stats.health = "quebrado"
	check(not importer.prepare(bad,app.store) and JSON.stringify(app.store.data) == JSON.stringify(original),"Atributo malformado rejeitado durante importação")
	bad = packet.duplicate(true)
	bad.characters[0].faction = "esquerda"
	check(not importer.prepare(bad,app.store),"Distribuição 40/40/40/36 exigida na importação")
	bad = packet.duplicate(true)
	bad.characters[0].id = "id_externo"
	check(not importer.prepare(bad,app.store),"ID externo exige mapeamento explícito")
	bad.id_map = {"id_externo":"teste_aurora"}
	check(importer.prepare(bad,app.store) and importer.candidate.characters[0].id == "teste_aurora","Mapeamento externo mantém o ID usado pelos saves")
	bad = packet.duplicate(true)
	bad.characters.resize(155)
	check(not importer.prepare(bad,app.store),"Catálogo incompleto rejeitado")
	var campaigns = {"format":"ffd.campaigns","version":1,"routes":{}}
	for faction in app.store.data.factions:
		var chosen: String = app.store.data.characters.filter(func(c): return c.faction == faction.id and not c.boss)[0].id
		campaigns.routes[faction.id] = Campaign.new().generate(app.store.data,chosen,faction.id,2026)
	check(importer.prepare(campaigns,app.store) and importer.candidate.campaign.routes.size() == 4,"Importação real de quatro rotas completas")
	bad = campaigns.duplicate(true)
	bad.routes.independente[1].opponent = bad.routes.independente[0].opponent
	check(not importer.prepare(bad,app.store),"Duplicata na rota Independente rejeitada")
	bad = campaigns.duplicate(true)
	bad.routes.direita[0].opponent = "teste_guardiao"
	check(not importer.prepare(bad,app.store),"Chefe antecipado de outra rota rejeitado pelo importador")
	bad = campaigns.duplicate(true)
	bad.routes.erase("independente")
	check(not importer.prepare(bad,app.store),"Importação exige a quarta rota")
	bad = packet.duplicate(true)
	bad.characters[0].sprite = "assets/arquivo_ausente.png"
	check(not importer.prepare(bad,app.store),"Arquivo ausente rejeitado antes da aplicação")
	var invalid_file = FileAccess.open(source,FileAccess.WRITE)
	invalid_file.store_string("{ JSON quebrado")
	invalid_file.close()
	check(not app.prepare_import_file(source) and "linha" in app.status_label.text,"Importação de JSON quebrado mostra linha e preserva o projeto")
	Store.write_atomic(source,packet)
	app.prepare_import_file(source)
	app.store.data.characters[0].description += " Edição posterior."
	app.modified()
	check(not app.apply_import(),"Prévia expirada não sobrescreve uma edição recente")
	app.undo_edit()
	app.store.data.characters[0].stats.health = 166
	app.modified()
	app.undo_edit()
	check(app.store.data.characters[0].stats.health == original.characters[0].stats.health,"Desfazer também restaura atributos")
	app.store.data.characters[0].stats.health = 167
	app.modified()
	check(app.redo_stack.is_empty(),"Edição depois de desfazer descarta a ramificação de refazer")
	app.undo_edit()
	app.show_page("Golpes")
	var hitbox_spin = collect(app.page,"SpinBox").filter(func(node): return node.value == 175)[0]
	hitbox_spin.value = 180
	check(app.store.data.characters[0].moves.light_punch.hitbox.offset_y == 180 and app.preview.fighter.config.moves.light_punch.hitbox.offset_y == 180,"Editor visual de colisão atualiza preview real")
	app.undo_edit()
	app.show_page("Chefes")
	check(collect(app.page,"Label").any(func(node): return "PARADOXO" in node.text),"Editor de chefes explicita condição narrativa limitada")
	app.show_page("Dashboard")
	app.chosen_file = ProjectSettings.globalize_path(source)
	app.export_import_template()
	check(importer.prepare_file(source,app.store) and importer.candidate.campaign.routes.size() == 4,"Modelo exportado pelo Studio pode ser importado com quatro rotas")
	app.show_page("Golpes")

func test_imports() -> void:
	var directory = app.store.path.get_base_dir()
	var image = Image.create(64,64,false,Image.FORMAT_RGBA8)
	image.fill(Color("#65d6a0"))
	var source_image = directory.path_join("source.png")
	image.save_png(source_image)
	app.chosen_file = ProjectSettings.globalize_path(source_image)
	app.import_asset(["*.png"],func(relative): app.store.data.characters[0].sprite = relative)
	check(app.store.data.characters[0].sprite.begins_with("assets/") and FileAccess.file_exists(app.store.asset_path(app.store.data.characters[0].sprite)),"Imagem importada e copiada de verdade")
	check(app.save_project(),"Projeto com sprite importado salva")
	check(not app.store.validate_distribution().is_empty(),"Exportação rejeita imagem sem registro de licença")
	app.show_page("Personagens")
	var license_inputs = collect(app.page,"LineEdit").filter(func(node): return node.text.is_empty())
	for input in license_inputs:
		input.text = "Arte original de teste — autorização própria"
		input.text_changed.emit(input.text)
	check(app.store.validate_distribution().is_empty(),"Registro visual de licença libera recurso original para exportação")
	app.show_page("Golpes")
	app.refresh_preview()
	check(app.preview.fighter.texture != null,"Preview carrega sprite importado")
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var pcm = PackedByteArray()
	pcm.resize(4410)
	stream.data = pcm
	var source_audio = directory.path_join("source.wav")
	stream.save_to_wav(source_audio)
	app.chosen_file = ProjectSettings.globalize_path(source_audio)
	app.import_asset(["*.wav"],func(relative): app.store.data.characters[0].voices.entry = [{"file":relative,"weight":1.0,"volume":0.8,"interval":2.0,"source":"","license":"","authorization":""}])
	var clip: Dictionary = app.store.data.characters[0].voices.entry[0]
	check(app.audio.load_stream(app.store.asset_path(clip.file)) != null,"Áudio importado e decodificado")
	check(not app.save_project(),"Voz sem registro de licença rejeitada")
	clip.source = "Fixture de testes: PCM original silencioso"
	clip.license = "Recurso de teste criado pelo projeto"
	clip.authorization = "Autoria própria, somente testes"
	check(app.save_project(),"Áudio com metadados válidos salva")
