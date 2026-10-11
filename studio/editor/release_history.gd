extends RefCounted
const Store = preload("res://runtime/content_store.gd")

static func fingerprint(data: Dictionary) -> String:
	return JSON.stringify(data).sha256_text()

static func read_history(workspace: String) -> Array:
	var path = workspace.path_join("dist/build-history.json")
	for source in [path,path+".bak"]:
		if FileAccess.file_exists(source):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(source))
			if parsed is Dictionary and parsed.get("schema_version") == 1 and parsed.get("builds") is Array:
				return parsed.builds
	return []

static func latest(workspace: String) -> Dictionary:
	var history = read_history(workspace)
	return history[-1] if not history.is_empty() else {}

static func register(workspace: String, record: Dictionary) -> Error:
	var history = read_history(workspace)
	history.append(record)
	var status = Store.write_atomic(workspace.path_join("dist/build-history.json"),{"schema_version":1,"builds":history})
	if status != OK:
		return status
	status = Store.write_atomic(workspace.path_join("dist/player/current.json"),record)
	if status != OK:
		return status
	var launcher_path = workspace.path_join("dist/player/current.cmd")
	var file = FileAccess.open(launcher_path+".tmp",FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("@echo off\r\nstart \"\" \"%~dp0versions\\"+record.build_id+"\\FightForDemocracy.exe\"\r\n")
	file.close()
	return DirAccess.rename_absolute(launcher_path+".tmp",launcher_path)

static func prepare_steam(workspace: String, data: Dictionary) -> Dictionary:
	var record = latest(workspace)
	if record.is_empty() or record.get("content_hash") != fingerprint(data):
		return {"success":false,"message":"Gere uma versão verificada com as alterações atuais antes de preparar a Steam."}
	if not FileAccess.file_exists(record.executable) or FileAccess.get_sha256(record.executable) != record.get("executable_sha256") or FileAccess.get_sha256(str(record.executable).get_basename()+".pck") != record.get("pck_sha256"):
		return {"success":false,"message":"A compilação foi removida ou alterada. Gere uma nova versão antes de preparar a Steam."}
	var destination = workspace.path_join("dist/steam/"+record.build_id+"-%d" % int(Time.get_unix_time_from_system()*1000))
	var payload = destination.path_join("content")
	DirAccess.make_dir_recursive_absolute(payload)
	for name in ["FightForDemocracy.exe","FightForDemocracy.pck","GODOT-COPYRIGHT.txt","GODOT-LICENSE.txt","LEIA-ME.txt","manifest.json"]:
		if DirAccess.copy_absolute(str(record.executable).get_base_dir().path_join(name),payload.path_join(name)) != OK:
			return {"success":false,"message":"Não foi possível copiar "+name+". Confira o arquivo da compilação."}
	var files = {
		"release-notes.md":"Fight for Democracy "+record.version+"\n\n"+record.get("release_notes","")+"\n",
		"app_build.vdf":"\"appbuild\"\n{\n\t\"appid\" \"APP_ID\"\n\t\"desc\" \"Fight for Democracy "+record.version+"\"\n\t\"buildoutput\" \"output\"\n\t\"contentroot\" \"content\"\n\t\"depots\" { \"DEPOT_ID\" \"depot_build.vdf\" }\n}\n",
		"depot_build.vdf":"\"DepotBuildConfig\"\n{\n\t\"DepotID\" \"DEPOT_ID\"\n\t\"FileMapping\" { \"LocalPath\" \"*\" \"DepotPath\" \".\" \"recursive\" \"1\" }\n}\n",
		"PUBLICACAO-MANUAL.txt":"Pacote local; nada foi enviado à Steam.\n1. Cadastre o aplicativo na sua conta Steamworks e obtenha App ID e Depot ID.\n2. Substitua APP_ID e DEPOT_ID nos dois VDF.\n3. Revise direitos de arte/áudio, ficha da loja e compatibilidade.\n4. Use o SteamPipe SDK/steamcmd da sua conta com run_app_build app_build.vdf.\n5. Selecione uma branch de teste, confira o upload no Steamworks e teste a instalação.\n6. Publique pela interface Steamworks após as aprovações exigidas pela plataforma.\nNenhuma credencial ou integração de upload está configurada neste Studio.\n"}
	for name in files:
		var file = FileAccess.open(destination.path_join(name),FileAccess.WRITE)
		if file == null:
			return {"success":false,"message":"Falha ao escrever "+name}
		file.store_string(files[name])
	Store.write_atomic(destination.path_join("build.json"),record)
	return {"success":true,"message":"Pacote Steam preparado em "+destination+". Upload e publicação são manuais.","folder":destination}
