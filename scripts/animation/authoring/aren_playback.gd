extends Node3D
## Opt-in baked locomotion. The approved gameplay controller remains unchanged.
@export var library:AnimationLibrary
@export var model_path:NodePath
@export var use_approved_skin:=false
var player:AnimationPlayer
var tree:AnimationTree
var target_speed:=0.0
var blend:=0.0
var current_speed:=0.0
func _ready() -> void:
 if library==null:
  push_error("Aren playback requires a generated library");set_process(false);return
 if use_approved_skin:prepare_approved_skin(get_node(model_path))
 player=AnimationPlayer.new();player.name="Clips";add_child(player)
 player.add_animation_library(&"aren",library)
 tree=AnimationTree.new();tree.name="Locomotion";add_child(tree);tree.anim_player=tree.get_path_to(player)
 var space:=AnimationNodeBlendSpace1D.new();space.min_space=0;space.max_space=2;space.sync=true
 for i in 3:
  var animation:=AnimationNodeAnimation.new();animation.animation=StringName("aren/"+["idle","walk","run"][i])
  animation.use_custom_timeline=true;animation.timeline_length=library.get_animation(&"idle").length if i==0 else 1.0;animation.stretch_time_scale=true
  space.add_blend_point(animation,float(i))
 var nodes:=AnimationNodeBlendTree.new();nodes.add_node(&"Gait",space);nodes.add_node(&"Cadence",AnimationNodeTimeScale.new());nodes.connect_node(&"Cadence",0,&"Gait");nodes.connect_node(&"output",0,&"Cadence")
 tree.tree_root=nodes;tree.active=true
func set_locomotion(speed_mps:float) -> void:
 target_speed=maxf(0,speed_mps) if is_finite(speed_mps) else 0.0
func _process(delta:float) -> void:
 var walk:float=library.get_animation(&"walk").get_meta("cycle").speed_mps
 var run:float=library.get_animation(&"run").get_meta("cycle").speed_mps
 var target:=clampf(target_speed/walk,0,1) if target_speed<=walk else 1+clampf((target_speed-walk)/maxf(run-walk,.001),0,1)
 blend=move_toward(blend,target,delta*5)
 tree.set("parameters/Gait/blend_position",blend)
 var walking:Dictionary=library.get_animation(&"walk").get_meta("cycle")
 var running:Dictionary=library.get_animation(&"run").get_meta("cycle")
 var rate:float=lerpf(1.0,1.0/walking.duration,blend) if blend<1 else lerpf(1.0/walking.duration,1.0/running.duration,blend-1)
 tree.set("parameters/Cadence/scale",rate)
 current_speed=(walking.distance_m*blend if blend<1 else lerpf(walking.distance_m,running.distance_m,blend-1))*rate
func use_procedural_rollback() -> Node3D:
 # Return an unmodified approved actor; callers retain control of movement.
 var actor=preload("res://scripts/prototype_3d/survivor_model.gd").new()
 actor.scale=Vector3.ONE*(1.75/64.0)
 return actor
static func prepare_approved_skin(model:Node3D) -> void:
 var skeleton:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 var mesh:MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
 var frame:=Transform3D.IDENTITY
 var ancestor:Node3D=skeleton
 while ancestor!=model.get_parent():
  frame=ancestor.transform*frame;ancestor=ancestor.get_parent()
 mesh.mesh=preload("res://scripts/animation/characters/hip_skin.gd").stable_mesh(mesh.mesh,mesh.skin,frame,skeleton.find_bone("smartrig_Hips"))
