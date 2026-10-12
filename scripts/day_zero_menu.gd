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
var art: TextureRect
var exact_art := false
var rects: Dictionary = {}
var confirmation: ConfirmationDialog
var message: Label
var mute_cover: TextureRect
var pause_faces: Dictionary = {}
var pause_font: Font = preload("res://assets/ui/pause_font.fnt")
const TEMPLATE_SIZE := Vector2(1672,941)

func configure(model) -> void:
	theme = preload("res://scripts/ui_style.gd").theme()
	settings = model
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exact_art = true
	art.texture = preload("res://assets/ui/title_template.png")
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
	if exact_art:
		mute_cover = TextureRect.new()
		var clean := AtlasTexture.new()
		clean.atlas = art.texture
		clean.region = Rect2(1542,801,10,10)
		mute_cover.texture = clean
		mute_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mute_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mute_button.add_child(mute_cover)
	return_button = button("Menú principal",Rect2(132,690,445,64),func(): main_menu_requested.emit(),false)
	save_button = button("Guardar partida",Rect2(651,690,365,64),func(): save_requested.emit(),false)
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
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Nueva partida"
	confirmation.dialog_text = "¿Iniciar una nueva partida? Los cambios sin guardar de la partida abierta se perderán. El guardado anterior se conserva hasta que guardes la nueva partida."
	confirmation.ok_button_text = "Nueva partida"
	confirmation.cancel_button_text = "Cancelar"
	confirmation.confirmed.connect(func(): new_game_requested.emit())
	add_child(confirmation)
	resized.connect(fit)
	settings.changed.connect(refresh_audio)
	set_resume(false)
	refresh_audio()
	fit()

func button(label: String, area: Rect2, callback: Callable, baked: bool = true) -> Button:
	var node := preload("res://scripts/menu_button.gd").new()
	node.clip_text = true
	node.text = "" if exact_art and baked else label
	node.tooltip_text = label
	node.add_theme_font_size_override("font_size",32)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		if exact_art and baked:
			style.bg_color = Color(0.6,0.8,0.65,0.14) if state in ["hover","pressed"] else Color(0,0,0,0.4 if state == "disabled" else 0)
			style.border_color = Color("d4cca1")
			style.set_border_width_all(1 if state == "focus" else 0)
		else:
			style.bg_color = Color("161e19") if state == "normal" else Color("2c392b")
			style.border_color = Color("797c56")
			style.set_border_width_all(1)
		node.add_theme_stylebox_override(state,style)
	node.pressed.connect(callback)
	options.add_child(node)
	rects[node] = area
	node.set_meta("caption",label)
	node.set_meta("baked",baked)
	if baked and label != "Silenciar":
		var blank := AtlasTexture.new()
		blank.atlas = art.texture
		blank.region = Rect2(173,194,40,35)
		var cover := TextureRect.new()
		cover.texture = blank
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.show_behind_parent = true
		cover.hide()
		node.add_child(cover)
		pause_faces[node] = cover
	if exact_art and not baked:
		var border_texture := AtlasTexture.new()
		border_texture.atlas = art.texture
		border_texture.region = Rect2(135,160,442,114)
		var fill_texture := AtlasTexture.new()
		fill_texture.atlas = art.texture
		fill_texture.region = Rect2(173,194,40,35)
		var fill := TextureRect.new()
		fill.texture = fill_texture
		fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.show_behind_parent = true
		node.add_child(fill)
		for state in ["normal","hover","pressed","focus","disabled"]:
			var rim := StyleBoxTexture.new()
			rim.texture = border_texture
			rim.texture_margin_left = 20; rim.texture_margin_right = 20
			rim.texture_margin_top = 16; rim.texture_margin_bottom = 16
			rim.draw_center = false
			rim.modulate_color = Color(1.25,1.35,1.15) if state in ["hover","pressed","focus"] else Color.WHITE
			node.add_theme_stylebox_override(state,rim)
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
		var baked: bool = node.get_meta("baked")
		node.text = String(node.get_meta("caption")).to_upper() if active or not baked else ""
		if pause_faces.has(node): pause_faces[node].visible = active
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
	mute_button.set_pressed_no_signal(settings.values["muted"])
	if mute_cover != null: mute_cover.visible = not settings.values["muted"]
	if not exact_art: mute_button.text = "♫×" if settings.values["muted"] else "♫"

func fit() -> void:
	var factor := minf(size.x/TEMPLATE_SIZE.x,size.y/TEMPLATE_SIZE.y)
	var offset := (size-TEMPLATE_SIZE*factor)/2
	art.position = offset
	art.size = TEMPLATE_SIZE*factor
	options.position = offset
	options.size = TEMPLATE_SIZE*factor
	for node in rects:
		node.position = rects[node].position*factor
		node.size = rects[node].size*factor
		var font_size := maxi(12,roundi((38 if rects[node].size.y > 90 and resumed else 30)*factor))
		if not node.text.is_empty():
			var width: float = pause_font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			if width > node.size.x-48*factor: font_size = maxi(12,floori(font_size*(node.size.x-48*factor)/width))
		node.add_theme_font_size_override("font_size",font_size)
		if pause_faces.has(node):
			var cover: TextureRect = pause_faces[node]
			cover.offset_left = 20*factor; cover.offset_right = -20*factor
			cover.offset_top = 16*factor; cover.offset_bottom = -16*factor
	if mute_cover != null:
		mute_cover.position = Vector2(57,31)*factor
		mute_cover.size = Vector2(22,32)*factor
	message.position = Vector2(600,760)*factor
	message.size = Vector2(550,28)*factor
	message.add_theme_font_size_override("font_size",maxi(12,roundi(18*factor)))
	title_area.position = Vector2(size.x*0.4,0)
	title_area.size = Vector2(size.x*0.6,size.y)

func open_settings() -> void:
	if is_instance_valid(settings_panel): return
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
	refresh_audio()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if is_instance_valid(settings_panel): close_settings()
		elif resumed: play_requested.emit()
		get_viewport().set_input_as_handled()
