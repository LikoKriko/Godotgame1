extends Node3D
## Independent F6 sandbox; no game singleton or main-scene changes.
const Patch=preload("res://scripts/animation/terrain/terrain_test_patch.gd")
const Motion=preload("res://scripts/animation/terrain/aren_motion_driver.gd")
var motion=Motion.new()
var response=motion.response
var body:CharacterBody3D
var actor:Node3D
var camera:Camera3D
var label:Label
var yaw:=0.0
var pitch:=-.28
var automated:=false
var test_input:=Vector2.ZERO
var test_run:=false
var elapsed:=0.0
var pose_ms:=0.0

func box(size:Vector3,at:Vector3,angle:float=0.0) -> void:
 var solid:=StaticBody3D.new();solid.position=at;solid.rotation.x=angle;add_child(solid)
 var shape:=BoxShape3D.new();shape.size=size
 var collision:=CollisionShape3D.new();collision.shape=shape;solid.add_child(collision)
 var mesh:=MeshInstance3D.new();var geometry:=BoxMesh.new();geometry.size=size;mesh.mesh=geometry
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.48,.5,.52);mesh.material_override=material;solid.add_child(mesh)

func _ready() -> void:
 box(Vector3(60,.4,100),Vector3(0,-.2,0))
 # A continuous climb, landing and descent, 15 degrees, along -Z.
 var slope:=deg_to_rad(15.0)
 box(Vector3(5,.3,6),Vector3(0,.63,-7),slope)
 box(Vector3(5,.3,3),Vector3(0,1.4,-11.4))
 box(Vector3(5,.3,6),Vector3(0,.63,-15.8),-slope)
 # Shallow irregularities; neighbouring overlapping blocks leave no cracks.
 for i in 12:
  box(Vector3(3,.14,1.05),Vector3(-7,.015+.035*sin(i*1.8),-3-i*.9),deg_to_rad(3*sin(i*1.3)))
 for i in 5:
  box(Vector3(3,.05*(i+1),1.5),Vector3(7,.025*(i+1),-4-i*1.45))
 var road:=Patch.build("IrregularDirtPath",Vector2(6,28),false)
 road.position=Vector3(-17,0,-12);add_child(road)
 var forest:=Patch.build("ForestTerrain",Vector2(12,28),true)
 forest.position=Vector3(19,0,-12);add_child(forest)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-25,0);light.shadow_enabled=true;add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.17,.19,.22)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color(.8,.85,.95);environment.environment.ambient_light_energy=.7;add_child(environment)
 body=CharacterBody3D.new();body.name="ArenController";body.floor_snap_length=.03;body.floor_max_angle=deg_to_rad(42);body.floor_constant_speed=true;add_child(body)
 # A rounded base avoids alternating edge normals on triangulated ground.
 var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.22;capsule.height=1.65;collider.shape=capsule;collider.position.y=.825;body.add_child(collider)
 actor=load("res://scenes/prototype_3d/aren_terrain_actor.tscn").instantiate()
 actor.body=body;body.add_child(actor)
 actor.rotation.y=PI
 response=motion.response
 camera=Camera3D.new();camera.current=true;camera.fov=58;add_child(camera)
 var layer:=CanvasLayer.new();add_child(layer);label=Label.new();label.position=Vector2(16,16);layer.add_child(label)
 body.position=Vector3(0,.1,2)
 update_camera()

func _unhandled_input(event:InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  yaw-=event.relative.x*.004;pitch=clampf(pitch-event.relative.y*.003,-1.1,.15)
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  if event.keycode in [KEY_1,KEY_2,KEY_3]:
   actor.change_style(["normal","cautious","tired"][event.keycode-KEY_1]);motion.requested_gait=""
  if event.keycode in [KEY_4,KEY_5]:
   yaw=0;reset_at(Vector3(-17 if event.keycode==KEY_4 else 19,.1,3))
  if event.keycode==KEY_R:reset_at(Vector3(0,.1,2))

func reset_at(at:Vector3) -> void:
 body.position=at;body.velocity=Vector3.ZERO;motion=Motion.new();response=motion.response
 actor.rotation.y=PI
 actor.turn_rate=0;actor.pivot_weight=0;actor.travel_foot_yaw=0
 actor.turn_bank=0;actor.turn_bank_velocity=0;actor.turn_bank_target=0
 actor.terrain_contacts.clear();actor.pelvis_offset=0;actor.reach_velocity=0;actor.height_initialized=false;actor.previous_speed=0
 actor.style_pose.clear();actor.style_blend=1;actor.grounded=false;actor.measured_speed=0
 actor.reset_motion()

func update_camera() -> void:
 var target:=body.position+Vector3.UP*1.0
 if actor.height_initialized:target.y=actor.body_height+1.0
 camera.position=target+Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Vector3(0,1.0,4.8)
 camera.look_at(target)

func _physics_process(dt:float) -> void:
 elapsed+=dt
 var input:=test_input if automated else Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
 var running:bool=test_run if automated else Input.is_physical_key_pressed(KEY_SHIFT)
 motion.advance(body,actor,input,running,yaw,dt)
 pose_ms=motion.pose_ms
 if body.position.y< -5:reset_at(Vector3(0,.1,2))
 update_camera()
 label.text="Aren · prueba de terreno\nWASD: mover · Mayús: correr · botón derecho + ratón: cámara\n1: normal · 2: cauteloso · 3: cansado · R: reiniciar\n4: camino de tierra · 5: terreno forestal\nCentro: subida / bajada 15° · izquierda: baches · derecha: desniveles 5–25 cm\n%s · %.2f m/s · IK %.1f mm · %.0f FPS · pose %.2f ms" % [actor.style,actor.measured_speed,actor.support_error*1000,Engine.get_frames_per_second(),pose_ms]
