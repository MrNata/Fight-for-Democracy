extends Node
signal completed(success: bool, message: String)
const Store = preload("res://runtime/content_store.gd")
const History = preload("res://editor/release_history.gd")
var thread: Thread
var busy = false
var root = ""
var engine_path = ""
var output = ""
var phase = "Pronto"
var progress = 0.0
var build_record: Dictionary = {}
var lock_path = ""

func fail(message: String) -> void:
	release_lock()
	phase = "Falha"
	progress = 0
	if not root.is_empty():
		DirAccess.make_dir_recursive_absolute(root.path_join("build"))
		var error_log = FileAccess.open(root.path_join("build/last-export-error.log"),FileAccess.WRITE)
		if error_log:
			error_log.store_string(Time.get_datetime_string_from_system(true)+" UTC\n"+message)
	completed.emit(false,message)

func acquire_lock() -> bool:
	lock_path = root.path_join("build/export.lock")
	DirAccess.make_dir_recursive_absolute(lock_path.get_base_dir())
	if DirAccess.dir_exists_absolute(lock_path):
		var owner_file = lock_path.path_join("owner.json")
		var owner = JSON.parse_string(FileAccess.get_file_as_string(owner_file)) if FileAccess.file_exists(owner_file) else null
		if owner is Dictionary and not OS.is_process_running(int(owner.get("pid",-1))):
			DirAccess.remove_absolute(owner_file)
			DirAccess.remove_absolute(lock_path)
	if DirAccess.make_dir_absolute(lock_path) != OK:
		completed.emit(false,"Outra exportação está preparando o Player. Aguarde a conclusão.")
		lock_path = ""
		return false
	Store.write_atomic(lock_path.path_join("owner.json"),{"pid":OS.get_process_id()})
	return true

func release_lock() -> void:
	if not lock_path.is_empty():
		DirAccess.remove_absolute(lock_path.path_join("owner.json"))
		DirAccess.remove_absolute(lock_path)
		lock_path = ""

func export_player(store: RefCounted, workspace: String, engine: String, omit_unlicensed: bool = false) -> void:
	if busy:
		return
	root = workspace
	engine_path = engine
	phase = "Validando e preparando arquivos"
	progress = 5
	if not FileAccess.file_exists(root.path_join("player/project.godot")):
		fail("Projeto Player não encontrado na pasta de trabalho.")
		return
	if not FileAccess.file_exists(engine_path):
		fail("Godot ausente. Selecione o executável estável em Configurações.")
		return
	for name in ["windows_release_x86_64.exe","windows_debug_x86_64.exe"]:
		if not FileAccess.file_exists(root.path_join("tools/godot/templates/"+name)):
			fail("Modelos Windows ausentes. Execute tools/bootstrap.py.")
			return
	var version = str(store.data.get("project_version","0.3.0"))
	var regex = RegEx.new()
	regex.compile("^[0-9]+\\.[0-9]+\\.[0-9]+(-[A-Za-z0-9.]+)?$")
	if regex.search(version) == null:
		fail("Use uma versão como 0.3.0 ou 0.3.0-beta.1.")
		return
	var prepared = store.distribution_snapshot(omit_unlicensed)
	var runtime_data: Dictionary = prepared.data
	var validator = Store.new()
	validator.data = runtime_data
	validator.path = store.path
	var license_errors = validator.validate_distribution()
	if not license_errors.is_empty():
		fail("Exportação rejeitada:\n"+"\n".join(license_errors.slice(0,12)))
		return
	if not store.save_file():
		fail("\n".join(store.errors))
		return
	if not acquire_lock():
		return
	var destination = root.path_join("player/data/default.json")
	if store.write_atomic(destination,runtime_data) != OK:
		fail("Não foi possível preparar os dados do Player.")
		return
	var resources: Array = []
	for character in runtime_data.characters:
		resources.append(character.get("sprite",""))
		for clips in character.voices.values():
			for clip in clips:
				resources.append(clip.file)
	for arena in runtime_data.arenas:
		for layer in arena.get("crowd",[]):
			resources.append(layer.file)
		resources.append(arena.get("background",""))
		resources.append(arena.get("music",""))
	for field in ["background","music"]:
		resources.append(runtime_data.menu.get(field,""))
	resources.append(runtime_data.get("resource_audio",{}).get("effects",""))
	var unique: Dictionary = {}
	for resource in resources:
		if str(resource).is_empty() or unique.has(resource):
			continue
		unique[resource] = true
		var target = destination.get_base_dir().path_join(resource)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var status = DirAccess.copy_absolute(store.path.get_base_dir().path_join(resource),target)
		if status != OK:
			fail("É impossível empacotar " + resource + ": " + error_string(status))
			return
	var preset = ConfigFile.new()
	if preset.load(root.path_join("player/export_presets.cfg")) != OK:
		fail("Preset de exportação Windows ausente ou inválido.")
		return
	var includes: PackedStringArray = ["data/default.json"]
	for resource in unique:
		includes.append("data/" + resource)
	preset.set_value("preset.0","include_filter",",".join(includes))
	preset.set_value("preset.0.options","application/file_version",version.split("-")[0])
	preset.set_value("preset.0.options","application/product_version",version.split("-")[0])
	if preset.save(root.path_join("player/export_presets.cfg")) != OK:
		fail("Falha ao preparar a lista de recursos.")
		return
	var build_id = "v%s-%d-%d" % [version,int(Time.get_unix_time_from_system()*1000),OS.get_process_id()]
	output = root.path_join("dist/player/versions/"+build_id+"/FightForDemocracy.exe")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	for pair in [["GODOT-COPYRIGHT.txt","GODOT-COPYRIGHT.txt"],["GODOT-LICENSE.txt","GODOT-LICENSE.txt"],["DISTRIBUTION-README.txt","LEIA-ME.txt"]]:
		var status = DirAccess.copy_absolute(root.path_join("docs/"+pair[0]),output.get_base_dir().path_join(pair[1]))
		if status != OK:
			fail("Falha ao incluir instruções/licenças: "+error_string(status))
			return
	var manifest = {"schema_version":1,"edition":"Player","version":version,"build_id":build_id,"assets":unique.keys(),"characters":store.data.characters.size(),"omitted_resources":prepared.omitted}
	if Store.write_atomic(output.get_base_dir().path_join("manifest.json"),manifest) != OK:
		fail("Falha ao escrever o manifesto.")
		return
	build_record = {"version":version,"build_id":build_id,"date":Time.get_datetime_string_from_system(true),"executable":output,"content_hash":History.fingerprint(store.data),"release_notes":str(store.data.get("release_notes","")),"omitted_resources":prepared.omitted,"verified":false}
	busy = true
	thread = Thread.new()
	thread.start(run_export)

func set_phase(value: String, percent: float) -> void:
	phase = value
	progress = percent

func run_export() -> Dictionary:
	var messages: Array = []
	call_deferred("set_phase","Importando recursos",25.0)
	var imported = OS.execute(engine_path,["--headless","--path",root.path_join("player"),"--editor","--import"],messages,true)
	var code = imported
	if imported == 0 and not "ERROR" in "\n".join(messages):
		call_deferred("set_phase","Compilando Player Edition para Windows",55.0)
		code = OS.execute(engine_path,["--headless","--path",root.path_join("player"),"--export-release","Windows Player",output],messages,true)
	var log_text = "\n".join(messages)
	var success = code == 0 and not "SCRIPT ERROR" in log_text and not "ERROR:" in log_text and FileAccess.file_exists(output) and FileAccess.file_exists(output.get_basename()+".pck")
	if success:
		call_deferred("set_phase","Verificando executável gerado",85.0)
		for mode in ["menu","battle"]:
			var smoke_log = output.get_base_dir().path_join("smoke-"+mode+".log")
			var args = PackedStringArray(["--headless","--quit-after","20","--log-file",smoke_log,"--","--controls-file="+output.get_base_dir().path_join("test-controls.json")])
			if mode == "battle":
				args.append_array(["--test-fight","--mode=ai"])
			var smoke_code = OS.execute(output,args,messages,true)
			var smoke_text = FileAccess.get_file_as_string(smoke_log) if FileAccess.file_exists(smoke_log) else "ERROR: log de inicialização ausente"
			log_text += "\n"+smoke_text
			success = success and smoke_code == 0 and not "ERROR" in smoke_text
	var log_file = FileAccess.open(output.get_base_dir().path_join("export.log"),FileAccess.WRITE)
	if log_file:
		log_file.store_string(log_text)
	return {"success":success,"message":("Exportação verificada: " + output) if success else "Falha na exportação. Log: "+output.get_base_dir().path_join("export.log")+"\n"+log_text.right(3000)}

func _process(_delta: float) -> void:
	if thread != null and not thread.is_alive():
		var result: Dictionary = thread.wait_to_finish()
		thread = null
		if result.success:
			build_record.verified = true
			build_record.executable_sha256 = FileAccess.get_sha256(output)
			build_record.pck_sha256 = FileAccess.get_sha256(output.get_basename()+".pck")
			var status = History.register(root,build_record)
			if status != OK:
				result.success = false
				result.message = "Executável gerado, mas o histórico/atalho não foi atualizado: "+error_string(status)
		release_lock()
		busy = false
		phase = "Concluído e verificado" if result.success else "Falha"
		progress = 100 if result.success else 0
		completed.emit(result.success,result.message)

func _exit_tree() -> void:
	if thread != null:
		thread.wait_to_finish()
	release_lock()
