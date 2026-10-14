extends Control
signal tab_changed(index: int)
const Art = preload("res://scripts/inventory_art.gd")
const TITLES := ["Inventario","Creación","Habilidades","Perks","Mapa","Misiones","Logros"]
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
	var x := 0.0
	for i in TITLES.size():
		var button := preload("res://scripts/menu_button.gd").new()
		button.text = "CREAR" if i == 1 else TITLES[i].to_upper()
		preload("res://scripts/ui_style.gd").set_font_size(button,21)
		Art.skin(button,Art.TAB); button.fit_text()
		button.position = Vector2(x,18)
		button.pressed.connect(func(): current_tab = i)
		add_child(button); buttons.append(button); x += button.size.x+12
	current_tab = 0
