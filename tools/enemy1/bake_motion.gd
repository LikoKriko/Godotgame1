extends SceneTree
const Motion=preload("res://scripts/prototype_3d/young_rig_motion.gd")
const BASE="res://assets/enemies/first/rig/"
var motion=Motion.new()
var vertices:PackedVector3Array
var bones:PackedInt32Array
var weights:PackedFloat32Array
var skin:Skin
var probes:Array[int]=[]
func _initialize():call_deferred("run")
func minimum(pose:Array[Transform3D]) -> float:
 var transforms:Array[Transform3D]=[]
 for i in skin.get_bind_count():transforms.append(pose[skin.get_bind_bone(i)]*skin.get_bind_pose(i))
 var low:=INF
 for vertex in probes:
  var point:=Vector3.ZERO
  for slot in 4:point+=(transforms[bones[vertex*4+slot]]*vertices[vertex])*weights[vertex*4+slot]
  low=minf(low,point.y)
 return low
func run():
 var actor=load(BASE+"model.scn").instantiate();root.add_child(actor)
 var rig:Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
 var node:MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0]
 motion.configure(rig);skin=node.skin
 var arrays:Array=node.mesh.surface_get_arrays(0);vertices=arrays[Mesh.ARRAY_VERTEX];bones=arrays[Mesh.ARRAY_BONES];weights=arrays[Mesh.ARRAY_WEIGHTS]
 for i in vertices.size():probes.append(i)
 print("Ground vertices ",probes.size())
 var library:=AnimationLibrary.new();var path:String=String(actor.get_path_to(rig))
 var states:Array[StringName]=Motion.STATES.duplicate();states.push_front(&"reference")
 for state in states:
  for left in ([true,false] if state in [&"attack",&"hook"] else [true]):
   var clip:=Animation.new();clip.length=Motion.seconds(state);clip.loop_mode=Animation.LOOP_LINEAR if state in Motion.LOOP_STATES else Animation.LOOP_NONE
   for i in rig.get_bone_count():
    for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
     var track:=clip.add_track(type);clip.track_set_path(track,NodePath(path+":"+rig.get_bone_name(i)))
   var phases:Array[float]=[]
   for frame in 121:phases.append(frame/120.0)
   if state in [&"walk",&"run",&"boxing_walk"]:
    var support:=.60 if state==&"boxing_walk" else (.55 if state==&"run" else .64)
    for offset in [0.0,.25,.5,.75]:phases.append(fposmod(support-offset,1));phases.append(offset)
   phases.sort()
   if state in [&"walk",&"run",&"boxing_walk"]:
    for frame in 121:motion.sample(state,frame/120.0,left)
   var lowest:=INF;var highest:=0.0
   for phase in phases:
    var pose:Array[Transform3D]=motion.sample(state,phase,left)
    var low:float=minimum(pose) if state!=&"reference" else 0.0
    var correction:=maxf(0,-low+.002) if state!=&"reference" else 0.0
    for i in pose.size():pose[i].origin.y+=correction
    highest=maxf(highest,correction);lowest=minf(lowest,low+correction)
    for i in pose.size():
     var local:Transform3D=pose[motion.parents[i]].affine_inverse()*pose[i] if motion.parents[i]>=0 else pose[i]
     clip.track_insert_key(i*2,phase*clip.length,local.origin)
     clip.track_insert_key(i*2+1,phase*clip.length,local.basis.get_rotation_quaternion())
   var name:StringName=Motion.clip_name(state,left);library.add_animation(name,clip)
   print(name," correction ",highest," floor ",lowest)
 assert(ResourceSaver.save(library,BASE+"motions.res",ResourceSaver.FLAG_COMPRESS)==OK)
 actor.queue_free();await process_frame;quit()
