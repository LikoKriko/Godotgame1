extends Control
signal confirmed
var panel: PanelContainer
var ok_button: Button
var cancel_button: Button
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = preload("res://scripts/ui_style.gd").theme(&"game")
	var veil := ColorRect.new(); veil.color = Color(0,0,0,0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(veil)
	panel = PanelContainer.new(); add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",20); margin.add_child(box)
	var heading := Label.new(); heading.text = "NUEVA PARTIDA"
	preload("res://scripts/ui_style.gd").set_font_size(heading,24); box.add_child(heading)
	var text := Label.new()
	text.text = "¿Iniciar una nueva partida? Los cambios sin guardar de la partida abierta se perderán. El guardado anterior se conserva hasta que guardes la nueva partida."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(text)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation",20); box.add_child(row)
	cancel_button = preload("res://scripts/menu_button.gd").new(); cancel_button.text = "CANCELAR"
	row.add_child(cancel_button); cancel_button.pressed.connect(hide)
	ok_button = preload("res://scripts/menu_button.gd").new(); ok_button.text = "NUEVA PARTIDA"
	row.add_child(ok_button); ok_button.pressed.connect(func(): hide(); confirmed.emit())
	get_viewport().size_changed.connect(fit)
	panel.minimum_size_changed.connect(func(): fit.call_deferred())
	hide()
func fit() -> void:
	if panel == null: return
	var screen := get_viewport_rect().size
	panel.size = Vector2(minf(640,screen.x*0.9),maxf(260,panel.get_combined_minimum_size().y))
	panel.position = (screen-panel.size)/2
func popup_centered(_requested: Vector2i = Vector2i.ZERO) -> void:
	show(); fit(); fit.call_deferred(); cancel_button.grab_focus()
func get_cancel_button() -> Button: return cancel_button
func get_ok_button() -> Button: return ok_button
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event.keycode == KEY_ESCAPE:
		hide(); get_viewport().set_input_as_handled()
