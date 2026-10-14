extends PanelContainer
signal closed
var game
var hud_slider:HSlider
var auto_run:CheckButton
var size_label:Label
func configure(owner_game) -> void:
 game=owner_game;theme=preload("res://scripts/ui_style.gd").theme(&"menu")
 custom_minimum_size=Vector2(470,240)
 var layout:=VBoxContainer.new();layout.add_theme_constant_override("separation",18);add_child(layout)
 var heading:=Label.new();heading.text="CONFIGURACIÓN · JUEGO";layout.add_child(heading)
 auto_run=CheckButton.new();auto_run.text="Correr automáticamente";auto_run.button_pressed=game.settings.values.auto_run;layout.add_child(auto_run)
 auto_run.toggled.connect(func(value):game.settings.values.auto_run=value;save())
 size_label=Label.new();layout.add_child(size_label)
 hud_slider=HSlider.new();hud_slider.min_value=1;hud_slider.max_value=6;hud_slider.step=1;hud_slider.value=game.settings.values.hud_size;hud_slider.custom_minimum_size=Vector2(360,28);layout.add_child(hud_slider)
 hud_slider.value_changed.connect(func(value):game.settings.values.hud_size=int(value);save())
 var close:=preload("res://scripts/menu_button.gd").new();close.text="Volver";close.pressed.connect(func():closed.emit());layout.add_child(close)
 update_text()
func save() -> void:
 game.settings.save_settings();game.settings.changed.emit();update_text()
func update_text() -> void:size_label.text="Tamaño del HUD: %d / 6"%int(game.settings.values.hud_size)
