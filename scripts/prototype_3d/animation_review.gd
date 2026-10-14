extends Node3D
## Standalone F6 review scene: no new objects or mechanics are granted in-game.
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
@export var species:StringName=&"survivor"
const YOUNG_STATES:Array[StringName]=[&"idle",&"walk",&"run",&"rise",&"attack",&"lower",&"sit_down",&"sit",&"sit_up",&"feed",&"stun_fall",&"stun_hold",&"stun_rise",&"death",&"corpse"]
var actor: Node3D
var camera:=Camera3D.new()
var family: StringName = &""
var clip: StringName = &"idle"
var elapsed:=0.0
var orbit:=0.0
var orbiting:=false
var speed:=1.0
func _ready() -> void:
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true;add_child(sun)
 var ambient:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
 environment.background_color=Color("444c51");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("bbb4a6");environment.ambient_light_energy=0.7;ambient.environment=environment;add_child(ambient)
 actor=(preload("res://scripts/prototype_3d/young_model.gd") if species==&"young" else preload("res://scripts/prototype_3d/survivor_model.gd")).new();add_child(actor)
 var bounds: AABB=actor.mesh_node.mesh.get_aabb();actor.scale=Vector3.ONE*((0.875 if species==&"young" else 1.75)/bounds.size.y);actor.position.y=-bounds.position.y*actor.scale.y
 add_child(camera);camera.current=true;camera.fov=48
 var floor_node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(10,10);floor_node.mesh=plane;add_child(floor_node)
 var layer:=CanvasLayer.new();add_child(layer);var column:=VBoxContainer.new();column.position=Vector2(20,20);layer.add_child(column)
 var title:=Label.new();title.text="Revisión de animaciones · arrastra con botón derecho para girar";column.add_child(title)
 var families:=OptionButton.new()
 var family_options:Array[StringName]=[]
 family_options.assign([&"left",&"right"] if species==&"young" else Clips.FAMILIES)
 for name in family_options:families.add_item("Manos libres" if name==&"" else String(name))
 column.add_child(families);families.item_selected.connect(func(index):family=family_options[index];elapsed=0)
 var states:=OptionButton.new()
 var state_options:Array[StringName]=YOUNG_STATES if species==&"young" else Clips.STATES
 for name in state_options:states.add_item(String(name))
 column.add_child(states);states.item_selected.connect(func(index):clip=state_options[index];elapsed=0)
 var slow:=CheckButton.new();slow.text="Cámara lenta";column.add_child(slow);slow.toggled.connect(func(value):speed=0.25 if value else 1.0)
 if species!=&"young":
  var pulse:=Button.new();pulse.text="Previsualizar pulso de parry";column.add_child(pulse);pulse.pressed.connect(func():actor.confirm_parry())
func _process(delta: float) -> void:
 elapsed+=delta*speed
 if species==&"young":
  var seconds:float={&"run":0.26,&"walk":0.52,&"attack":1.0,&"rise":0.28,&"lower":0.28,&"sit":6.0,&"sit_down":0.28,&"sit_up":0.28,&"feed":4.0,&"stun_fall":0.24,&"stun_hold":1.02,&"stun_rise":0.24,&"death":2.0}.get(clip,1.0)
  actor.animate(clip,fposmod(elapsed/seconds,1),family!=&"right",delta*speed)
 else:
  var phase:=fposmod(elapsed/Clips.duration(clip,family),1)
  actor.family_override=family;actor.aim_contact=Vector3(0,42,31)
  var moving:=String(clip).contains("walk") or clip in [&"run",&"start",&"stop",&"start_run",&"stop_run"]
  actor.animate(clip,phase,family==&"axe",delta*speed,fposmod(elapsed/0.6,1),Vector3.BACK if moving else Vector3.ZERO)
 var distance:=1.9 if species==&"young" else 3.2
 camera.position=Vector3(sin(orbit)*distance,0.8 if species==&"young" else 1.35,cos(orbit)*distance);camera.look_at(Vector3(0,0.48 if species==&"young" else 0.95,0))
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:orbiting=event.pressed
 if event is InputEventMouseMotion and orbiting:orbit-=event.relative.x*0.01
