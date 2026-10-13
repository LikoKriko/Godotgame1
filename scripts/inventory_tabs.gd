extends Control
signal tab_changed(index: int)
const Art = preload("res://scripts/inventory_art.gd")
const TITLES := ["Inventario","Creación","Habilidades","Perks","Mapa"]
var buttons: Array[Button] = []
var highlights: Array[ColorRect] = []
var current_tab := 0:
	set(value):
		if value < 0 or value >= TITLES.size(): return
		current_tab = value
		for i in buttons.size(): buttons[i].self_modulate = Color(1.25,1.22,0.8) if i == value else Color.WHITE
		for i in highlights.size(): highlights[i].visible = i == value
		tab_changed.emit(value)
var tab_count: int:
	get: return TITLES.size()
func get_tab_title(index: int) -> String: return TITLES[index]
func configure() -> void:
	size = Vector2(1222,80); mouse_filter = Control.MOUSE_FILTER_IGNORE
	var widths := [277,222,246,223,223]
	var x := 0.0
	for i in TITLES.size():
		var highlight := ColorRect.new(); highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.position = Vector2(x+12,12); highlight.size = Vector2(widths[i]-24,54)
		highlight.color = Color(0.35,0.42,0.07,0.45); add_child(highlight); highlights.append(highlight)
		var button := preload("res://scripts/menu_button.gd").new()
		button.text = "CREAR" if i == 1 else TITLES[i].to_upper()
		button.position = Vector2(x,0); button.size = Vector2(widths[i],78)
		preload("res://scripts/ui_style.gd").set_font_size(button,25)
		button.clip_text = true
		Art.skin(button,Art.TAB)
		button.pressed.connect(func(): current_tab = i)
		add_child(button); buttons.append(button); x += widths[i]+7
	current_tab = 0
