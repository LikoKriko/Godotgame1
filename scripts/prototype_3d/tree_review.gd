extends Node3D
## F6: orbit the edited oak and inspect roots/branches at the retained heights.
var tree:Node3D
var camera:=Camera3D.new()
var orbit:=0.0
var elevation:=0.15
var dragging:=false
var zoom:=6.0
func _ready() -> void:
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true;add_child(sun)
 var ambient:=WorldEnvironment.new();ambient.environment=Environment.new();ambient.environment.background_mode=Environment.BG_COLOR;ambient.environment.background_color=Color("414c51");ambient.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;ambient.environment.ambient_light_color=Color.WHITE;ambient.environment.ambient_light_energy=.6;add_child(ambient)
 add_child(camera);camera.current=true;camera.fov=48
 var floor_node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,20);floor_node.mesh=plane;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("3e4936");floor_node.material_override=mat;add_child(floor_node)
 var ui:=CanvasLayer.new();add_child(ui);var column:=VBoxContainer.new();column.position=Vector2(20,20);ui.add_child(column)
 var title:=Label.new();title.text="Árboles · botón derecho: girar · rueda: acercar/alejar";column.add_child(title)
 var designs:=OptionButton.new();column.add_child(designs)
 for i in 9:designs.add_item("Altura %.4g m"%preload("res://scripts/prototype_3d/tree_geometry.gd").HEIGHTS[i])
 var variations:=OptionButton.new();column.add_child(variations)
 for i in 4:variations.add_item("Orientación %d°"%(i*90))
 designs.item_selected.connect(func(_index):show_design(designs.selected,variations.selected))
 variations.item_selected.connect(func(_index):show_design(designs.selected,variations.selected))
 show_design(0,0)
func show_design(design:int,variation:int) -> void:
 if is_instance_valid(tree):tree.free()
 tree=preload("res://scripts/prototype_3d/tree_model.gd").new();tree.design_id=design;tree.variant_id=variation;add_child(tree)
func _process(_delta:float) -> void:
 var target:Vector3=Vector3.UP*tree.visual_height()*.50
 camera.position=target+Vector3(sin(orbit)*cos(elevation),sin(elevation),cos(orbit)*cos(elevation))*zoom;camera.look_at(target)
func _unhandled_input(event:InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
  elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=maxf(2,zoom-.3)
  elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=minf(12,zoom+.3)
 if event is InputEventMouseMotion and dragging:orbit-=event.relative.x*.008;elevation=clampf(elevation+event.relative.y*.006,-.15,1.2)
