extends CanvasLayer
var progress: ProgressBar
var caption: Label
func _ready() -> void:
	layer = 3000
	var background := ColorRect.new(); background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); center.add_child(box)
	caption = Label.new(); caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color",Color.WHITE); preload("res://scripts/ui_style.gd").set_font_size(caption,24)
	box.add_child(caption)
	progress = ProgressBar.new(); progress.custom_minimum_size = Vector2(360,18)
	progress.show_percentage = false; progress.max_value = 1
	var frame := StyleBoxFlat.new(); frame.bg_color = Color.BLACK
	frame.border_color = Color.WHITE; frame.set_border_width_all(1); frame.set_content_margin_all(2)
	progress.add_theme_stylebox_override("background",frame)
	var fill := StyleBoxFlat.new(); fill.bg_color = Color.WHITE
	progress.add_theme_stylebox_override("fill",fill); box.add_child(progress)
	hide()
func begin(restoring: bool) -> void:
	caption.text = "Cargando mundo" if restoring else "Generando mundo"
	progress.value = 0; show()
func set_progress(value: float) -> void:
	progress.value = maxf(progress.value,clampf(value,0,1))
