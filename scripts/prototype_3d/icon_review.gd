extends Control
func _ready() -> void:
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;theme=preload("res://scripts/ui_style.gd").theme()
 var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(scroll)
 var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",18);scroll.add_child(grid)
 for id in preload("res://scripts/inventory.gd").DEFINITIONS:
  var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(220,210);grid.add_child(box)
  var image:=TextureRect.new();image.texture=preload("res://scripts/prototype_3d/item_icons.gd").get_icon(id);image.custom_minimum_size=Vector2(180,170);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;box.add_child(image)
  var label:=Label.new();label.text=preload("res://scripts/inventory.gd").DEFINITIONS[id].name;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(label)
