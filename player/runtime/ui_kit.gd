extends RefCounted
const INK = Color("#e9edf3")
const MUTED = Color("#9aaac0")
const GREEN = Color("#65d6a0")

static func style(background: Color, radius: int = 8, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.border_color = border
	box.set_border_width_all(1)
	return box

static func theme(size: int = 22, accent: Color = GREEN) -> Theme:
	var value = Theme.new()
	value.default_font_size = size
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	value.default_font = font
	value.set_color("font_color", "Label", INK)
	value.set_color("font_color", "Button", INK)
	value.set_color("font_hover_color", "Button", Color.WHITE)
	value.set_stylebox("normal", "Button", style(Color("#1a293d"),8,Color("#2a3d55")))
	value.set_stylebox("hover", "Button", style(accent.darkened(0.65),8,accent))
	value.set_stylebox("pressed", "Button", style(Color("#245c47")))
	value.set_stylebox("focus", "Button", style(Color.TRANSPARENT,8,accent))
	value.set_stylebox("disabled", "Button", style(Color("#141e2d")))
	value.set_stylebox("normal", "LineEdit", style(Color("#0d1726"),6,Color("#2a3d55")))
	value.set_color("font_color", "LineEdit", INK)
	value.set_stylebox("panel", "PanelContainer", style(Color("#121f31"),10,Color("#24354a")))
	value.set_stylebox("panel", "PopupMenu", style(Color("#1a293d")))
	value.set_color("font_color", "PopupMenu", INK)
	value.set_stylebox("panel", "ItemList", style(Color("#0d1726")))
	value.set_color("font_color", "ItemList", INK)
	value.set_stylebox("selected", "ItemList", style(Color("#24513e")))
	value.set_stylebox("background", "ProgressBar", style(Color("#253147"),5))
	value.set_stylebox("fill", "ProgressBar", style(GREEN,5))
	return value

static func label(text: String, size: int = 22, color: Color = INK) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	return node

static func button(text: String, callback: Callable) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.pressed.connect(callback)
	return node

static func margins(child: Control, amount: int = 28) -> MarginContainer:
	var margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_"+side,amount)
	margin.add_child(child)
	return margin

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
