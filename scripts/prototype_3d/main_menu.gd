extends "res://scripts/day_zero_menu.gd"
## Approved menu artwork and integrated confirmation; only 3D settings are exposed.
var settings_owner
func configure(model) -> void:
 settings_owner=RefCountedSettings.new(model)
 super.configure(model)
func open_settings() -> void:
 if is_instance_valid(settings_panel):return
 settings_backdrop=ColorRect.new();settings_backdrop.color=Color(0,0,0,0.55);settings_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(settings_backdrop)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);settings_backdrop.add_child(center)
 settings_panel=preload("res://scripts/prototype_3d/settings_panel.gd").new();center.add_child(settings_panel);settings_panel.configure(settings_owner);settings_panel.closed.connect(close_settings)
func close_settings() -> void:
 if is_instance_valid(settings_panel):settings_panel.queue_free();settings_panel=null
 if is_instance_valid(settings_backdrop):settings_backdrop.queue_free();settings_backdrop=null
 refresh_audio()
class RefCountedSettings extends RefCounted:
 var settings
 func _init(value):settings=value
