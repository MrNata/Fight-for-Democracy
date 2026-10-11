extends Control
signal frame_selected(frame: int)
var move: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(360,110)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	if move.is_empty():
		return
	var total = int(move.startup+move.active+move.recovery)
	var unit = size.x/maxi(total,1)
	var start = 0.0
	var colors = [Color("#ecc96c"),Color("#ef6c82"),Color("#73b9eb")]
	var fields = ["startup","active","recovery"]
	for i in 3:
		var width = float(move[fields[i]]) * unit
		draw_rect(Rect2(start,20,width,50),colors[i].darkened(0.15))
		start += width
	for i in total:
		if unit > 4 or i % 5 == 0:
			draw_line(Vector2(i*unit,20),Vector2(i*unit,70),Color(0,0,0,0.3),1)
	var font = ThemeDB.fallback_font
	draw_string(font,Vector2(0,98),"INÍCIO %d  /  ATIVO %d  /  RECUPERAÇÃO %d  •  TOTAL %df" % [int(move.startup),int(move.active),int(move.recovery),total],HORIZONTAL_ALIGNMENT_LEFT,size.x,14,Color("#bac8db"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not move.is_empty():
		var total = int(move.startup+move.active+move.recovery)
		frame_selected.emit(clampi(int(event.position.x/size.x*total),0,total-1))
