extends Node3D
## User-supplied 25-bone SmartRig. Original hierarchy, skin and bind axes.
const Face=preload("res://scripts/prototype_3d/young_face.gd")
const Motion=preload("res://scripts/prototype_3d/young_rig_motion.gd")
const SOURCE=preload("res://assets/enemies/first/rig/model.scn")
const IMPORTED_SKIN=preload("res://assets/enemies/first/rig/face.res")
const LIBRARY=preload("res://assets/enemies/first/rig/motions.res")
var skeleton:Skeleton3D
var mesh_node:MeshInstance3D
var animation:AnimationPlayer
var rest:Array[Transform3D]=[]
var posed:Array[Transform3D]=[]
var parents:Array[int]=[]
var pose_writer=preload("res://scripts/prototype_3d/skeleton_pose.gd").new()
var body_material:StandardMaterial3D
var last_pose:Dictionary={}
var previous_state:StringName=&"reference"
var interruption_pose:Dictionary={}
var facial_open:=0.0
var expression_time:=NAN
var expression_weights:=PackedFloat32Array()
var facial_elapsed:=Face.SECONDS
var facial_state:StringName=&"reference"
var facial_phase:=0.0
var facial_close_time:=0.0
var facial_close_weights:=PackedFloat32Array()
var head_bone:=0
var fist_bones:Array[int]=[]
var nose_local:=Vector3.ZERO
func _ready() -> void:
 var model:=SOURCE.instantiate();add_child(model)
 skeleton=model.find_children("*","Skeleton3D",true,false)[0]
 mesh_node=model.find_children("*","MeshInstance3D",true,false)[0]
 mesh_node.mesh=IMPORTED_SKIN
 mesh_node.custom_aabb=AABB(Vector3(-1.8,-.2,-1.8),Vector3(3.6,2.8,4.0))
 body_material=IMPORTED_SKIN.surface_get_material(0)
 for i in skeleton.get_bone_count():rest.append(skeleton.get_bone_global_pose(i));posed.append(rest[i]);parents.append(skeleton.get_bone_parent(i))
 head_bone=skeleton.find_bone("Bone_016")
 fist_bones=[skeleton.find_bone("Bone_017"),skeleton.find_bone("Bone_021")]
 nose_local=rest[head_bone].affine_inverse()*Motion.NOSE
 pose_writer.configure(parents)
 animation=AnimationPlayer.new();add_child(animation);animation.root_node=animation.get_path_to(model);animation.add_animation_library(&"",LIBRARY)
func socket(label:StringName) -> Vector3:
 if label==&"snout":return posed[head_bone]*nose_local
 if label==&"head":return posed[head_bone].origin
 if label==&"left_fist":return posed[fist_bones[0]].origin
 if label==&"right_fist":return posed[fist_bones[1]].origin
 return posed[0].origin
func sample_fist(state:StringName,phase:float,left:bool) -> Vector3:
 # Predict a parry contact from the shared native clip without moving the actor.
 var clip:Animation=LIBRARY.get_animation(Motion.clip_name(state,left))
 var time:=clampf(phase,0,1)*clip.length
 var frames:Array[Transform3D]=[]
 for i in parents.size():
  var local:=Transform3D(Basis(clip.rotation_track_interpolate(i*2+1,time)),clip.position_track_interpolate(i*2,time))
  frames.append(frames[parents[i]]*local if parents[i]>=0 else local)
 return frames[fist_bones[0 if left else 1]].origin
func animate(state:StringName,phase:float,left:bool=true,delta:float=0.0) -> void:
 var name:=Motion.clip_name(state,left)
 var changed:bool=last_pose.get("state",&"reference")!=state or last_pose.get("left",true)!=left
 if changed and delta>0:
  var locals:Array[Transform3D]=[]
  for i in parents.size():locals.append(skeleton.get_bone_pose(i))
  interruption_pose={"locals":locals,"elapsed":0.0,"seconds":.14 if state in [&"attack",&"hook"] else .22}
 elif delta<=0:interruption_pose.clear()
 if animation.current_animation!=name:animation.play(name);animation.pause()
 animation.seek(clampf(phase,0,1)*Motion.seconds(state),true)
 if not interruption_pose.is_empty():
  interruption_pose.elapsed=minf(interruption_pose.seconds,interruption_pose.elapsed+delta)
  var blend:=smoothstep(0,interruption_pose.seconds,interruption_pose.elapsed)
  for i in parents.size():skeleton.set_bone_pose(i,interruption_pose.locals[i].interpolate_with(skeleton.get_bone_pose(i),blend))
  if blend>=1:interruption_pose.clear()
 for i in parents.size():posed[i]=posed[parents[i]]*skeleton.get_bone_pose(i) if parents[i]>=0 else skeleton.get_bone_pose(i)
 last_pose={"state":state,"phase":phase,"left":left,"bones":posed};previous_state=state
 advance_face(state,phase,delta)
func apply_pose(pose:Dictionary,delta:float=0.0) -> void:
 if pose.has("bones"):
  posed.assign(pose.bones);pose_writer.apply(skeleton,posed);last_pose=pose
  advance_face(pose.state,pose.phase,delta)
 else:animate(pose.state,pose.phase,pose.get("left",true),delta)
func advance_face(state:StringName,phase:float,delta:float) -> void:
 var attacking:bool=state in [&"attack",&"hook"]
 if delta<=0:
  facial_elapsed=phase*Face.SECONDS if attacking else Face.SECONDS;facial_close_time=0
 else:
  var begins:bool=attacking and (facial_state!=state or phase<facial_phase)
  if begins and facial_elapsed>=Face.SECONDS:facial_elapsed=0
  facial_elapsed=minf(Face.SECONDS,facial_elapsed+delta)
  if state in [&"death",&"corpse",&"stun_fall",&"stun_hold"] and facial_elapsed<Face.SECONDS:
   facial_close_weights=Face.weights(facial_elapsed);facial_close_time=.16;facial_elapsed=Face.SECONDS
 facial_state=state;facial_phase=phase;set_facial_time(facial_elapsed)
 if facial_close_time>0:
  facial_close_time=maxf(0,facial_close_time-delta);var closing:=smoothstep(0,.16,facial_close_time)
  for control in 5:mesh_node.set_blend_shape_value(control,facial_close_weights[control]*closing)
  facial_open=facial_close_weights[0]*Face.CONTROL_SCALE*closing
func set_facial_time(seconds:float) -> void:
 facial_elapsed=clampf(seconds,0,Face.SECONDS)
 if expression_time!=facial_elapsed:expression_weights=Face.weights(facial_elapsed);expression_time=facial_elapsed
 facial_open=expression_weights[0]*Face.CONTROL_SCALE
 for control in 5:mesh_node.set_blend_shape_value(control,expression_weights[control])
