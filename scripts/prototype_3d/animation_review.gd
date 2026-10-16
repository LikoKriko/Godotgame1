extends Node3D
## Standalone F6 review scene: no new objects or mechanics are granted in-game.
const Clips = preload("res://scripts/prototype_3d/survivor_animation.gd")
@export var species:StringName=&"survivor"
const YoungMotion=preload("res://scripts/prototype_3d/young_pose.gd")
const YOUNG_STATES:Array[StringName]=YoungMotion.STATES
var actor: Node3D
var camera:=Camera3D.new()
var family: StringName = &""
var clip: StringName = &"idle"
var elapsed:=0.0
var orbit:=0.0
var orbiting:=false
var speed:=1.0
var paused:=false
var manual_phase:=0.0
var contact_height:=1.2
var contact_distance:=0.88
var contact_marker:MeshInstance3D
var height_control:HSlider
var distance_control:HSlider
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
 var state_options:Array[StringName]=YOUNG_STATES.duplicate() if species==&"young" else Clips.STATES
 if species==&"young":state_options.push_front(&"reference");clip=&"reference"
 var labels={&"reference":"Postura de referencia",&"boxing_guard":"Guardia de boxeo",&"boxing_walk":"Avanzar en guardia",&"boxing_rise":"Entrar en boxeo",&"boxing_lower":"Salir de boxeo",&"hook":"Crochet alterno",&"sleep_down":"Acostarse",&"sleep":"Dormir",&"wake_up":"Despertarse",&"slide_back":"Deslizamiento hacia atrás",&"slide_back_left":"Deslizamiento atrás izquierda",&"slide_back_right":"Deslizamiento atrás derecha"}
 for name in state_options:states.add_item(labels.get(name,String(name)))
 column.add_child(states);states.item_selected.connect(func(index):clip=state_options[index];elapsed=0)
 if species==&"young":
  var views:=HBoxContainer.new();column.add_child(views)
  for i in 4:
   var view:=Button.new();view.text=["Frente","Derecha","Espalda","Izquierda"][i];views.add_child(view)
   var angle:float=[0.0,deg_to_rad(-68),PI,deg_to_rad(68)][i]
   view.pressed.connect(func():orbit=angle)
 var slow:=CheckButton.new();slow.text="Cámara lenta";column.add_child(slow);slow.toggled.connect(func(value):speed=0.25 if value else 1.0)
 var pause:=CheckButton.new();pause.text="Pausar / revisar fase";column.add_child(pause);pause.toggled.connect(func(value):paused=value)
 var phase_control:=HSlider.new();phase_control.min_value=0;phase_control.max_value=1;phase_control.step=.005;phase_control.custom_minimum_size.x=220;column.add_child(phase_control);phase_control.value_changed.connect(func(value):manual_phase=value)
 if species!=&"young":
  var armor:=CheckButton.new();armor.text="Armadura de hojas";column.add_child(armor);armor.toggled.connect(func(value):actor.wear({"id":&"burdock_armor"} if value else {}))
  var crouched:=CheckButton.new();crouched.text="Atacar agachado";column.add_child(crouched);crouched.toggled.connect(func(value):actor.action_crouch=1.0 if value else 0.0)
  var left_punch:=CheckButton.new();left_punch.text="Puñetazo izquierdo";column.add_child(left_punch);left_punch.toggled.connect(func(value):actor.punch_side=0 if value else 1)
  var height_label:=Label.new();height_label.text="Altura de contacto (m)";column.add_child(height_label)
  height_control=HSlider.new();height_control.min_value=.05;height_control.max_value=1.6;height_control.step=.01;height_control.value=contact_height;column.add_child(height_control);height_control.value_changed.connect(func(value):contact_height=value)
  var distance_label:=Label.new();distance_label.text="Distancia de contacto (m)";column.add_child(distance_label)
  distance_control=HSlider.new();distance_control.min_value=.3;distance_control.max_value=1.3;distance_control.step=.01;distance_control.value=contact_distance;column.add_child(distance_control);distance_control.value_changed.connect(func(value):contact_distance=value)
  states.item_selected.connect(func(index):
   if state_options[index] in [&"pickup",&"pickup_walk"]:height_control.value=.12;distance_control.value=.75
  )
  contact_marker=MeshInstance3D.new()
  var sphere:=SphereMesh.new();sphere.radius=.025;sphere.height=.05;contact_marker.mesh=sphere
  var marker_material:=StandardMaterial3D.new();marker_material.albedo_color=Color("e8bf63");marker_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;contact_marker.material_override=marker_material;add_child(contact_marker)
  var pulse:=Button.new();pulse.text="Previsualizar pulso de parry";column.add_child(pulse);pulse.pressed.connect(func():actor.confirm_parry())
func _process(delta: float) -> void:
 if not paused:elapsed+=delta*speed
 if species==&"young":
  var seconds:float=YoungMotion.seconds(clip)
  var phase:=0.0 if clip==&"reference" else (manual_phase if paused else fposmod(elapsed/seconds,1))
  actor.animate(clip,phase,family!=&"right",0.0 if paused or clip==&"reference" else delta*speed)
 else:
  var phase:=manual_phase if paused else fposmod(elapsed/Clips.duration(clip,family),1)
  actor.family_override=family;actor.aim_contact=Vector3(0,contact_height/actor.scale.y,contact_distance/actor.scale.z)
  contact_marker.position=actor.to_global(actor.aim_contact)
  contact_marker.visible=clip in [&"action",&"draw",&"pickup",&"pickup_walk",&"parry"]
  actor.displayed_item=&"apple" if family==&"food" else (&"botella" if family==&"bottle" else family)
  actor.item_water_ml=500;actor.nock_visible=clip==&"draw"
  var moving:=String(clip).contains("walk") or clip in [&"run",&"start",&"stop",&"start_run",&"stop_run"]
  actor.animate(clip,phase,family==&"axe",(0.0 if paused else delta*speed),fposmod(elapsed/Clips.duration(&"run" if String(clip).contains("run") else (&"crouch_walk" if String(clip).contains("crouch") else &"walk")),1),Vector3.BACK if moving else Vector3.ZERO)
 var distance:=1.9 if species==&"young" else 3.2
 camera.position=Vector3(sin(orbit)*distance,0.8 if species==&"young" else 1.35,cos(orbit)*distance);camera.look_at(Vector3(0,0.48 if species==&"young" else 0.95,0))
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:orbiting=event.pressed
 if event is InputEventMouseMotion and orbiting:orbit-=event.relative.x*0.01
