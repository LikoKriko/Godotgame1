extends Control
signal play_requested
signal main_menu_requested
var settings
var resumed := false
var play_button: Button
var settings_button: Button
var return_button: Button
var options: VBoxContainer
var title_area: Control
var title: Label
var settings_panel: PanelContainer

func configure(model) -> void:
	settings = model
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("101713"),Color("253126"),Color("111813")])
	gradient.offsets = PackedFloat32Array([0,0.65,1])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1,0.5)
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(background)
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation",24)
	add_child(options)
	play_button = button("Jugar",func(): play_requested.emit())
	settings_button = button("Configuración",open_settings)
	return_button = button("Menú principal",func(): main_menu_requested.emit())
	return_button.hide()
	button("Salir",func(): get_tree().quit())
	title_area = Control.new()
	title_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_area)
	title = Label.new()
	title.text = "DAY\nZERO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("cbbf8b"))
	title.add_theme_color_override("font_shadow_color",Color("0b100d"))
	title.add_theme_constant_override("shadow_offset_x",5)
	title.add_theme_constant_override("shadow_offset_y",7)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_area.add_child(title)
	resized.connect(fit)
	fit()

func button(text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 64
	node.add_theme_font_size_override("font_size",28)
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.pressed.connect(callback)
	options.add_child(node)
	return node

func set_resume(active: bool) -> void:
	resumed = active
	play_button.text = "Continuar" if active else "Jugar"
	return_button.visible = active

func fit() -> void:
	options.position = Vector2(size.x*0.065,size.y*0.38)
	options.size.x = size.x*0.27
	title_area.position = Vector2(size.x*0.4,0)
	title_area.size = Vector2(size.x*0.6,size.y)
	title.size = title_area.size
	title.add_theme_font_size_override("font_size",roundi(minf(size.x*0.105,size.y*0.22)))

func open_settings() -> void:
	if is_instance_valid(settings_panel):
		return
	options.hide()
	title_area.hide()
	settings_panel = preload("res://scripts/settings_panel.gd").new()
	add_child(settings_panel)
	settings_panel.configure(settings)
	settings_panel.closed.connect(close_settings)

func close_settings() -> void:
	if is_instance_valid(settings_panel):
		remove_child(settings_panel)
		settings_panel.queue_free()
	options.show()
	title_area.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if is_instance_valid(settings_panel):
			close_settings()
		elif resumed:
			play_requested.emit()
		get_viewport().set_input_as_handled()
