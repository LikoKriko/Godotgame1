extends Control
signal play_requested
signal new_game_requested
signal main_menu_requested
signal save_requested
var settings
var resumed := false
var can_continue := false
var play_button: Button
var continue_button: Button
var new_game_button: Button
var settings_button: Button
var return_button: Button
var save_button: Button
var mute_button: Button
var shop_button: Button
var options: Control
var title_area: Control
var title: Label
var settings_panel: PanelContainer
var settings_backdrop: ColorRect
var art: TextureRect
var rects: Dictionary = {}
var confirmation: Control
var message: Label
var pause_font: Font = preload("res://scripts/ui_style.gd").menu_font()
const TEMPLATE_SIZE := Vector2(1672,941)

func configure(model) -> void:
	theme = preload("res://scripts/ui_style.gd").theme(&"menu")
	settings = model
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = load("res://assets/ui/title_background.png")
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(art)
	options = Control.new()
	options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(options)
	continue_button = button("Continuar",Rect2(135,160,442,114),func(): play_requested.emit())
	new_game_button = button("Jugar",Rect2(134,287,443,114),request_new_game)
	play_button = new_game_button
	settings_button = button("Configuración",Rect2(132,416,445,111),open_settings)
	button("Salir",Rect2(132,543,445,110),func(): get_tree().quit())
	shop_button = button("Tienda",Rect2(651,784,365,94),func(): pass)
	shop_button.disabled = true
	shop_button.tooltip_text = "La tienda todavía no está disponible."
	mute_button = button("Silenciar",Rect2(1527,786,95,94),toggle_mute)
	mute_button.toggle_mode = true
	mute_button.icon = load("res://assets/ui/styles/mute_icon.png")
	mute_button.expand_icon = true
	return_button = button("Menú principal",Rect2(132,690,445,64),func(): main_menu_requested.emit())
	save_button = button("Guardar partida",Rect2(651,690,365,64),func(): save_requested.emit())
	message = Label.new()
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options.add_child(message)
	title_area = Control.new()
	title_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_area)
	title = Label.new()
	title.text = "DAY\nZERO"
	title.hide()
	title_area.add_child(title)
	confirmation = preload("res://scripts/confirmation_panel.gd").new()
	confirmation.confirmed.connect(func(): new_game_requested.emit())
	add_child(confirmation)
	resized.connect(fit)
	settings.changed.connect(refresh_audio)
	set_resume(false)
	refresh_audio()
	fit()

func button(label: String, area: Rect2, callback: Callable) -> Button:
	var node := preload("res://scripts/menu_button.gd").new()
	node.text = label.to_upper(); node.tooltip_text = label
	node.pressed.connect(callback); options.add_child(node); rects[node] = area
	node.set_meta("caption",label)
	return node

func set_resume(active: bool) -> void:
	resumed = active
	play_button = continue_button if active else new_game_button
	return_button.visible = active
	save_button.visible = active
	continue_button.disabled = not (active or can_continue)
	message.text = ""
	for node in rects:
		if node == mute_button: continue
		node.add_theme_font_override("font",pause_font)
		node.text = String(node.get_meta("caption")).to_upper()
	fit()

func set_saved_available(available: bool) -> void:
	can_continue = available
	continue_button.disabled = not (resumed or available)

func request_new_game() -> void:
	if resumed or can_continue: confirmation.popup_centered(Vector2i(560,180))
	else: new_game_requested.emit()

func toggle_mute() -> void:
	settings.values["muted"] = not settings.values["muted"]
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),settings.values["muted"] or settings.values["master"] == 0)
	settings.save_settings()
	refresh_audio()

func refresh_audio() -> void:
	if mute_button == null: return
	mute_button.tooltip_text = "Activar sonido" if settings.values["muted"] else "Silenciar juego"
	mute_button.modulate = Color("91b9a3") if settings.values["muted"] else Color.WHITE
	var icon: Texture2D = load("res://assets/ui/styles/mute_icon.png")
	if not settings.values["muted"]:
		var speaker := AtlasTexture.new(); speaker.atlas = icon; speaker.region = Rect2(0,0,icon.get_width()*0.60,icon.get_height()); icon = speaker
	mute_button.icon = icon
	mute_button.set_pressed_no_signal(settings.values["muted"])
	mute_button.text = ""
	fit()

func fit() -> void:
	var factor := minf(size.x/TEMPLATE_SIZE.x,size.y/TEMPLATE_SIZE.y)
	var offset := (size-TEMPLATE_SIZE*factor)/2
	art.position = offset
	art.size = TEMPLATE_SIZE*factor
	options.position = offset
	options.size = TEMPLATE_SIZE*factor
	for node in rects:
		var font_size := maxi(12,roundi(30*factor))
		preload("res://scripts/ui_style.gd").set_font_size(node,font_size)
		preload("res://scripts/ui_style.gd").skin_button(node,&"menu")
		var metrics: Vector2 = Vector2.ONE*font_size if node == mute_button else node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		var padding: float = node.get_theme_font("font").get_height(font_size)*0.15
		node.custom_minimum_size = metrics+Vector2.ONE*padding*2
		node.size = node.custom_minimum_size
		node.position = (rects[node].position+rects[node].size/2)*factor-node.size/2
	message.position = Vector2(600,760)*factor
	message.size = Vector2(550,28)*factor
	preload("res://scripts/ui_style.gd").set_font_size(message,maxi(12,roundi(18*factor)))
	title_area.position = Vector2(size.x*0.4,0)
	title_area.size = Vector2(size.x*0.6,size.y)

func open_settings() -> void:
	if is_instance_valid(settings_panel): return
	# Keep the live pause captions visible; the backdrop blocks their input.
	settings_backdrop = ColorRect.new()
	settings_backdrop.color = Color(0,0,0,0.35)
	settings_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settings_backdrop)
	settings_panel = preload("res://scripts/settings_panel.gd").new()
	add_child(settings_panel)
	settings_panel.configure(settings)
	settings_panel.closed.connect(close_settings)

func close_settings() -> void:
	if is_instance_valid(settings_panel):
		remove_child(settings_panel)
		settings_panel.queue_free()
	if is_instance_valid(settings_backdrop):
		remove_child(settings_backdrop); settings_backdrop.queue_free()
	options.show()
	title_area.show()
	refresh_audio()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if confirmation.visible: confirmation.hide()
		elif is_instance_valid(settings_panel): close_settings()
		elif resumed: play_requested.emit()
		get_viewport().set_input_as_handled()
