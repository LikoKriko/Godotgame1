extends Control
const Art = preload("res://scripts/inventory_art.gd")
var game
var panel: Panel
var content: Control
var page: Control
func configure(owner_game) -> void:
	game = owner_game; theme = preload("res://scripts/ui_style.gd").theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new(); veil.color = Color(0,0,0,0.65)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(veil)
	panel = Panel.new(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); add_child(panel)
	content = Control.new(); content.size = Art.SIZE; panel.add_child(content)
	Art.patch(content,Rect2(Vector2.ZERO,Art.SIZE),Art.BOUNDS)
	var heading := Label.new(); heading.text = "MESA DE FABRICACIÓN BÁSICA"
	preload("res://scripts/ui_style.gd").set_font_size(heading,24)
	heading.position = Vector2(55,32); heading.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(heading)
	var close := preload("res://scripts/menu_button.gd").new(); close.text = "Cerrar"
	close.position = Vector2(1170,32); close.pressed.connect(hide); content.add_child(close)
	page = preload("res://scripts/creation_page.gd").new(); page.position = Vector2(55,142)
	content.add_child(page); page.configure(game.bag,1)
	page.crafted.connect(func(_message): game.inventory_panel.refresh(); game.update_hud())
	visibility_changed.connect(func():
		if not visible: page.cancel_creation()
	)
	resized.connect(fit); fit(); hide()
func fit() -> void:
	var screen := get_viewport_rect().size
	var factor := minf(sqrt(screen.x*screen.y*0.6/(Art.SIZE.x*Art.SIZE.y)),minf(screen.x*0.95/Art.SIZE.x,screen.y*0.84/Art.SIZE.y))
	panel.size = Art.SIZE*factor; panel.position = (screen-panel.size)/2; content.scale = Vector2.ONE*factor
func open_window() -> void: page.refresh(); show(); fit()
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide(); get_viewport().set_input_as_handled()
