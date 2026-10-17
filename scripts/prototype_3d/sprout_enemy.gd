extends CharacterBody3D
## Temporary enemy3 behaviour: a grounded twenty-metre shuttle, using its own rig.
const Visual=preload("res://scripts/prototype_3d/sprout_model.gd")
const HEIGHT:=.9
const SOURCE_HEIGHT:=1.9013426
const MODEL_SCALE:=HEIGHT/SOURCE_HEIGHT
const SPEED:=Visual.SPEED*MODEL_SCALE
const RUN_SPEED:=SPEED*10.0
const RunCycle=preload("res://scripts/prototype_3d/sprout_run_cycle.gd")
var game
var model:Node3D
var animation:AnimationPlayer
var patrol=preload("res://scripts/prototype_3d/sprout_patrol.gd").new()
var phase:=0.0
var run_phase:=0.0
var run_preview_enabled:=true
var run_cycle=RunCycle.new()
var rig:Skeleton3D
var pose_from:Array[Transform3D]=[]
var blend_elapsed:=.18
func configure(owner_game,direction:Vector3=Vector3(0,0,1)) -> void:
 game=owner_game;add_to_group("prototype_sprouts")
 collision_layer=8;collision_mask=43;floor_snap_length=.15
 model=preload("res://scenes/prototype_3d/enemy3.tscn").instantiate();add_child(model);model.scale=Vector3.ONE*MODEL_SCALE
 model.find_children("*","MeshInstance3D",true,false)[0].custom_aabb=Visual.VISUAL_BOUNDS
 rig=model.find_children("*","Skeleton3D",true,false)[0]
 animation=model.get_node("AnimationPlayer");animation.play("walk");animation.pause()
 var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.19;capsule.height=HEIGHT
 collision.shape=capsule;collision.position.y=HEIGHT*.5;add_child(collision)
 patrol.configure(global_position,direction);model.rotation.y=patrol.heading
 show_pose(false)
func show_pose(still:bool,running:bool=false,delta:float=0.0) -> void:
 var clip:StringName=&"RESET" if still else (&"run" if running else &"walk")
 if animation.current_animation!=clip:
  pose_from.clear()
  if delta>0:
   for i in rig.get_bone_count():pose_from.append(rig.get_bone_pose(i))
  blend_elapsed=0.0 if not pose_from.is_empty() else .18
  animation.play(clip);animation.pause()
 animation.seek(0.0 if still else (run_phase*Visual.RUN_CYCLE_SECONDS if running else phase*Visual.CYCLE_SECONDS),true)
 if not pose_from.is_empty():
  blend_elapsed=minf(.18,blend_elapsed+maxf(0,delta))
  var weight:=smoothstep(0,.18,blend_elapsed)
  for i in rig.get_bone_count():rig.set_bone_pose(i,pose_from[i].interpolate_with(rig.get_bone_pose(i),weight))
  if blend_elapsed>=.18:pose_from.clear()
func _physics_process(delta:float) -> void:
 if game==null or game.paused:return
 var timing:Dictionary=run_cycle.advance(delta) if run_preview_enabled else {"run_seconds":0.0,"walk_seconds":delta}
 var running:bool=run_preview_enabled and run_cycle.running()
 var resting:bool=run_preview_enabled and run_cycle.resting()
 var requested_distance:float=SPEED*timing.walk_seconds+RUN_SPEED*timing.run_seconds
 var turning:bool=patrol.turning
 var direction:=Vector3.ZERO
 if turning:patrol.turn(delta)
 elif patrol.remaining(global_position)<.0001:patrol.begin_turn();turning=true
 elif not resting or requested_distance>0:direction=patrol.direction(global_position)
 model.rotation.y=patrol.heading
 var speed:=minf(requested_distance,patrol.remaining(global_position))/maxf(delta,.00001) if not turning else 0.0
 velocity.x=direction.x*speed;velocity.z=direction.z*speed
 velocity.y=-.1 if is_on_floor() else maxf(-20,velocity.y-20*delta)
 var previous:=global_position;move_and_slide()
 var travelled:=Vector2(global_position.x-previous.x,global_position.z-previous.z).length()
 if timing.run_seconds>0:run_phase=fposmod(run_phase+travelled/(RUN_SPEED*Visual.RUN_CYCLE_SECONDS),1)
 else:phase=fposmod(phase+travelled/(SPEED*Visual.CYCLE_SECONDS),1)
 show_pose(resting or turning or travelled<.000001,running,delta)
func snapshot() -> Dictionary:
 return {"position":[position.x,position.y,position.z],"phase":phase,"patrol":patrol.snapshot(),"run_phase":run_phase,"run_preview_enabled":run_preview_enabled,"run_cycle":run_cycle.snapshot()}
func restore(data:Dictionary) -> void:
 position=Vector3(data.position[0],data.position[1],data.position[2]);phase=data.phase;patrol.restore(data.patrol)
 run_phase=data.get("run_phase",0.0);run_preview_enabled=data.get("run_preview_enabled",true)
 if data.has("run_cycle"):run_cycle.restore(data.run_cycle)
 pose_from.clear();blend_elapsed=.18
 model.rotation.y=patrol.heading;show_pose(patrol.turning or (run_preview_enabled and run_cycle.resting()),run_preview_enabled and run_cycle.running())
