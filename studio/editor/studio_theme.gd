extends RefCounted
const UI = preload("res://runtime/ui_kit.gd")
const ACCENT = Color("#8ab7ff")
const BACKGROUND = Color("#0d1119")
static var icons: Dictionary = {}

static func create() -> Theme:
	var result = UI.theme(16,ACCENT)
	for type in ["Button","OptionButton"]:
		result.set_stylebox("normal",type,box("#19212e","#2b3546"))
		result.set_stylebox("hover",type,box("#24334a","#4b6c98"))
		result.set_stylebox("pressed",type,box("#243e60","#668bbc"))
		result.set_stylebox("focus",type,UI.style(Color.TRANSPARENT,6,ACCENT))
		result.set_stylebox("disabled",type,box("#141b26","#252d3a"))
	result.set_stylebox("panel","PanelContainer",box("#151c28","#2a3342"))
	result.set_stylebox("panel","PopupMenu",box("#19212e","#354359"))
	result.set_stylebox("normal","LineEdit",box("#101722","#303c50"))
	result.set_stylebox("focus","LineEdit",box("#101722","#6e99d1"))
	result.set_stylebox("normal","TextEdit",box("#101722","#303c50"))
	result.set_color("font_color","TextEdit",Color("#e4eaf3"))
	result.set_stylebox("panel","ItemList",box("#101722","#263348"))
	result.set_stylebox("selected","ItemList",box("#263f60","#476b9c"))
	result.set_stylebox("selected_focus","ItemList",box("#263f60","#6e99d1"))
	result.set_stylebox("fill","ProgressBar",box("#648cc5","#648cc5"))
	result.set_stylebox("panel","TabContainer",box("#151c28","#2a3342"))
	result.set_stylebox("tab_selected","TabContainer",box("#263b58","#47658a"))
	result.set_stylebox("tab_unselected","TabContainer",box("#131b28","#2a3342"))
	result.set_color("font_selected_color","TabContainer",Color("#e4eaf3"))
	result.set_color("font_unselected_color","TabContainer",Color("#9faec4"))
	return result

static func box(background: String, border: String) -> StyleBoxFlat:
	var value = UI.style(Color(background),7,Color(border))
	value.content_margin_left = 12
	value.content_margin_right = 12
	value.content_margin_top = 9
	value.content_margin_bottom = 9
	return value

static func icon(name: String) -> Texture2D:
	if icons.has(name):
		return icons[name]
	var paths = {
		"Dashboard":"M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z",
		"Personagens":"M5 21v-3a7 7 0 0 1 14 0v3 M8 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0",
		"Golpes":"M12 3l9 4v6c0 5-9 9-9 9s-9-4-9-9V7z M8 12l3 3 5-6",
		"Biblioteca":"M3 6h7l2 3h9v12H3z M3 6V3h7l2 3h9v3",
		"Áudio":"M4 14v-3a8 8 0 0 1 16 0v3 M4 12h3v8H4z M17 12h3v8h-3z",
		"Arenas":"M2 20L9 7l4 7 3-5 6 11z M8 9l3 2",
		"Campanha":"M5 22V3 M5 3h14l-3 5 3 5H5",
		"Controles":"M7 7h10c3 0 5 7 4 11s-4 1-6-1H9c-2 2-5 4-6 1S4 7 7 7z M5 12h6 M8 9v6 M16 11h1 M18 14h1",
		"Testador":"M6 3l15 9L6 21z",
		"Publicação":"M12 16V2 M7 7l5-5 5 5 M3 14v7h18v-7",
		"Configurações":"M4 6h16 M4 12h16 M4 18h16 M8 3v6 M16 9v6 M10 15v6"}
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#a7b9d3" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>' % paths.get(name,paths.Dashboard)
	var image = Image.new()
	image.load_svg_from_string(svg)
	icons[name] = ImageTexture.create_from_image(image)
	return icons[name]
