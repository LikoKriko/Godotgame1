extends SceneTree
const Response=preload("res://scripts/prototype_3d/movement_response.gd")
const Delay=preload("res://scripts/prototype_3d/facing_delay.gd")
const Motion=preload("res://scripts/locomotion.gd")
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func key(code:int,pressed:bool):
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func _initialize():call_deferred("run")
func sample_floor(actor,arrays:Array) -> float:
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var minimum:=INF
 var skin:Skin=actor.mesh_node.skin
 var slots:int=bones.size()/vertices.size()
 for i in range(0,vertices.size(),997):
  var point:=Vector3.ZERO
  for slot in slots:
   var bind:int=bones[slots*i+slot]
   point+=actor.native.posed[skin.get_bind_bone(bind)]*skin.get_bind_pose(bind)*vertices[i]*weights[slots*i+slot]
  minimum=minf(minimum,point.y)
 return minimum
func run():
 require(is_equal_approx(Response.SPRINT_MULTIPLIER,1.6*1.4),"Requested sprint maximum is exactly forty percent faster")
 for fps in [30,60,120]:
  var delayed:=Delay.new();delayed.sample(Vector3.BACK,0)
  for target in [Vector3.RIGHT,Vector3.FORWARD]:
   var previous:=Vector3.BACK if target==Vector3.RIGHT else Vector3.RIGHT
   for frame in int(floor(.15*fps)):require(delayed.sample(target,1.0/fps).distance_to(previous)<.0001,"Every camera change keeps a 0.15-second delay")
   for frame in 2:delayed.sample(target,1.0/fps)
   require(delayed.sample(target,0).distance_to(target)<.0001,"Camera posture follows after 0.15 seconds, within one sampled frame")
  for frame in fps*2:
   var actual:Vector3=delayed.sample(Vector3(float(frame),0,1),1.0/fps)
   if frame>int(ceil(.15*fps))+1:require(actual.distance_to(Vector3(frame-.15*fps,0,1))<.0001,"Continuous camera motion follows exactly 0.15 seconds behind at every frame rate")
  require(delayed.history.size()<=int(ceil(.15*fps))+3,"Continuous turning consumes bounded history rather than waiting for mouse release")
  var response:=Response.new();response.advance(Vector2.UP,true,0,.16)
  require(response.stage==&"maximum" and absf(response.speed-1)<.0001,"Sprint starts with a separate idle-to-walk transition")
  response.advance(Vector2.UP,true,0,.5)
  require(response.speed>1 and response.speed<Response.SPRINT_MULTIPLIER,"Maximum phase accelerates progressively")
  var restored:=Response.new();var encoded:Dictionary=JSON.parse_string(JSON.stringify(response.snapshot()))
  require(Response.valid(encoded),"Saved sprint envelopes accept their JSON round trip")
  restored.restore(encoded);restored.advance(Vector2.UP,true,0,.5)
  response.advance(Vector2.UP,true,0,.5)
  require(absf(restored.speed-response.speed)<.00001 and restored.stage==response.stage,"Loading mid-acceleration resumes the same physical curve")
  require(is_equal_approx(response.speed,Response.SPRINT_MULTIPLIER),"Maximum sprint speed arrives after one full second")
 for interrupt in [.04,.16,.4,1.16,2.0]:
  for target in [0.0,.48,1.0]:
   var response:=Response.new()
   for frame in int(ceil(interrupt*120)):response.advance(Vector2.UP,true,0,1.0/120)
   var before:float=response.speed
   var travel:=Vector2.ZERO if target==0 else Vector2.UP
   response.advance(travel,false,1.0 if target==.48 else 0.0,0)
   require(is_equal_approx(response.speed,before),"Stopping any sprint phase starts from actual speed")
   var previous:float=response.speed
   for frame in 30:
    response.advance(travel,false,1.0 if target==.48 else 0.0,.01)
    require(absf(response.speed-previous)<Response.SPRINT_MULTIPLIER*.07,"Braking never snaps speed")
    previous=response.speed
   require(absf(response.speed-target)<.00001,"Braking reaches idle, walk or crouch-walk")
   response.advance(Vector2.UP,true,0,0)
   require(is_equal_approx(response.speed,previous),"Restarting during braking also preserves current speed")
 var distance:Array[float]=[]
 for scale in [1.0,.6]:
  var slide:=Motion.new();slide.slide(Vector2.UP,scale);var total:=0.0
  for frame in 460:
   total+=slide.velocity(Vector2.ZERO,1).length()*.001;slide.advance(.001,false)
  distance.append(total)
 require(absf(distance[1]/distance[0]-.6)<.0001,"Backward slide travels exactly forty percent less")
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 for family in [&"",&"axe",&"pickaxe",&"sword",&"bow"]:
  actor.family_override=family
  for frame in 65:
   var t:=frame/64.0
   actor.animate(&"slide_back",t,family!=&"",0,.25)
   require(actor.grip_error<.045,"Backward slide preserves the actual grip")
   require(sample_floor(actor,arrays)>-.12,"Backward slide visible skin stays above ground")
   for side in 2:
    var leg:Dictionary=actor.last_pose.legs[side]
    require(absf(leg.root.distance_to(leg.joint)-Anatomy.THIGH)<.001 and absf(leg.joint.distance_to(leg.end)-Anatomy.SHIN)<.001,"Backward sliding keeps knee anatomy")
   actor.animate(&"jump",t,family!=&"")
   require(actor.grip_error<.045,"Jumping keeps weapon and supporting hand attached")
  actor.animate(&"jump",0,family!=&"");var initial:Array[Vector3]=[actor.rig.posed[6].origin,actor.rig.posed[9].origin]
  actor.animate(&"jump",.52,family!=&"")
  for side in 2:require(actor.rig.posed[6+side*3].origin.y>initial[side].y+1.0,"Both free and occupied hands rise with the jump")
  for launch_phase in [.1,.4,.8]:
   actor.animate(&"slide_back",launch_phase,family!=&"",0,.25)
   var feet:Array[Vector3]=[actor.rig.posed[12].origin,actor.rig.posed[15].origin]
   actor.animate(&"slide_jump",0,family!=&"")
   for side in 2:require(actor.rig.posed[12+side*3].origin.distance_to(feet[side])<.001,"Backward slide-jump starts at the actual displayed feet")
 actor.family_override=&""
 for side in 2:
  actor.punch_side=side;actor.aim_contact=Vector3((-1 if side==0 else 1)*6,40,18)
  actor.animate(&"action",.5,false)
  require(actor.last_pose.active==side,"Punch selects the alternating arm")
  require(actor.rig.posed[6+side*3].origin.distance_to(actor.aim_contact)<.03,"Either fist reaches the selected reticle contact")
  require(actor.last_pose.legs[side].end.z>actor.last_pose.legs[1-side].end.z+2,"Striking-side leg advances as support")
  require(absf(actor.last_pose.body.basis.get_euler().y)>.05 and absf(actor.last_pose.pelvis.basis.get_euler().y)>.025,"Torso and pelvis accompany both punches")
 actor.aim_contact=Vector3.INF
 for stop_time in [.08,.55,1.3]:
  var envelope:=Response.new();actor.sprint_weight=0;actor.sprint_crouch=0;actor.animate(&"idle",0,false)
  var previous:Array=actor.rig.posed.duplicate()
  var gait:=0.0
  for frame in 240:
   var sprint:bool=frame/120.0<stop_time
   envelope.advance(Vector2.UP if sprint else Vector2.ZERO,sprint,0,1.0/120)
   gait=fposmod(gait+2*envelope.speed*Clips.gait_playback_rate(envelope.sprint_weight)/Clips.cycle_distance(envelope.sprint_weight)/120,1)
   actor.sprint_weight=envelope.sprint_weight
   var state:StringName=&"start_run" if envelope.stage==&"start" else (&"run" if envelope.stage==&"maximum" else (&"stop_run" if envelope.speed>.001 else &"idle"))
   actor.animate(state,envelope.phase() if state!=&"run" else gait,false,1.0/120,gait,Vector3.BACK,clampf(envelope.speed,0,1))
   for bone in 16:
    var travel_limit:=3.0 if bone in [11,12,14,15] else 2.0
    require(actor.rig.posed[bone].origin.distance_to(previous[bone].origin)<travel_limit,"Interrupted sprint bounds joint travel, including the fast foot return at maximum speed")
    require(actor.rig.posed[bone].basis.get_rotation_quaternion().angle_to(previous[bone].basis.get_rotation_quaternion())<.70,"Interrupted sprint avoids knee or elbow flips")
   previous=actor.rig.posed.duplicate()
 actor.free()
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false);game.settings.values.auto_run=false
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var player=game.player;player.position=Vector3(12,.01,12);player.equipped=false
 for frame in 12:
  player._physics_process(1.0/60);await physics_frame
 key(KEY_W,true);key(KEY_SHIFT,true);await physics_frame
 await process_frame
 for frame in 72:
  player._physics_process(1.0/60);await physics_frame
 require(player.movement_response.stage==&"maximum" and is_equal_approx(player.movement_response.speed,Response.SPRINT_MULTIPLIER),"Live input reaches maximum sprint after startup plus one second")
 key(KEY_SHIFT,false)
 for frame in 16:
  player._physics_process(1.0/60);await physics_frame
 require(absf(player.movement_response.speed-1)<.001 and player.model.last_pose.clip_state==&"walk","Releasing sprint transitions to the walking animation and speed")
 key(KEY_W,false)
 for frame in 16:
  player._physics_process(1.0/60);await physics_frame
 require(player.velocity.length()<.01 and player.model.last_pose.clip_state==&"idle","Releasing movement finishes braking at true rest")
 key(KEY_S,true);key(KEY_SHIFT,true)
 for frame in 10:
  player._physics_process(1.0/60);await physics_frame
 key(KEY_CTRL,true);await physics_frame
 await process_frame
 player._physics_process(1.0/60);await physics_frame
 require(player.locomotion.sliding() and player.slide_backward and player.model.last_pose.clip_state==&"slide_back","Backward input actually selects the new animation")
 require(is_equal_approx(player.locomotion.slide_distance_scale,.6),"Live backward slide uses reduced travel")
 game.environment_content=load("res://scripts/prototype_3d/world_content.gd").new();game.add_child(game.environment_content)
 var saved:Dictionary=preload("res://scripts/prototype_3d/save_game.gd").capture(game)
 require(saved.player.slide_backward and is_equal_approx(saved.player.slide_distance_scale,.6),"Save records backward posture and shortened travel")
 require(preload("res://scripts/prototype_3d/save_game.gd").valid(saved),"New locomotion fields satisfy save validation")
 var legacy:=saved.duplicate(true)
 for field in ["response","slide_backward","slide_side","slide_facing","slide_distance_scale"]:legacy.player.erase(field)
 require(preload("res://scripts/prototype_3d/save_game.gd").valid(legacy),"Older saves remain accepted without the new animation fields")
 for code in [KEY_CTRL,KEY_SHIFT,KEY_S]:key(code,false)
 var Save=preload("res://scripts/prototype_3d/save_game.gd")
 for side in [-1,1]:
  await physics_frame;await process_frame
  player.reset_motion_state();player.control_was_pressed=false;player.position=Vector3(12,.01,12)
  for frame in 12:
   player._physics_process(1.0/60);await physics_frame
  key(KEY_S,true);key(KEY_SHIFT,true);key(KEY_A if side<0 else KEY_D,true)
  for frame in 10:
   player._physics_process(1.0/60);await physics_frame
  key(KEY_CTRL,true);await physics_frame;await process_frame
  player._physics_process(1.0/60);await physics_frame
  var clip:StringName=&"slide_back_left" if side<0 else &"slide_back_right"
  require(player.locomotion.sliding() and player.slide_backward and player.slide_side==side and player.model.last_pose.clip_state==clip,"Live S+A/S+D selects its own backward diagonal animation")
  require(is_equal_approx(player.locomotion.slide_distance_scale,.6),"Both backward diagonals use the shorter travel")
  var diagonal:Dictionary=Save.capture(game)
  require(Save.valid(diagonal),"Backward diagonal save validates")
  var invalid:=diagonal.duplicate(true);invalid.player.slide_side=2
  require(not Save.valid(invalid),"Save rejects an unknown slide side")
  player.slide_side=0
  require(Save.restore(game,diagonal),"Backward diagonal state restores")
  require(player.slide_side==side and player.model.last_pose.clip_state==clip,"Loading restores the correct diagonal pose")
  for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
  for code in [KEY_CTRL,KEY_SHIFT,KEY_S,KEY_A,KEY_D]:key(code,false)
 player.equipped=false;player.equip_elapsed=-1
 player.cancel_action();require(player.strike(),"First empty-hand attack begins")
 var first:int=player.punch_side;player.cancel_action();require(player.strike(),"Second empty-hand attack begins")
 require(player.punch_side==1-first and player.model.punch_side==player.punch_side,"Real attack input alternates both the fist and the model")
 player.cancel_action();game.free()
 print("%s: %d delayed facing, sprint interruption, backward slide, jump and alternate punch checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
