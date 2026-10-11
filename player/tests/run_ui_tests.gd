extends SceneTree
const App = preload("res://ui/player_app.gd")
const Campaign = preload("res://runtime/campaign_system.gd")
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
		printerr("FAIL: " + title)

func buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(buttons(child))
	return result

func controls(node: Node, kind: String) -> Array:
	var result: Array = [node] if node.is_class(kind) else []
	for child in node.get_children():
		result.append_array(controls(child,kind))
	return result

func run() -> void:
	app = App.new()
	root.add_child(app)
	app.saves.base_path = "user://ui_test_%d" % Time.get_ticks_usec()
	app.profile = "Teste isolado"
	app.selection("career")
	buttons(app.screen).filter(func(button): return button.text == "ENTRAR NA ARENA")[0].pressed.emit()
	check(app.career_active and app.career.schedule.size() == 114,"Menu inicia carreira por controles reais")
	var chosen: String = app.career.character
	var original_opponent: String = app.career.schedule[0].opponent
	app.start_match(chosen,original_opponent)
	app.combat.set_physics_process(false)
	app.combat.fighters[0].health = 0
	app.combat.complete()
	check(app.career.losses == 1 and app.career.next_fight == 0 and app.career.schedule[0].opponent == original_opponent,"Derrota conserva confronto no fluxo completo")
	app.main_menu()
	app.continue_career()
	check(app.career.character == chosen and int(app.career.next_fight) == 0 and int(app.career.losses) == 1,"Continuar recupera personagem e derrota")
	for index in 7:
		var fight: Dictionary = app.career.schedule[int(app.career.next_fight)]
		app.start_match(chosen,fight.opponent)
		app.combat.set_physics_process(false)
		app.combat.fighters[1].health = 0
		app.combat.complete()
		if index < 6:
			app.career_map()
	check(int(app.career.next_fight) == 7 and int(app.career.wins) == 7 and app.career.defeated.size() == 7,"Vitórias progridem uma única luta")
	check(int(app.career.schedule[7].rank) == 1,"Promoção de Vereador para Prefeito")
	check(app.career.character == chosen and app.career.propina > 0,"Carreira mantém lutador e concede Propina")
	app.main_menu()
	app.continue_career()
	check(int(app.career.next_fight) == 7 and app.career.defeated.size() == 7,"Vitórias salvas após cada confronto")
	app.career_active = false
	app.start_match("teste_aurora","teste_torquato","training")
	app.combat.set_physics_process(false)
	app.combat.fighters[1].health = 0
	app.combat.complete()
	check(int(app.saves.load_profile(app.profile).next_fight) == 7,"Treinamento não modifica progresso oficial")
	app.main_menu()
	var schedule = Campaign.new().generate(app.store.data,"teste_torquato","esquerda",2026)
	app.career = app.saves.new_career("teste_torquato","esquerda",schedule,2026)
	app.career.next_fight = 113
	app.career.wins = 113
	app.career.defeated = schedule.slice(0,113).map(func(f): return f.opponent)
	app.career_active = true
	app.start_match("teste_torquato",schedule[-1].opponent,"ai",schedule[-1].arena,7)
	app.combat.set_physics_process(false)
	check(app.combat.narrative_boss and app.combat.fighters[1].invincible,"Chefe narrativo invencível apenas na rota")
	check(controls(app.screen,"Label").any(func(label): return "PARADOXO DA URNA-X" in label.text),"Aviso do Paradoxo visível antes do primeiro golpe")
	app.combat.tick = 1800
	app.combat.complete()
	check(app.career.completed and app.career.next_fight == 114 and app.career.wins == 113,"Desfecho narrativo não registra vitória falsa")
	app.career_active = false
	app.start_match("teste_aurora","teste_guardiao","local")
	app.combat.set_physics_process(false)
	app.combat.fighters[1].receive_hit({"damage":1000,"stun":1,"knockback":0},590,1)
	check(not app.combat.narrative_boss and app.combat.fighters[1].health == 0,"Enéas pode sofrer KO no Versus real")
	app.main_menu()
	app.profile = "Independentes isolado"
	app.selection("career")
	var factions = controls(app.screen,"OptionButton")[0]
	check(factions.item_count == 4,"Menu de carreira oferece quatro facções")
	factions.select(3)
	factions.item_selected.emit(3)
	check(controls(app.screen,"ItemList")[0].item_count == 34,"Independentes disponibiliza os 34 personagens comuns e reserva dois chefes")
	buttons(app.screen).filter(func(button): return button.text == "ENTRAR NA ARENA")[0].pressed.emit()
	check(app.career.faction == "independente" and app.career.schedule.size() == 114 and app.career.schedule[-1].opponent == "teste_regente","Controles reais iniciam a quarta carreira com Lula no final")
	var independent_order = app.career.schedule.map(func(f): return f.opponent)
	app.main_menu()
	app.continue_career()
	check(app.career.faction == "independente" and independent_order == app.career.schedule.map(func(f): return f.opponent),"Quarta carreira retoma a sequência salva")
	app.career.next_fight = 113
	app.start_match(app.career.character,"teste_regente","ai","trono_urna_x",7)
	app.combat.set_physics_process(false)
	check(not app.combat.narrative_boss and not app.combat.fighters[1].invincible,"Lula permanece vencível na carreira Independente")
	app.main_menu()
	var legacy = Campaign.new().generate(app.store.data,"teste_aurora","direita",2026)
	legacy[0].opponent = "teste_guardiao"
	var legacy_progress = app.saves.new_career("teste_aurora","direita",legacy,2026)
	legacy_progress.erase("schedule_rules")
	app.profile = "Legado isolado"
	app.saves.save(app.profile,legacy_progress)
	app.continue_career()
	check(app.career_active and app.career.schedule[0].opponent == "teste_guardiao" and app.career.next_fight == 0,"Continuar preserva adversário de uma carreira anterior sem regenerar")
	app.queue_free()
	await process_frame
	print("PLAYER UI TESTS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed > 0 else 0)
