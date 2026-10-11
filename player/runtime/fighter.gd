extends Node2D
## Frame-based state machine. World collision is resolved by CombatMatch.
signal voice_event(event: String)
const Fame = preload("res://runtime/fame_system.gd")
const Characters = preload("res://runtime/character_system.gd")
enum State { IDLE, WALK, CROUCH, AIR, ATTACK, BLOCK, DODGE, HIT, KO }
var config: Dictionary
var state = State.IDLE
var health = 100.0
var fame = 0.0
var facing = 1
var velocity = Vector2.ZERO
var ground_y = 850.0
var frame = 0
var action_frame = 0
var attack_id = ""
var attack_serial = 0
var attack: Dictionary = {}
var contacted = false
var projectile_spawned = false
var hit_confirmed = false
var stun_frames = 0
var dodge_frames = 0
var recent_block = -100
var combo = 0
var max_combo = 0
var last_hit_frame = -100
var cooldowns: Dictionary = {}
var buffer: Array = []
var flash = 0
var invincible = false
var show_boxes = false
var texture: Texture2D
var defending = false

func setup(character: Dictionary, content_root: String = "") -> void:
	config = character.duplicate(true)
	health = float(config.stats.health)
	position.y = ground_y
	texture = Characters.load_sprite(config,content_root)
	queue_redraw()

func queue_action(action: String) -> void:
	if buffer.size() < 5:
		buffer.append({"action": action, "expires": frame + 8})

func step(command: Dictionary, opponent_x: float) -> void:
	frame += 1
	flash = maxi(0, flash - 1)
	for key in cooldowns.keys():
		cooldowns[key] = maxi(0, int(cooldowns[key]) - 1)
	buffer = buffer.filter(func(item): return item.expires >= frame)
	if frame - last_hit_frame > 45:
		combo = 0
	for action in command.get("actions", []):
		queue_action(action)
	defending = bool(command.get("block", false))
	if state == State.KO:
		queue_redraw()
		return
	if state != State.ATTACK and state != State.HIT:
		facing = 1 if opponent_x >= position.x else -1
	if state == State.HIT:
		stun_frames -= 1
		if stun_frames <= 0:
			state = State.IDLE
	elif state == State.DODGE:
		dodge_frames -= 1
		if dodge_frames <= 0:
			state = State.IDLE
	elif state == State.ATTACK:
		action_frame += 1
		if action_frame >= int(attack.startup + attack.active + attack.recovery):
			state = State.IDLE
		elif not buffer.is_empty():
			var next_action: String = buffer[0].action
			if can_cancel(next_action):
				if begin_attack(next_action):
					buffer.pop_front()
	if state not in [State.HIT, State.DODGE, State.ATTACK]:
		var direction = float(command.get("axis", 0.0))
		if command.get("dodge", false) and position.y >= ground_y:
			state = State.DODGE
			dodge_frames = 20
			velocity.x = -facing * 560.0
		elif defending and position.y >= ground_y:
			state = State.BLOCK
			velocity.x = 0.0
		elif command.get("crouch", false) and position.y >= ground_y:
			state = State.CROUCH
			velocity.x = 0.0
		else:
			velocity.x = direction * float(config.stats.speed)
			state = State.WALK if absf(direction) > 0.1 else State.IDLE
		if command.get("jump", false) and position.y >= ground_y and state != State.DODGE:
			velocity.y = -760.0 * float(config.stats.mobility)
			state = State.AIR
		if not buffer.is_empty() and state != State.DODGE:
			if begin_attack(buffer[0].action):
				buffer.pop_front()
	if state == State.ATTACK:
		velocity.x = move_toward(velocity.x, 0.0, 45.0)
	elif state == State.HIT:
		velocity.x = move_toward(velocity.x, 0.0, 10.0)
	velocity.y += 1800.0 / 60.0
	position += velocity / 60.0
	position.x = clampf(position.x, 120, 1800)
	if position.y >= ground_y:
		position.y = ground_y
		velocity.y = 0.0
	elif state in [State.IDLE, State.WALK]:
		state = State.AIR
	queue_redraw()

func begin_attack(id: String) -> bool:
	if not config.moves.has(id) or cooldowns.get(id, 0) > 0:
		return false
	if id == "counter" and frame - recent_block > 14:
		return false
	var move: Dictionary = config.moves[id]
	if position.y < ground_y and not move.get("air_allowed", id in ["light_punch","heavy_punch","light_kick","heavy_kick"]):
		return false
	if not Fame.can_spend(fame,float(move.fame_cost)):
		return false
	fame = Fame.spend(fame,float(move.fame_cost))
	attack_id = id
	attack_serial += 1
	attack = move
	action_frame = 0
	contacted = false
	projectile_spawned = false
	hit_confirmed = false
	cooldowns[id] = int(move.cooldown)
	state = State.ATTACK
	voice_event.emit("super" if id == "super" else "special" if id.begins_with("special") else "attack")
	return true

func is_active() -> bool:
	return state == State.ATTACK and action_frame >= int(attack.startup) and action_frame < int(attack.startup + attack.active)

func can_cancel(next_action: String) -> bool:
	var rules: Dictionary = attack.get("cancel", {})
	var recovery_frame = action_frame - int(attack.get("startup", 0) + attack.get("active", 0))
	return state == State.ATTACK and next_action != attack_id and next_action in rules.get("into", []) and recovery_frame >= int(rules.get("start",0)) and recovery_frame <= int(rules.get("end",0)) and (hit_confirmed or not rules.get("require_hit",true))

func push_width() -> float:
	return float(config.get("collision", {}).get("push_width",85))

func hurtbox() -> Rect2:
	var box: Dictionary = config.get("collision", {})
	var height = float(box.get("crouch_height",112)) if state == State.CROUCH else float(box.get("height",204))
	var width = float(box.get("width",84))
	return Rect2(position + Vector2(-width*0.5, -height), Vector2(width, height))

func hitbox() -> Rect2:
	if not is_active() or contacted or attack.get("projectile", false):
		return Rect2()
	var reach = float(attack.reach)
	var box: Dictionary = attack.get("hitbox", {})
	var y = -float(box.get("offset_y",110 if "kick" in attack_id else 175))
	var offset = float(box.get("offset_x",25))
	var x = offset if facing == 1 else -reach - offset
	return Rect2(position + Vector2(x, y), Vector2(reach, float(box.get("height",65))))

func receive_hit(move: Dictionary, attacker_x: float, power: float) -> String:
	if state == State.KO or (state == State.DODGE and dodge_frames > 5):
		return "miss"
	var blocked = state == State.BLOCK and not move.get("unblockable", false)
	if blocked:
		recent_block = frame
		health = maxf(1.0, health - float(move.damage) * 0.08)
		velocity.x = signf(position.x - attacker_x) * float(move.knockback) * 0.2
		flash = 3
		return "block"
	var damage = float(move.damage) * power * (1.0 - float(config.stats.defense))
	health = maxf(1.0 if invincible else 0.0, health - damage)
	velocity.x = signf(position.x - attacker_x) * float(move.knockback)
	stun_frames = int(move.stun)
	state = State.HIT if health > 0 else State.KO
	flash = 6
	combo = 0
	voice_event.emit("hurt" if health > 0 else "defeat")
	return "hit"

func confirm_hit(move: Dictionary, serial: int = -1) -> void:
	fame = Fame.gain(fame,float(move.fame_gain))
	combo = combo + 1 if frame - last_hit_frame <= 45 else 1
	max_combo = maxi(max_combo, combo)
	last_hit_frame = frame
	if serial == -1 or serial == attack_serial:
		hit_confirmed = true

func state_label() -> String:
	return ["NEUTRO", "MOVIMENTO", "AGACHADO", "SALTO", "ATAQUE", "DEFESA", "ESQUIVA", "STUN", "KO"][state]

func _draw() -> void:
	if config.is_empty():
		return
	var clothes = Color(config.palette.clothes)
	var skin = Color(config.palette.skin)
	var accent = Color(config.palette.accent)
	if flash > 0:
		clothes = Color.WHITE
	var bob = sin(frame * 0.1) * 3.0
	var crouch = 62.0 if state == State.CROUCH else 0.0
	var stride = sin(frame * 0.4) * 16.0 if state == State.WALK else 0.0
	if texture != null:
		var region = Characters.attack_frame_rect(texture,config.animation,attack,action_frame) if state == State.ATTACK else Characters.frame_rect(texture,config.animation,frame)
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
		draw_texture_rect_region(texture, Rect2(-100, -240+crouch, 200, 240-crouch), region, clothes)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
		draw_circle(Vector2(0, -8), 52, Color(0,0,0,0.25))
		var lean = -30.0 if state == State.KO else 0.0
		var hip = Vector2(lean, -78 + crouch * 0.5)
		draw_line(hip+Vector2(-18,0), Vector2(-25-stride, -12), Color("#203348"), 23)
		draw_line(hip+Vector2(18,0), Vector2(25+stride, -12), Color("#203348"), 23)
		draw_line(Vector2(-25-stride,-8), Vector2(-48-stride,-8), accent, 13)
		draw_line(Vector2(25+stride,-8), Vector2(47+stride,-8), accent, 13)
		draw_style_box(body_style(clothes), Rect2(-38+lean, -172+crouch+bob, 76, 98-crouch*0.4))
		draw_line(Vector2(lean, -164+crouch+bob), Vector2(lean,-84+crouch*0.5), accent, 7)
		var head = Vector2(lean, -199+crouch+bob)
		draw_circle(head, 36, skin)
		var appearance = int(config.get("appearance", 0))
		draw_arc(head, 33, PI, TAU, 16, Color("#262331"), 12 if appearance != 2 else 3)
		if appearance == 1:
			draw_line(head+Vector2(-20,-3), head+Vector2(25,-3), Color("#182130"), 10)
		else:
			draw_circle(head+Vector2(13,-3), 4, Color("#182130"))
			draw_line(head+Vector2(6,-15),head+Vector2(23,-12),Color("#182130"),3)
		if appearance == 3:
			draw_arc(head+Vector2(0,5), 24, 0.2, 2.8, 16, Color("#443331"), 10)
		var portrait = str(config.get("portrait_style",""))
		if portrait in ["white_beard","glasses_beard"]:
			draw_arc(head+Vector2(0,5),26,0.1,3.0,16,Color("#e9e3da") if portrait == "white_beard" else Color("#33282b"),14)
		if portrait == "glasses_beard":
			draw_rect(Rect2(head+Vector2(-25,-10),Vector2(22,16)),Color("#182130"),false,3)
			draw_rect(Rect2(head+Vector2(1,-10),Vector2(22,16)),Color("#182130"),false,3)
			draw_line(head+Vector2(-3,-4),head+Vector2(1,-4),Color("#182130"),3)
		draw_line(head+Vector2(12,16),head+Vector2(25,13),Color("#633a35"),3)
		var extension = attack_extension()
		var box: Dictionary = attack.get("hitbox", {})
		var strike_y = -float(box.get("offset_y",175)) + float(box.get("height",65))*0.5
		var hand = Vector2(55+extension, lerpf(-147+crouch,strike_y,attack_pose_weight()))
		if state == State.BLOCK:
			hand = Vector2(39,-196)
		draw_line(Vector2(28+lean,-153+crouch),hand,clothes,22)
		draw_circle(hand,16,skin)
		draw_line(Vector2(-29+lean,-149+crouch),Vector2(-48,-105+crouch),clothes,22)
		draw_circle(Vector2(-48,-105+crouch),14,skin)
		if state == State.ATTACK and "kick" in attack_id:
			var foot = Vector2(55+extension,lerpf(-12,strike_y,attack_pose_weight()))
			draw_line(hip,foot,Color("#203348"),26)
			draw_circle(foot,15,accent)
		draw_set_transform(Vector2.ZERO)
	if show_boxes:
		draw_rect(Rect2(hurtbox().position-position,hurtbox().size),Color(0.1,0.7,1,0.25),true)
		draw_rect(Rect2(hurtbox().position-position,hurtbox().size),Color(0.1,0.7,1,0.9),false,2)
		if is_active():
			draw_rect(Rect2(hitbox().position-position,hitbox().size),Color(1,0.2,0.2,0.4),true)

func body_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	return style

func attack_pose_weight() -> float:
	if state != State.ATTACK:
		return 0.0
	if action_frame < int(attack.startup):
		return float(action_frame)/float(attack.startup)*0.25
	if action_frame < int(attack.startup + attack.active):
		return 1.0
	return maxf(0,1.0-float(action_frame-int(attack.startup+attack.active))/float(attack.recovery))

func attack_extension() -> float:
	if state != State.ATTACK:
		return 0.0
	var tip = float(attack.get("hitbox",{}).get("offset_x",25)) + float(attack.reach) - 14.0
	if action_frame < int(attack.startup):
		return -22.0*float(action_frame)/float(attack.startup)
	return (tip-55.0)*attack_pose_weight()
