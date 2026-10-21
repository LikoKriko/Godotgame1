extends "res://scripts/animation/authoring/aren_review.gd"
## Reuse the four-view review stage, with two simulations and two pose mirrors.
const Driver=preload("res://scripts/animation/terrain/aren_motion_driver.gd")
const Patch=preload("res://scripts/animation/terrain/terrain_test_patch.gd")
var drivers:Array=[]
var bodies:Array[CharacterBody3D]=[]
var mirrors:Array=[]
var patches:Array[Node3D]=[]
var state:="normal"
var running:=false
var turn_angle:=180.0
var gradual:=false
var moving_camera:=false
var irregular:=false
var consecutive:=false
var status:Label
var gait_choice:OptionButton
var state_choice:OptionButton
var angle_choice:OptionButton

func _ready() -> void:
 build_views()
 for pair in 2:
  var mirror:=PoseMirror.new()
  var views:Array[Node3D]=[actors[pair],actors[pair+2]]
  mirror.configure(views);mirrors.append(mirror)
 var bar:=HBoxContainer.new();bar.position=Vector2(12,8);add_child(bar)
 state_choice=OptionButton.new()
 for title in ["Normal","Cauteloso","Cansado"]:state_choice.add_item(title)
 bar.add_child(state_choice)
 state_choice.item_selected.connect(func(index):state=["normal","cautious","tired"][index];restart())
 gait_choice=OptionButton.new()
 for title in ["Caminata","Carrera"]:gait_choice.add_item(title)
 bar.add_child(gait_choice);gait_choice.item_selected.connect(func(index):running=index==1;restart())
 angle_choice=OptionButton.new()
 for title in ["45°","90°","135°","180° · W ↔ S"]:angle_choice.add_item(title)
 angle_choice.select(3);bar.add_child(angle_choice)
 angle_choice.item_selected.connect(func(index):turn_angle=[45.0,90.0,135.0,180.0][index];restart())
 for item in [["Suave", "gradual"],["Cámara en movimiento","moving_camera"],["Suelo irregular","irregular"]]:
  var toggle:=CheckButton.new();toggle.text=item[0];bar.add_child(toggle)
  var property:String=item[1]
  toggle.toggled.connect(func(value):set(property,value);restart())
 var pause:=Button.new();pause.text="Pausa";bar.add_child(pause);pause.pressed.connect(func():playing=not playing)
 var reset:=Button.new();reset.text="Reiniciar";bar.add_child(reset);reset.pressed.connect(restart)
 speed_slider=HSlider.new();speed_slider.min_value=.1;speed_slider.max_value=1;speed_slider.value=1;speed_slider.custom_minimum_size.x=80;bar.add_child(speed_slider)
 status=Label.new();status.position=Vector2(12,37);add_child(status)
 var chain:=CheckButton.new();chain.text="Consecutivos";chain.position=Vector2(1030,33);add_child(chain)
 chain.toggled.connect(func(value):consecutive=value;restart())
 for i in 4:
  var title:=Label.new();title.position=Vector2((i%2)*600+15,80+(i/2)*420)
  title.text=("ANTES" if i%2==0 else "DESPUÉS")+(" · tres cuartos" if i<2 else " · apoyos desde arriba")
  add_child(title)
 get_viewport().size_changed.connect(fit_views);fit_views()
 restart();set_process(false)

func create_actor(world:Node3D) -> Node3D:
 var body:=CharacterBody3D.new();world.add_child(body);bodies.append(body)
 body.floor_snap_length=.03;body.floor_max_angle=deg_to_rad(42);body.floor_constant_speed=true
 var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
 capsule.radius=.22;capsule.height=1.65;collider.shape=capsule;collider.position.y=.825;body.add_child(collider)
 var floor_body:=StaticBody3D.new();world.add_child(floor_body)
 var floor_shape:=CollisionShape3D.new();floor_shape.shape=BoxShape3D.new();floor_shape.shape.size=Vector3(100,.4,100);floor_shape.position.y=-.2;floor_body.add_child(floor_shape)
 var patch:=Patch.build("ReviewIrregular",Vector2(30,40),true);world.add_child(patch);patches.append(patch)
 var actor:Node3D=load("res://scenes/prototype_3d/aren_terrain_actor.tscn").instantiate()
 actor.body=body;body.add_child(actor);actor.set_process(false)
 return actor

func restart() -> void:
 elapsed=0;drivers.clear()
 for i in actors.size():
  var actor=actors[i]
  patches[i].position.y=0 if irregular else -100
  bodies[i].position=Vector3(0,.8 if irregular else .03,2);bodies[i].velocity=Vector3.ZERO
  actor.change_style(state);actor.rotation.y=PI
  actor.turn_rate=0;actor.pivot_weight=0;actor.travel_foot_yaw=0;actor.turn_correction=i%2==1
  actor.turn_bank=0;actor.turn_bank_velocity=0;actor.turn_bank_target=0
  actor.terrain_contacts.clear();actor.pelvis_offset=0;actor.reach_velocity=0;actor.height_initialized=false
  actor.previous_speed=0;actor.pose_speed=0;actor.pose_speed_velocity=0
  actor.style_pose.clear();actor.style_blend=1;actor.grounded=false;actor.measured_speed=0
  actor.reset_motion()
  actor.set_process(false)
  if i<2:drivers.append(Driver.new(i==1))

func point_camera(index:int) -> void:
 var angle:float=PI/4+(sin(elapsed*.45)*.8 if moving_camera else 0.0)
 var target:=actors[index].global_position+Vector3(0,.8,0)
 grounds[index].position=Vector3(floorf(target.x),0,floorf(target.z))
 var camera=cameras[index]
 camera.position=target+(Vector3(sin(angle)*4,.3,cos(angle)*4) if index<2 else Vector3(0,4,1.5))
 camera.look_at(target)

func advance_review(dt:float) -> void:
 elapsed+=dt
 var progress:float=smoothstep(3,4.5,elapsed) if gradual else (1.0 if elapsed>=3 else 0.0)
 var input:=Vector2(0,-1).rotated(-deg_to_rad(turn_angle)*progress)
 if consecutive and elapsed>=3:
  var leg:=floori((elapsed-3)/.85)
  var from:float=[0.0,turn_angle,-turn_angle,180.0][leg%4]
  var to:float=[turn_angle,-turn_angle,180.0,0.0][leg%4]
  var blend:float=smoothstep(0,.45,fposmod(elapsed-3,.85)) if gradual else 1.0
  input=Vector2(0,-1).rotated(-deg_to_rad(from+wrapf(to-from,-180,180)*blend))
 if elapsed>=7:input=Vector2.ZERO
 var yaw:float=sin(elapsed*.45)*.8 if moving_camera else 0.0
 for i in 2:drivers[i].advance(bodies[i],actors[i],input,running,yaw,dt)
 for i in 2:
  mirrors[i].copy_pose()
  bodies[i+2].global_transform=bodies[i].global_transform
  actors[i+2].transform=actors[i].transform
 for i in 4:point_camera(i)
 status.text="Paso 3 · %.1f s · %.0f FPS · velocidad antes %.2f / después %.2f m/s · CPU %.2f / %.2f ms"%[elapsed,Engine.get_frames_per_second(),actors[0].measured_speed,actors[1].measured_speed,drivers[0].pose_ms,drivers[1].pose_ms]

func _physics_process(dt:float) -> void:
 if not playing:return
 advance_review(dt*speed_slider.value)
 if elapsed>=9:restart()
