extends SceneTree
const Store = preload("res://runtime/content_store.gd")
const Campaign = preload("res://runtime/campaign_system.gd")
const Exporter = preload("res://editor/export_manager.gd")
var exporter: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var workspace = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var store = Store.new()
	if not store.load_file(workspace.path_join("content/project.json")):
		printerr("\n".join(store.errors))
		quit(1)
		return
	for i in store.data.factions.size():
		var faction: Dictionary = store.data.factions[i]
		for character in store.data.characters:
			if character.faction != faction.id or character.boss or not character.campaign_enabled:
				continue
			var generator = Campaign.new()
			if generator.generate(store.data,character.id,faction.id,int(store.data.campaign.seed)).is_empty():
				printerr("\n".join(generator.errors))
				quit(1)
				return
	exporter = Exporter.new()
	root.add_child(exporter)
	exporter.completed.connect(func(success,message): print(message); quit(0 if success else 1))
	exporter.export_player(store,workspace,workspace.path_join("tools/godot/Godot_v4.7.2-stable_win64_console.exe"),"--omit-unlicensed" in OS.get_cmdline_user_args())
