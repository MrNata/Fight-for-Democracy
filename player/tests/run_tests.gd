extends SceneTree
const Store = preload("res://runtime/content_store.gd")
const Campaign = preload("res://runtime/campaign_system.gd")
const Economy = preload("res://runtime/economy_system.gd")
const Saves = preload("res://runtime/save_system.gd")
const Fighter = preload("res://runtime/fighter.gd")
const Match = preload("res://runtime/combat_match.gd")
const Characters = preload("res://runtime/character_system.gd")
var passed = 0
var failed = 0
var store = Store.new()
var temp = "user://tests_%d" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + title)

func run() -> void:
	check(store.load_file("res://tests/fixtures/project.json"),"Conteúdo inicial válido")
	if store.data.is_empty():
		quit(1)
		return
	var data: Dictionary = store.data
	check(data.characters.size() == 156,"156 slots")
	var counts: Dictionary = {}
	for character in data.characters:
		counts[character.faction] = counts.get(character.faction,0)+1
	check(counts == {"direita":40,"esquerda":40,"centrao":40,"independente":36},"Contagens do catálogo")
	check(data.campaign.ranks.size() == 7,"7 cargos")
	var campaign = Campaign.new()
	var first: Array = []
	for faction_index in data.factions.size():
		var faction: Dictionary = data.factions[faction_index]
		for character in data.characters:
			if character.faction != faction.id or character.boss:
				continue
			var schedule = campaign.generate(data,character.id,faction.id,2026)
			check(schedule.size() == 114,character.id+": 114 confrontos")
			if schedule.is_empty():
				continue
			check(schedule == campaign.generate(data,character.id,faction.id,2026),"Determinismo")
			check(schedule[-1].opponent == faction.boss,"Chefe reservado")
			var unique: Dictionary = {}
			var self_fight = false
			var early_boss = false
			for fight in schedule:
				unique[fight.opponent] = true
				self_fight = self_fight or fight.opponent == character.id
				if not fight.boss:
					early_boss = early_boss or store.character(fight.opponent).boss
			check(unique.size() == 114 and not self_fight and not early_boss,"Sem repetição, auto-confronto ou chefes antecipados")
			if first.is_empty():
				first = schedule
	var invalid = first.duplicate(true)
	invalid[1].opponent = invalid[0].opponent
	check(not campaign.validate_schedule(invalid,data,"teste_aurora","direita").is_empty(),"Adversário duplicado rejeitado")
	invalid = first.duplicate(true)
	invalid[0].opponent = data.factions[0].boss
	check(not campaign.validate_schedule(invalid,data,"teste_aurora","direita").is_empty(),"Chefe antecipado rejeitado")
	var insufficient = data.duplicate(true)
	insufficient.characters = insufficient.characters.slice(0,42)
	check(campaign.generate(insufficient,"teste_aurora","direita",2026).is_empty(),"Pool insuficiente rejeitado")
	var wallet = {"propina":0,"upgrades":{}}
	var economy = Economy.new()
	check(not economy.purchase(wallet,data.economy.upgrades[0]) and wallet.propina == 0,"Saldo não negativo")
	wallet.propina = 10000
	for _i in 20:
		economy.purchase(wallet,data.economy.upgrades[0])
	check(wallet.upgrades.health == data.economy.upgrades[0].max_level,"Limite de melhorias")
	var fighter = Fighter.new()
	fighter.setup(data.characters[0])
	fighter.fame = 100
	check(fighter.begin_attack("special_a") and fighter.fame == 65,"Especial consome 35")
	check(not fighter.begin_attack("special_a"),"Recarga impede repetição")
	fighter.fame = 10
	check(not fighter.begin_attack("super") and fighter.fame == 10,"Super sem fama rejeitado")
	fighter.fame = 99
	fighter.confirm_hit(data.characters[0].moves.heavy_punch)
	check(fighter.fame == 100,"Fama limitada a 100")
	fighter.fame = 0
	check(not fighter.begin_attack("special_b") and fighter.fame == 0,"Fama nunca negativa")
	fighter.free()
	test_combat(data)
	test_save(first)
	test_validation(data)
	test_data_edit(data)
	test_combat_rules(data)
	test_campaign_compatibility(data,first)
	print("RUNTIME TESTS: %d passed, %d failed" % [passed,failed])
	quit(1 if failed > 0 else 0)

func test_combat(data: Dictionary) -> void:
	var battle = Match.new()
	root.add_child(battle)
	battle.setup(data.characters[0],data.characters[40],data.arenas[0],"","training")
	battle.set_physics_process(false)
	var left = battle.fighters[0]
	var right = battle.fighters[1]
	left.position.x = 900
	right.position.x = 1040
	left.begin_attack("light_punch")
	for _i in 4:
		battle.advance({}, {})
	check(right.health == 100,"Startup não causa dano")
	battle.advance({}, {})
	check(right.health == 94 and left.fame == 4,"Hitbox ativa causa dano e fama")
	for _i in 8:
		battle.advance({}, {})
	check(right.health == 94,"Um contato por ataque")
	left.state = Fighter.State.IDLE
	right.state = Fighter.State.IDLE
	left.position.x = 900
	right.position.x = 1040
	left.begin_attack("light_punch")
	for _i in 5:
		battle.advance({}, {"block":true})
	check(right.health > 93 and left.fame == 4,"Defesa reduz dano e não dá fama")
	check(right.begin_attack("counter"),"Contra após defesa disponível")
	right.state = Fighter.State.DODGE
	right.dodge_frames = 18
	var previous = right.health
	check(right.receive_hit(left.config.moves.heavy_punch,left.position.x,1.0) == "miss" and right.health == previous,"Esquiva evita golpe")
	right.state = Fighter.State.IDLE
	right.invincible = true
	right.receive_hit({"damage":1000,"knockback":0,"stun":10},left.position.x,1.0)
	check(right.health == 1,"Chefe narrativo permanece vivo")
	right.invincible = false
	right.receive_hit({"damage":1000,"knockback":0,"stun":10},left.position.x,1.0)
	check(right.health == 0,"Modo livre permite KO do chefe")
	battle.queue_free()
	var simultaneous = Match.new()
	root.add_child(simultaneous)
	simultaneous.setup(data.characters[0],data.characters[40],data.arenas[0],"","training")
	simultaneous.set_physics_process(false)
	for i in 2:
		var participant = simultaneous.fighters[i]
		participant.position.x = 900+i*140
		participant.config.moves.light_punch.startup = 1
		participant.config.moves.light_punch.priority = 5 if i == 0 else 1
		participant.begin_attack("light_punch")
	simultaneous.advance({}, {})
	check(simultaneous.fighters[0].health == 100 and simultaneous.fighters[1].health == 94,"Prioridade resolve colisão simultânea")
	simultaneous.queue_free()

func test_save(schedule: Array) -> void:
	var saves = Saves.new()
	saves.base_path = temp
	var progress = saves.new_career("teste_aurora","direita",schedule,2026)
	check(saves.save("Isolado",progress),"Salvamento inicial")
	progress.losses = 1
	check(saves.save("Isolado",progress),"Salvamento após derrota")
	var resumed = saves.load_profile("Isolado")
	check(int(resumed.next_fight) == 0 and resumed.schedule.map(func(f): return f.opponent) == schedule.map(func(f): return f.opponent) and int(resumed.losses) == 1 and Campaign.new().validate_schedule(resumed.schedule,store.data,"teste_aurora","direita").is_empty(),"Retomar derrota mantém confronto")
	var file = FileAccess.open(saves.profile_path("Isolado"),FileAccess.WRITE)
	file.store_string("{ inválido")
	file.close()
	check(not saves.load_profile("Isolado").is_empty() and "Backup" in saves.error,"Recuperação do backup")
	progress.propina = -1
	check(not saves.save("Isolado",progress),"Progresso inválido rejeitado")

func test_validation(data: Dictionary) -> void:
	var broken = data.duplicate(true)
	broken.characters[0].stats.health = -1
	check(not store.validate(broken).is_empty(),"Atributos inválidos rejeitados")
	broken = data.duplicate(true)
	broken.characters[1].id = broken.characters[0].id
	check(not store.validate(broken).is_empty(),"IDs duplicados rejeitados")
	var path = temp.path_join("broken.json")
	DirAccess.make_dir_recursive_absolute(temp)
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{\"schema_version\":")
	file.close()
	var candidate = Store.new()
	check(not candidate.load_file(path) and "linha" in candidate.errors[0],"JSON inválido com mensagem compreensível")
	broken = data.duplicate(true)
	broken.characters[0].sprite = "../secret.png"
	check(not store.validate(broken).is_empty(),"Recurso fora de assets rejeitado")
	for section in ["stats","palette","animation","moves","voices","ai"]:
		broken = data.duplicate(true)
		broken.characters[0][section] = []
		check(not store.validate(broken).is_empty(),"Tipo inválido rejeitado: " + section)
	broken = data.duplicate(true)
	broken.characters[0].moves.light_punch.startup = 2.5
	check(not store.validate(broken).is_empty(),"Frame fracionário rejeitado")
	broken = data.duplicate(true)
	broken.factions[0].id = 99
	broken.factions[1].id = 99
	check(not store.validate(broken).is_empty(),"IDs numéricos de facção rejeitados sem falha")

func test_data_edit(data: Dictionary) -> void:
	var authoring = Store.new()
	authoring.path = temp.path_join("authoring.json")
	authoring.data = data.duplicate(true)
	authoring.data.characters[0].stats.health = 175
	authoring.data.characters[0].moves.light_punch.damage = 19
	check(authoring.save_file(),"Salvar edição por dados")
	var game_data = Store.new()
	check(game_data.load_file(authoring.path),"Jogo recarrega conteúdo editado")
	var fighter = Fighter.new()
	fighter.setup(game_data.character("teste_aurora"))
	check(fighter.health == 175 and fighter.config.moves.light_punch.damage == 19,"Alterações afetam runtime real")
	fighter.free()

func test_combat_rules(data: Dictionary) -> void:
	var fighter = Fighter.new()
	fighter.setup(data.characters[0])
	fighter.position.x = 900
	fighter.begin_attack("light_punch")
	fighter.action_frame = 8
	check(not fighter.can_cancel("heavy_punch"),"Erro de golpe não permite cancelamento que exige confirmação")
	fighter.hit_confirmed = true
	check(fighter.can_cancel("heavy_punch") and not fighter.can_cancel("throw"),"Acerto libera apenas destinos autorizados")
	fighter.action_frame = 17
	check(not fighter.can_cancel("heavy_punch"),"Cancelamento fora da janela rejeitado")
	fighter.action_frame = 8
	fighter.step({"actions":["heavy_punch"]},1100)
	check(fighter.attack_id == "heavy_punch" and fighter.action_frame == 0,"Buffer encadeia golpe autorizado no runtime")
	fighter.position.y = 700
	fighter.fame = 100
	check(not fighter.begin_attack("throw") and not fighter.begin_attack("super"),"Agarrão e super terrestre não disparam no ar")
	check(fighter.begin_attack("light_kick"),"Golpe comum pode ser executado durante o salto")
	fighter.position.y = fighter.ground_y
	fighter.config.moves.light_punch.hitbox = {"offset_x":40,"offset_y":250,"height":30}
	fighter.begin_attack("light_punch")
	fighter.action_frame = 5
	var front = fighter.hitbox()
	check(front.position == Vector2(940,600) and front.size == Vector2(120,30),"Configuração visual de hitbox aplicada ao Fighter")
	fighter.facing = -1
	check(fighter.hitbox().end.x == fighter.position.x-40,"Hitbox espelhada acompanha a direção do ataque")
	fighter.config.collision = {"width":100,"height":240,"crouch_height":120,"push_width":100}
	check(fighter.hurtbox().size == Vector2(100,240),"Hurtbox configurável aplicada")
	fighter.state = Fighter.State.CROUCH
	check(fighter.hurtbox().size.y == 120,"Agachamento usa hurtbox configurada")
	fighter.begin_attack("light_punch")
	var old_serial = fighter.attack_serial
	fighter.begin_attack("heavy_punch")
	fighter.confirm_hit(fighter.config.moves.light_punch,old_serial)
	check(fighter.fame == 100 and not fighter.hit_confirmed,"Projétil antigo dá fama sem confirmar o golpe atual")
	fighter.free()
	var image = Image.create(80,20,false,Image.FORMAT_RGBA8)
	var texture = ImageTexture.create_from_image(image)
	var animation = {"columns":4,"rows":1,"fps":8}
	var move: Dictionary = data.characters[0].moves.light_punch.duplicate(true)
	move.animation = {"start":1,"count":3}
	check(Characters.attack_frame_rect(texture,animation,move,0).position.x == 20 and Characters.attack_frame_rect(texture,animation,move,19).position.x == 60,"Animação de golpe percorre o trecho a partir do frame do ataque")
	var battle = Match.new()
	root.add_child(battle)
	battle.setup(data.characters[0],data.characters[40],data.arenas[0],"","training")
	battle.set_physics_process(false)
	battle.fighters[0].position.x = 120
	battle.fighters[1].position.x = 140
	battle.resolve_pushboxes()
	check(battle.fighters[0].position.x == 120 and battle.fighters[1].position.x == 205,"Colisão na parede mantém separação corporal")
	battle.fighters[0].position.x = 900
	battle.fighters[1].position.x = 1040
	battle.fighters[0].config.moves.light_punch.hitbox.offset_y = 450
	battle.fighters[0].begin_attack("light_punch")
	for _frame in 5:
		battle.advance({}, {})
	check(battle.fighters[1].health == 100,"Hitbox fora do corpo não causa dano invisível")
	battle.fighters[0].config.moves.light_punch.hitbox.offset_y = 175
	battle.fighters[0].begin_attack("light_punch")
	for _frame in 5:
		battle.advance({}, {})
	check(battle.fighters[1].health == 94,"Mudança de hitbox altera a colisão real")
	battle.queue_free()
	var ranged = Match.new()
	root.add_child(ranged)
	ranged.setup(data.characters[0],data.characters[40],data.arenas[0],"","training")
	ranged.set_physics_process(false)
	ranged.fighters[0].position.x = 900
	ranged.fighters[1].position.x = 1700
	ranged.fighters[0].fame = 100
	ranged.fighters[0].config.moves.special_a.hitbox = {"offset_x":25,"offset_y":100,"height":20}
	ranged.fighters[0].config.moves.special_a.projectile_width = 60
	ranged.fighters[0].begin_attack("special_a")
	for _frame in 14:
		ranged.advance({}, {})
	check(ranged.projectiles.size() == 1 and ranged.projectiles[0].size == Vector2(60,20) and ranged.projectiles[0].position.y == 760,"Projétil usa a geometria configurada e é gerado no frame ativo")
	ranged.fighters[0].begin_attack("finisher")
	for _frame in 100:
		ranged.advance({}, {})
	check(ranged.fighters[1].health == 78 and not ranged.fighters[0].hit_confirmed,"Projétil mantém sua identidade após o atacante iniciar outro golpe")
	ranged.queue_free()
	for broken_field in ["hitbox","cancel","animation"]:
		var broken: Dictionary = data.duplicate(true)
		broken.characters[0].moves.light_punch[broken_field] = []
		check(not store.validate(broken).is_empty(),"Extensão malformada rejeitada: " + broken_field)
	var broken: Dictionary = data.duplicate(true)
	broken.characters[0].collision.height = "inválido"
	check(not store.validate(broken).is_empty(),"Dimensão de colisão textual rejeitada sem falha")
	broken = data.duplicate(true)
	broken.characters[0].moves.light_punch.cancel.end = 0.5
	check(not store.validate(broken).is_empty(),"Janela de cancelamento fracionária rejeitada")
	broken = data.duplicate(true)
	broken.characters[0].moves.light_punch.animation = {"start":1,"count":2}
	check(not store.validate(broken).is_empty(),"Animação fora do spritesheet rejeitada")
	broken = data.duplicate(true)
	broken.characters[0].animation.columns = []
	broken.characters[0].moves.light_punch.animation = {"start":0,"count":1}
	check(not store.validate(broken).is_empty(),"Dimensão de spritesheet malformada rejeitada sem converter coleção em número")
	broken = data.duplicate(true)
	broken.characters[0].voices.entry = [{"file":"","weight":1,"volume":1,"interval":0,"source":123,"license":"original","authorization":"própria"}]
	check(not store.validate(broken).is_empty(),"Registro de origem de voz precisa ser textual")
	broken = data.duplicate(true)
	broken.characters[0].moves.light_punch.cancel.into = ["golpe_inexistente"]
	check(not store.validate(broken).is_empty(),"Destino de cancelamento inexistente rejeitado")
	broken = data.duplicate(true)
	broken.campaign.narrative_invincible_route = "direita"
	check(not store.validate(broken).is_empty(),"Paradoxo não pode se estender a outra facção")

func test_campaign_compatibility(data: Dictionary, first: Array) -> void:
	var generator = Campaign.new()
	var legacy: Array = first.duplicate(true)
	legacy[0].opponent = "teste_guardiao"
	check(not generator.validate_schedule(legacy,data,"teste_aurora","direita").is_empty(),"Nova carreira reserva também o chefe de outra rota")
	check(generator.validate_schedule(legacy,data,"teste_aurora","direita",true).is_empty(),"Carreira antiga pode conservar o outro chefe como adversário comum")
	var saves = Saves.new()
	saves.base_path = temp
	var progress = saves.new_career("teste_aurora","direita",legacy,2026)
	progress.erase("schedule_rules")
	check(saves.save("Legacy",progress) and saves.load_profile("Legacy").schedule[0].opponent == "teste_guardiao","Salvar e carregar não substitui a sequência legada")
	progress.schedule_rules = "2"
	check(not saves.save("Malformed",progress),"Versão textual de regras rejeitada sem impedir a recarga de números JSON")
	var out_of_order: Array = first.duplicate(true)
	out_of_order[0].rank = 1
	out_of_order[7].rank = 0
	check(not generator.validate_schedule(out_of_order,data,"teste_aurora","direita").is_empty(),"Troca de cargos rejeitada mesmo com totais corretos")
	check(first[-1].arena == "trono_urna_x" and data.factions[3].boss == "teste_regente" and data.factions[1].boss == "teste_guardiao","Chefe e arena finais seguem as quatro regras narrativas")
