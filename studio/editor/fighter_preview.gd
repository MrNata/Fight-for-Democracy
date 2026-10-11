extends Control
const Fighter = preload("res://runtime/fighter.gd")
const Arena = preload("res://runtime/arena_system.gd")
var fighter: Node2D
var world: Node2D
var boxes = false
var paused = false

func setup(character: Dictionary, arena: Dictionary, root: String) -> void:
	if world != null:
		remove_child(world)
		world.queue_free()
	world = Node2D.new()
	add_child(world)
	var background = Arena.new()
	background.setup(arena,root)
	world.add_child(background)
	fighter = Fighter.new()
	fighter.setup(character,root)
	fighter.position = Vector2(960,850)
	fighter.scale = Vector2(2.6,2.6)
	fighter.show_boxes = boxes
	fighter.fame = 100.0
	world.add_child(fighter)
	custom_minimum_size = Vector2(380,280)
	clip_contents = true
	resize_world()
	if not resized.is_connected(resize_world):
		resized.connect(resize_world)

func resize_world() -> void:
	if world != null:
		world.scale = Vector2(size.x/1920.0,size.y/1080.0)

func test_move(action: String) -> void:
	if fighter != null:
		paused = false
		fighter.fame = 100.0
		fighter.state = Fighter.State.IDLE
		fighter.cooldowns.clear()
		fighter.recent_block = fighter.frame
		fighter.queue_action(action)

func _physics_process(_delta: float) -> void:
	if fighter != null and not paused:
		fighter.step({},1500)
