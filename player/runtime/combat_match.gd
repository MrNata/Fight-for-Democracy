extends Node2D
signal finished(result: Dictionary)
signal impact(blocked: bool)
const Fighter = preload("res://runtime/fighter.gd")
const InputSystem = preload("res://runtime/input_system.gd")
const AISystem = preload("res://runtime/ai_system.gd")
const Arena = preload("res://runtime/arena_system.gd")
const MAX_PROJECTILES = 64
const MAX_SPARKS = 32
var fighters: Array = []
var input_system = InputSystem.new()
var ai = AISystem.new()
var ai_left = AISystem.new()
var mode = "ai"
var tick = 0
var remaining_frames = 99 * 60
var intro_frames = 100
var ended = false
var projectiles: Array = []
var sparks: Array = []
var narrative_boss = false
var paused = false

func setup(left: Dictionary, right: Dictionary, arena: Dictionary, content_root: String, match_mode: String = "ai", difficulty: int = 0, seed_value: int = 2026) -> void:
	mode = match_mode
	ai.setup(difficulty, seed_value)
	ai_left.setup(difficulty, seed_value + 1)
	var background = Arena.new()
	background.setup(arena, content_root)
	add_child(background)
	for index in 2:
		var fighter = Fighter.new()
		fighter.setup(left if index == 0 else right, content_root)
		fighter.position = Vector2(590 if index == 0 else 1330, 850)
		fighter.facing = 1 if index == 0 else -1
		fighter.invincible = narrative_boss and index == 1
		fighter.show_boxes = mode == "training"
		add_child(fighter)
		fighters.append(fighter)

func _physics_process(_delta: float) -> void:
	if paused or ended or fighters.size() != 2:
		return
	if intro_frames > 0:
		intro_frames -= 1
		return
	advance(input_system.poll(0) if mode != "simulation" else ai_left.decide(fighters[0],fighters[1],tick), input_system.poll(1) if mode == "local" else {} if mode == "training" else ai.decide(fighters[1],fighters[0],tick))

func advance(left_input: Dictionary, right_input: Dictionary) -> void:
	if ended:
		return
	tick += 1
	if mode != "training":
		remaining_frames -= 1
	fighters[0].step(left_input, fighters[1].position.x)
	fighters[1].step(right_input, fighters[0].position.x)
	resolve_pushboxes()
	var contacts: Array = []
	for index in 2:
		var fighter = fighters[index]
		if fighter.is_active() and fighter.attack.get("projectile", false) and not fighter.projectile_spawned:
			fighter.projectile_spawned = true
			var box: Dictionary = fighter.attack.get("hitbox",{})
			var size = Vector2(float(fighter.attack.get("projectile_width",48)),float(box.get("height",48)))
			if projectiles.size() < MAX_PROJECTILES:
				projectiles.append({"position": fighter.position+Vector2(fighter.facing*(float(box.get("offset_x",25))+35),-float(box.get("offset_y",169))+size.y*0.5), "size":size, "velocity": fighter.facing*float(fighter.attack.get("projectile_speed",680)), "owner": index, "move": fighter.attack.duplicate(), "action":fighter.attack_id, "serial":fighter.attack_serial, "life": 180})
		if fighter.is_active() and not fighter.contacted and fighter.hitbox().has_area() and fighter.hitbox().intersects(fighters[1-index].hurtbox()):
			contacts.append({"owner": index, "move": fighter.attack.duplicate()})
	if contacts.size() == 2:
		var first_priority = int(contacts[0].move.priority)
		var second_priority = int(contacts[1].move.priority)
		if first_priority != second_priority:
			contacts = [contacts[0] if first_priority > second_priority else contacts[1]]
	for contact in contacts:
		fighters[contact.owner].contacted = true
		apply_hit(contact.owner, contact.move,fighters[contact.owner].attack_id,fighters[contact.owner].attack_serial)
	for index in range(projectiles.size()-1,-1,-1):
		var projectile: Dictionary = projectiles[index]
		projectile.position.x += float(projectile.velocity)/60.0
		projectile.life -= 1
		var box = Rect2(projectile.position-projectile.size*0.5,projectile.size)
		if box.intersects(fighters[1-int(projectile.owner)].hurtbox()):
			apply_hit(projectile.owner,projectile.move,projectile.action,projectile.serial)
			projectiles.remove_at(index)
		elif projectile.life <= 0 or projectile.position.x < 0 or projectile.position.x > 1920:
			projectiles.remove_at(index)
	for index in range(sparks.size()-1,-1,-1):
		sparks[index].life -= 1
		if sparks[index].life <= 0:
			sparks.remove_at(index)
	if mode == "training":
		for fighter in fighters:
			if fighter.health <= 0:
				fighter.health = float(fighter.config.stats.health)
				fighter.state = Fighter.State.IDLE
	else:
		if fighters[0].health <= 0 or fighters[1].health <= 0 or remaining_frames <= 0 or (narrative_boss and tick >= 60*30):
			complete()
	queue_redraw()

func resolve_pushboxes() -> void:
	var distance = fighters[1].position.x-fighters[0].position.x
	var separation = (fighters[0].push_width()+fighters[1].push_width())*0.5
	if absf(distance) < separation and absf(fighters[0].position.y-fighters[1].position.y) < 130:
		var push = (separation-absf(distance))*0.5
		var direction = 1.0 if distance >= 0 else -1.0
		fighters[0].position.x = clampf(fighters[0].position.x-push*direction,120,1800)
		fighters[1].position.x = clampf(fighters[1].position.x+push*direction,120,1800)
		# Transfer the remaining separation to the free side when one fighter hits a wall.
		var missing = separation-absf(fighters[1].position.x-fighters[0].position.x)
		if missing > 0:
			if fighters[0].position.x == 120 or fighters[0].position.x == 1800:
				fighters[1].position.x = clampf(fighters[1].position.x+missing*direction,120,1800)
			else:
				fighters[0].position.x = clampf(fighters[0].position.x-missing*direction,120,1800)

func apply_hit(owner: int, move: Dictionary, action: String = "", serial: int = -1) -> void:
	var attacker = fighters[owner]
	var target = fighters[1-owner]
	if (action if not action.is_empty() else attacker.attack_id) == "finisher" and target.health > float(target.config.stats.health)*0.2:
		return
	var response = target.receive_hit(move,attacker.position.x,float(attacker.config.stats.strength))
	if response == "miss":
		return
	if response == "hit":
		attacker.confirm_hit(move,serial)
	impact.emit(response == "block")
	sparks.append({"position": target.position+Vector2(0,-145), "life": 12, "blocked": response == "block"})
	if sparks.size() > MAX_SPARKS:
		sparks.pop_front()

func complete() -> void:
	ended = true
	var winner = -1
	if not narrative_boss:
		if fighters[0].health > fighters[1].health:
			winner = 0
		elif fighters[1].health > fighters[0].health:
			winner = 1
	finished.emit({"winner": winner, "narrative": narrative_boss, "health": fighters[0].health, "max_combo": fighters[0].max_combo, "seconds": tick/60.0, "timeout": remaining_frames <= 0})

func _draw() -> void:
	for projectile in projectiles:
		draw_set_transform(projectile.position,0,projectile.size/Vector2(48,48))
		draw_circle(Vector2.ZERO,24,Color(0.4,1,0.75,0.3))
		draw_circle(Vector2.ZERO,16,Color("#c7ffe6"))
		draw_set_transform(Vector2.ZERO)
		if fighters[0].show_boxes:
			draw_rect(Rect2(projectile.position-projectile.size*0.5,projectile.size),Color(1,0.2,0.2,0.7),false,2)
	for spark in sparks:
		var color = Color("#86cbff") if spark.blocked else Color("#ffe39e")
		for i in 8:
			var direction = Vector2.from_angle(i*TAU/8)
			draw_line(spark.position+direction*12,spark.position+direction*(45-spark.life),color,3)
