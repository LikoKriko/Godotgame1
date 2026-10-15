extends Node3D
## F6 inspection only: creates no items in saved games or the inventory.
const Models=preload("res://scripts/prototype_3d/item_models.gd")
var current:Node3D
var item_id:StringName=&"axe"
var camera:=Camera3D.new()
var orbit:=0.4
var dragging:=false
var radius:=1.7
func _ready() -> void:
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true;add_child(sun)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("353e42");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("dfdbc9");environment.environment.ambient_light_energy=0.55;add_child(environment)
 var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(5,5);floor_mesh.mesh=plane;add_child(floor_mesh)
 add_child(camera);camera.current=true;camera.fov=48
 var layer:=CanvasLayer.new();add_child(layer);var panel:=VBoxContainer.new();panel.position=Vector2(18,18);layer.add_child(panel)
 var label:=Label.new();label.text="Objetos 3D · arrastra con botón derecho · rueda para acercar";panel.add_child(label)
 var options:=OptionButton.new();panel.add_child(options)
 for id in Models.SUPPORTED:options.add_item(preload("res://scripts/inventory.gd").DEFINITIONS[id].name+" ("+String(id)+")")
 options.item_selected.connect(func(index):item_id=Models.SUPPORTED[index];show_item())
 var water:=CheckButton.new();water.text="Botella llena";panel.add_child(water);water.toggled.connect(func(value):show_item(500 if value else 0))
 show_item()
func show_item(water_ml:int=0) -> void:
 if current!=null:current.free()
 current=Models.create({"id":item_id,"water_ml":water_ml});add_child(current)
 var bounds:=Models.bounds(current);radius=maxf(0.45,bounds.size.length()*1.5)
func _process(_delta:float) -> void:
 var target:=Models.bounds(current).get_center()
 camera.position=target+Vector3(sin(orbit)*radius,radius*0.65,cos(orbit)*radius);camera.look_at(target)
func _unhandled_input(event:InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
  elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:radius=maxf(0.2,radius*0.9)
  elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:radius=minf(5,radius*1.1)
 if event is InputEventMouseMotion and dragging:orbit-=event.relative.x*0.01
