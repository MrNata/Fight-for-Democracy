extends SceneTree
const Store = preload("res://runtime/content_store.gd")
const Exporter = preload("res://editor/export_manager.gd")
const History = preload("res://editor/release_history.gd")
var passed = 0
var failed = 0
var exporter: Node
var completed_result: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: "+title)

func run() -> void:
	var workspace = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--workspace="):
			workspace = arg.trim_prefix("--workspace=")
	if workspace.is_empty() or not workspace.replace("\\","/").contains("/build/export-ux-"):
		printerr("Workspace isolado obrigatório para este teste.")
		quit(1)
		return
	var store = Store.new()
	check(store.load_file(workspace.path_join("content/project.json")),"Conteúdo de teste válido")
	var engine = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("tools/godot/Godot_v4.7.2-stable_win64_console.exe")
	exporter = Exporter.new()
	root.add_child(exporter)
	exporter.completed.connect(func(success,message): completed_result.append([success,message]))
	exporter.export_player(store,workspace,engine)
	var competitor = Exporter.new()
	root.add_child(competitor)
	var rejection: Array = []
	competitor.completed.connect(func(success,message): rejection.append([success,message]))
	competitor.export_player(store,workspace,engine)
	check(exporter.busy and rejection.size() == 1 and not rejection[0][0],"Bloqueio impede duas preparações concorrentes")
	while exporter.busy:
		await process_frame
	check(completed_result.size() == 1 and completed_result[0][0],"Primeiro executável Windows exportado e inicializado")
	var first = History.latest(workspace)
	if first.is_empty():
		printerr(str(completed_result))
		quit(1)
		return
	check(first.verified and first.version == "0.3.0" and FileAccess.file_exists(first.executable),"Histórico só contém exportação verificada")
	var hash_before = FileAccess.get_sha256(first.executable)
	var pack_before = FileAccess.get_sha256(str(first.executable).get_basename()+".pck")
	var old_pid = OS.create_process(first.executable,["--headless","--max-fps","60","--quit-after","18000","--","--controls-file="+workspace.path_join("first-controls.json")])
	await create_timer(0.4).timeout
	check(old_pid > 0 and OS.is_process_running(old_pid),"Versão anterior permanece em execução durante atualização")
	store.data.characters[0].stats.health += 1
	store.data.project_version = "0.3.1"
	store.data.release_notes = "Teste de atualização com atributo editado."
	exporter.export_player(store,workspace,engine)
	while exporter.busy:
		await process_frame
	check(completed_result.size() == 2 and completed_result[1][0],"Nova versão após edição é realmente compilada")
	var second = History.latest(workspace)
	check(second.version == "0.3.1" and second.executable != first.executable and History.read_history(workspace).size() == 2,"Duas versões independentes com histórico e notas")
	check(OS.is_process_running(old_pid) and FileAccess.get_sha256(first.executable) == hash_before and FileAccess.get_sha256(str(first.executable).get_basename()+".pck") == pack_before,"Atualização não substitui exe nem pacote em uso")
	if old_pid > 0:
		OS.kill(old_pid)
	check(second.content_hash == History.fingerprint(store.data) and second.release_notes == store.data.release_notes,"Histórico corresponde aos dados e notas da atualização")
	var pointer = JSON.parse_string(FileAccess.get_file_as_string(workspace.path_join("dist/player/current.json")))
	check(pointer.executable == second.executable and FileAccess.file_exists(workspace.path_join("dist/player/current.cmd")),"Atalho aponta para a última versão aprovada")
	check(not DirAccess.dir_exists_absolute(workspace.path_join("build/export.lock")),"Trava é liberada após o resultado")
	var steam = History.prepare_steam(workspace,store.data)
	check(steam.success and FileAccess.file_exists(str(steam.get("folder","")).path_join("content/FightForDemocracy.exe")) and FileAccess.file_exists(str(steam.get("folder","")).path_join("app_build.vdf")),"Pacote Steam local contém executável real e templates")
	store.data.characters[0].stats.health += 1
	check(not History.prepare_steam(workspace,store.data).success,"Alterações ainda não compiladas impedem preparar pacote desatualizado")
	Store.write_atomic(workspace.path_join("test-results.json"),{"passed":passed,"failed":failed,"first":first,"second":second,"steam":steam})
	exporter.queue_free()
	competitor.queue_free()
	await process_frame
	print("EXPORT INTEGRATION TESTS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
