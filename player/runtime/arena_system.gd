extends Node2D
var config: Dictionary = {}
var texture: Texture2D
var tick = 0
var crowd_textures: Array = []

func setup(arena: Dictionary, root: String = "") -> void:
	config = arena
	texture = null
	crowd_textures.clear()
	for layer in arena.get("crowd",[]):
		var asset = root.path_join(layer.file)
		var layer_texture: Texture2D
		if asset.begins_with("res://") and ResourceLoader.exists(asset):
			layer_texture = load(asset) as Texture2D
		else:
			var image = Image.load_from_file(asset)
			if image != null:
				layer_texture = ImageTexture.create_from_image(image)
		if layer_texture != null:
			crowd_textures.append({"texture":layer_texture,"layer":layer})
	if not str(arena.get("background", "")).is_empty():
		var asset = root.path_join(arena.background)
		if asset.begins_with("res://") and ResourceLoader.exists(asset):
			texture = load(asset) as Texture2D
		else:
			var img = Image.load_from_file(asset)
			if img != null:
				texture = ImageTexture.create_from_image(img)
	queue_redraw()

func _draw() -> void:
	var sky = Color(config.get("sky", "#121d33"))
	var floor_color = Color(config.get("floor", "#293a4e"))
	var accent = Color(config.get("accent", "#65d6a0"))
	draw_rect(Rect2(0,0,1920,1080),sky)
	if texture:
		draw_texture_rect(texture,Rect2(0,0,1920,850),false)
	else:
		for i in 16:
			var height = 150 + (i * 67) % 260
			draw_rect(Rect2(i*130,700-height,90,height),sky.lightened(0.06))
		draw_circle(Vector2(1460,260),120,sky.lightened(0.13))
		draw_rect(Rect2(560,490,800,250),sky.lightened(0.1))
		for i in 9:
			draw_rect(Rect2(595+i*85,525,28,188),sky.lightened(0.22))
		draw_colored_polygon(PackedVector2Array([Vector2(520,490),Vector2(960,335),Vector2(1400,490)]),sky.lightened(0.18))
		for i in 34:
			var color = accent.darkened(0.5+(i%3)*0.07)
			draw_circle(Vector2(25+i*57,760),16,color)
			draw_rect(Rect2(10+i*57,777,30,48),color)
		draw_line(Vector2(0,825),Vector2(1920,825),accent.darkened(0.25),6)
	draw_rect(Rect2(0,850,1920,230),floor_color)
	for i in 13:
		draw_line(Vector2(960+(i-6)*140,850),Vector2(960+(i-6)*260,1080),floor_color.lightened(0.1),2)
	for y in [890,950,1035]:
		draw_line(Vector2(0,y),Vector2(1920,y),floor_color.lightened(0.1),2)
	draw_line(Vector2(0,850),Vector2(1920,850),accent,3)
	if not texture and config.get("id") == "trono_urna_x":
		draw_throne(sky,accent)
	for item in crowd_textures:
		var layer: Dictionary = item.layer
		draw_texture_rect(item.texture,Rect2(float(layer.x)-float(layer.width)/2,float(layer.y)-float(layer.height),float(layer.width),float(layer.height)),false)

func _physics_process(_delta: float) -> void:
	if config.get("id") == "trono_urna_x" and texture == null:
		tick += 1
		queue_redraw()

func draw_throne(sky: Color, accent: Color) -> void:
	# Distinct procedural scenery, explicitly temporary; final illustrations/music are pending.
	draw_rect(Rect2(0,160,1920,650),sky)
	for i in 12:
		var x = i*170.0-30
		var height = 165+(i*31)%130
		var facade = Color("#835575") if i%2 else Color("#b67d63")
		draw_rect(Rect2(x,690-height,155,height),facade.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(x-5,690-height),Vector2(x+78,640-height),Vector2(x+160,690-height)]),accent.darkened(0.4))
		for window in 3:
			draw_rect(Rect2(x+18+window*43,720-height,20,48),sky)
	for side in [-1,1]:
		var source = Vector2(960+side*730,210)
		var sweep = sin(tick*0.009)*120
		draw_colored_polygon(PackedVector2Array([source,Vector2(960+side*180+sweep,750),Vector2(960+side*470+sweep,750)]),Color(accent,0.07))
		draw_rect(Rect2(960+side*570-110,360,220,140),sky.lightened(0.17))
		draw_rect(Rect2(960+side*570-100,370,200,120),accent.darkened(0.65))
		draw_string(ThemeDB.fallback_font,Vector2(960+side*570-63,440),"URNA-X",HORIZONTAL_ALIGNMENT_LEFT,-1,30,accent)
		draw_line(Vector2(960+side*370,305),Vector2(960+side*370,650),accent,6)
		draw_colored_polygon(PackedVector2Array([Vector2(960+side*370,305),Vector2(960+side*270,335),Vector2(960+side*370,390)]),Color("#9c5e82"))
	draw_rect(Rect2(690,610,540,105),accent.darkened(0.7))
	draw_rect(Rect2(795,330,330,270),accent.darkened(0.3))
	draw_rect(Rect2(820,355,280,230),Color("#73334e"))
	draw_rect(Rect2(790,565,340,55),accent)
	draw_rect(Rect2(760,505,55,160),accent.darkened(0.15))
	draw_rect(Rect2(1105,505,55,160),accent.darkened(0.15))
	for i in 34:
		var color = accent.darkened(0.6+(i%3)*0.04)
		var bob = sin(tick*0.06+i)*4
		draw_circle(Vector2(25+i*57,760+bob),16,color)
		draw_rect(Rect2(10+i*57,777+bob,30,48),color)
	draw_line(Vector2(0,825),Vector2(1920,825),accent.darkened(0.25),6)
