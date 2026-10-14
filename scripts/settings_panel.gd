extends PanelContainer
signal closed
const RESOLUTIONS := [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
var settings
var pending: Dictionary
var volume_sliders: Dictionary = {}
var hud_slider: HSlider
var hud_value: Label
var vsync: CheckButton
var frame_limit: OptionButton
var smoothing: OptionButton
var mode: OptionButton
var resolution: OptionButton
var message: Label

func configure(model) -> void:
	theme = preload("res://scripts/ui_style.gd").theme(&"menu")
	settings = model
	pending = settings.values.duplicate()
	custom_minimum_size = Vector2(700,500)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",18)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "CONFIGURACIÓN"
	preload("res://scripts/ui_style.gd").set_font_size(heading,30)
	box.add_child(heading)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	var gameplay := page(tabs,"Juego")
	var automatic := CheckButton.new()
	automatic.name = "AutomaticRun"
	automatic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	automatic.text = "Correr automáticamente"
	automatic.button_pressed = pending.get("auto_run",false)
	automatic.toggled.connect(func(enabled): pending["auto_run"] = enabled)
	gameplay.add_child(automatic)
	var hud_row := HBoxContainer.new()
	gameplay.add_child(hud_row)
	var hud_label := Label.new()
	hud_label.text = "Tamaño del HUD"
	hud_label.custom_minimum_size.x = 230
	hud_row.add_child(hud_label)
	hud_slider = HSlider.new()
	hud_slider.name = "HUDSize"
	hud_slider.min_value = 1; hud_slider.max_value = 6; hud_slider.step = 1
	hud_slider.tick_count = 6; hud_slider.ticks_on_borders = true
	hud_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_row.add_child(hud_slider)
	hud_value = Label.new(); hud_value.custom_minimum_size.x = 104
	hud_row.add_child(hud_value)
	hud_slider.value_changed.connect(func(value): pending["hud_size"] = int(value); hud_value.text = "%d · %d%% área" % [value,roundi(40*(1+0.2*(value-1)))])
	hud_slider.value = pending["hud_size"]
	hud_value.text = "%d · %d%% área" % [hud_slider.value,roundi(40*(1+0.2*(hud_slider.value-1)))]
	var graphics := page(tabs,"Gráficos")
	var sound := page(tabs,"Audio")
	for pair in [["Volumen general","master"],["Música","music"],["Efectos","effects"]]:
		var row := HBoxContainer.new()
		sound.add_child(row)
		var label := Label.new()
		label.text = pair[0]
		label.custom_minimum_size.x = 200
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var number := Label.new()
		number.custom_minimum_size.x = 55
		row.add_child(number)
		slider.value_changed.connect(func(value): pending[pair[1]] = value/100; number.text = "%d%%" % value)
		slider.value = pending[pair[1]]*100
		number.text = "%d%%" % slider.value
		volume_sliders[pair[1]] = slider
	var note := Label.new()
	note.text = "Aún no hay sonidos. El volumen queda guardado para cuando se añadan."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sound.add_child(note)
	smoothing = option(graphics,"Suavizado de bordes",["Desactivado (pixel art)","MSAA 2×","MSAA 4×"])
	if not settings.supports_msaa_2d():
		pending["msaa"] = 0
		smoothing.set_item_disabled(1,true)
		smoothing.set_item_disabled(2,true)
		smoothing.tooltip_text = "MSAA 2D no está disponible con el renderizador de compatibilidad."
	smoothing.select(pending["msaa"])
	smoothing.item_selected.connect(func(index): pending["msaa"] = index)
	frame_limit = option(graphics,"Límite de fotogramas",["30 FPS","60 FPS","120 FPS","144 FPS","Sin límite"])
	frame_limit.select([30,60,120,144,0].find(pending["fps"]))
	frame_limit.item_selected.connect(func(index): pending["fps"] = [30,60,120,144,0][index])
	vsync = CheckButton.new()
	vsync.text = "Sincronización vertical"
	vsync.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vsync.button_pressed = pending["vsync"]
	vsync.toggled.connect(func(enabled): pending["vsync"] = enabled)
	graphics.add_child(vsync)
	var screen := graphics
	mode = option(screen,"Modo de pantalla",["Ventana","Pantalla completa","Ventana sin bordes"])
	mode.select(pending["window_mode"])
	mode.item_selected.connect(func(index): pending["window_mode"] = index)
	resolution = option(screen,"Resolución",["1280 × 720","1600 × 900","1920 × 1080","2560 × 1440"])
	resolution.select(maxi(0,RESOLUTIONS.find(pending["resolution"])))
	resolution.item_selected.connect(func(index): pending["resolution"] = RESOLUTIONS[index])
	message = Label.new()
	message.text = "Los cambios se guardan al pulsar Aplicar."
	box.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	var cancel := preload("res://scripts/menu_button.gd").new()
	cancel.text = "Volver"
	cancel.pressed.connect(func(): closed.emit())
	buttons.add_child(cancel)
	var apply_button := preload("res://scripts/menu_button.gd").new()
	apply_button.text = "Aplicar"
	apply_button.pressed.connect(apply_changes)
	buttons.add_child(apply_button)
	get_viewport().size_changed.connect(fit)
	fit()

func page(tabs: TabContainer, title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,18)
	tabs.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",22)
	margin.add_child(box)
	return box

func option(parent: Control, text: String, choices: Array) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 230
	row.add_child(label)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	selector.fit_to_longest_item = false
	for choice in choices:
		selector.add_item(choice)
	row.add_child(selector)
	return selector

func apply_changes() -> void:
	settings.values = pending.duplicate()
	settings.apply(get_viewport())
	message.text = "Configuración guardada." if settings.save_settings() == OK else "No se pudo guardar la configuración."

func fit() -> void:
	if not is_inside_tree(): return
	var screen := get_viewport_rect().size
	size = Vector2(minf(940,screen.x*0.9),minf(600,screen.y*0.88))
	position = (screen-size)/2
