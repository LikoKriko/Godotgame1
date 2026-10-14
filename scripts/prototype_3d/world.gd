extends Node3D
## Reviewable first slice: real 3D survivor, shoulder camera, axe and woodland.
var player: CharacterBody3D
var camera_rig: Node3D
var paused := false
var bag = preload("res://scripts/inventory.gd").new()
var status: Label
var pause_panel: Control
var message_time := 0.0
func _ready() -> void:
 # The 2D cursor autoload would override captured mouse mode each frame.
 var cursor := get_tree().root.get_node_or_null("GameCursor")
 if cursor != null: cursor.set_process(false); cursor.hide()
 for overlay in get_tree().root.get_children():
  if overlay.name == &"GameCursor": continue
  if overlay.get("name") == &"DayZeroCursor": overlay.hide(); overlay.process_mode = Node.PROCESS_MODE_DISABLED
 Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
 bag.reset()
 build_environment()
 player = preload("res://scripts/prototype_3d/player.gd").new(); add_child(player); player.configure(self); player.position = Vector3(0,0.2,2.0)
 camera_rig = preload("res://scripts/prototype_3d/shoulder_camera.gd").new(); add_child(camera_rig); camera_rig.configure(self,player); camera_rig.update(1.0)
 build_ui()
func build_environment() -> void:
 var environment := WorldEnvironment.new(); var settings := Environment.new()
 settings.background_mode = Environment.BG_COLOR; settings.background_color = Color("809495")
 settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color = Color("b2b59b"); settings.ambient_light_energy = 0.6
 environment.environment = settings; add_child(environment)
 var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52,-35,0); sun.light_color = Color("fff1d6"); sun.light_energy = 1.2; sun.shadow_enabled = true; add_child(sun)
 var ground := StaticBody3D.new(); add_child(ground)
 var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(48,0.4,48); shape.shape = box; shape.position.y = -0.2; ground.add_child(shape)
 var mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(48,48); mesh.mesh = plane
 var material := StandardMaterial3D.new(); material.albedo_color = Color("7b8053"); material.albedo_texture = load("res://assets/environment/imported/terreno_1_1.png")
 material.uv1_scale = Vector3(12,12,1); material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; material.roughness = 1.0; mesh.material_override = material; ground.add_child(mesh)
 for point in [Vector3(0,0,-1.6),Vector3(3,0,-4),Vector3(-3,0,-5),Vector3(5,0,3)]:
  var tree := preload("res://scripts/prototype_3d/tree_model.gd").new(); add_child(tree); tree.position = point; tree.scale = Vector3.ONE*0.65
 # A solid test wall also provides an explicit camera collision case.
 var wall := StaticBody3D.new(); add_child(wall); wall.position = Vector3(-6,1,-2)
 var collider := CollisionShape3D.new(); var block := BoxShape3D.new(); block.size = Vector3(0.5,2,5); collider.shape = block; wall.add_child(collider)
 var visual := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = block.size; visual.mesh = cube
 var paint := StandardMaterial3D.new(); paint.albedo_color = Color("686257"); paint.roughness = 1.0; visual.material_override = paint; wall.add_child(visual)
func build_ui() -> void:
 var layer := CanvasLayer.new(); add_child(layer)
 var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(root)
 var aim := Label.new(); aim.text = "·"; aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; aim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER); aim.offset_left = -12; aim.offset_top = -12; aim.offset_right = 12; aim.offset_bottom = 12; aim.add_theme_font_size_override("font_size",28); root.add_child(aim)
 status = Label.new(); status.position = Vector2(20,20); status.text = "DAY ZERO · PROTOTIPO 3D"; root.add_child(status)
 var help := Label.new(); help.text = "WASD: mover · Ratón: cámara · Shift: correr · Ctrl: agachar/deslizar · Espacio: saltar · 1: hacha/manos · Clic: talar · Esc: pausa"
 help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); help.position = Vector2(20,-36); root.add_child(help)
 pause_panel = CenterContainer.new(); pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(pause_panel); pause_panel.hide()
 var frame := PanelContainer.new(); frame.theme = preload("res://scripts/ui_style.gd").theme(); pause_panel.add_child(frame)
 var buttons := VBoxContainer.new(); buttons.add_theme_constant_override("separation",16); frame.add_child(buttons)
 for caption in ["Continuar","Abrir versión 2D","Salir"]:
  var button := preload("res://scripts/menu_button.gd").new(); button.text = caption; buttons.add_child(button)
  button.pressed.connect(toggle_pause if caption == "Continuar" else (open_2d if caption == "Abrir versión 2D" else get_tree().quit))
func toggle_pause() -> void:
 paused = not paused; pause_panel.visible = paused
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
func open_2d() -> void:
 if get_tree().root.get_node_or_null("GameCursor") == null:
  var cursor := preload("res://scripts/cursor_overlay.gd").new(); cursor.name = "GameCursor"; get_tree().root.add_child(cursor)
 get_tree().change_scene_to_file("res://scenes/day_zero.tscn")
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE: toggle_pause(); get_viewport().set_input_as_handled()
  elif event.keycode == KEY_1 and not paused: player.toggle_tool()
 if paused: return
 if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: camera_rig.look(event.relative)
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: player.strike()
func resolve_hit(click_target = null) -> bool:
 var result: Dictionary = camera_rig.target() if click_target == null else click_target
 if result.is_empty() or not is_instance_valid(result.collider) or not result.collider.is_in_group("prototype_trees"):
  status.text = "Golpe al aire"; return false
 var tree: Node3D = result.collider
 if player.global_position.distance_to(tree.global_position) > 2.4: status.text = "Acércate al árbol"; return false
 if not tree.hit(): return false
 bag.consume_use()
 if tree.health == 0: bag.add(&"madera",4)
 status.text = "Árbol: %d golpes restantes · Madera: %d" % [tree.health,bag.count(&"madera")]
 return true
func _exit_tree() -> void:
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 var cursor := get_tree().root.get_node_or_null("GameCursor")
 if cursor != null: cursor.show(); cursor.set_process(true)
