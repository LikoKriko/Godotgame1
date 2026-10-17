extends SceneTree
## Bake to the supplied 35-bone skeleton; runtime uses ordinary animation tracks.
const Actor=preload("res://scripts/prototype_3d/sprout_model.gd")
var actor
var keys:Dictionary={}
var samples:Dictionary={}
func _initialize():call_deferred("run")
func sample_pose(phase:float) -> Array:
 if samples.has(phase):return samples[phase]
 actor.animate_run(phase)
 var locals:Array[Transform3D]=[]
 for i in actor.bind.size():locals.append(actor.posed[actor.parents[i]].affine_inverse()*actor.posed[i] if actor.parents[i]>=0 else actor.posed[i])
 samples[phase]=locals
 return locals
func refine(a:float,b:float,depth:int=0) -> void:
 var left:Array=sample_pose(a);var right:Array=sample_pose(b);var middle:float=(a+b)*.5
 var exact:Array=sample_pose(middle)
 var blended:Array[Transform3D]=[];var reference:Array[Transform3D]=[]
 var error:=0.0
 for i in actor.bind.size():
  var local:Transform3D=left[i].interpolate_with(right[i],.5)
  blended.append(blended[actor.parents[i]]*local if actor.parents[i]>=0 else local)
  reference.append(reference[actor.parents[i]]*exact[i] if actor.parents[i]>=0 else exact[i])
  error=maxf(error,blended[i].origin.distance_to(reference[i].origin))
 if error>.0002 and depth<8:
  keys[middle]=true;refine(a,middle,depth+1);refine(middle,b,depth+1)
func run() -> void:
 actor=Actor.new();root.add_child(actor)
 var model:Node=actor.get_child(0)
 var clip:=Animation.new();clip.resource_name="Enemy3 run";clip.length=Actor.RUN_CYCLE_SECONDS;clip.loop_mode=Animation.LOOP_LINEAR
 var path:=model.get_path_to(actor.skeleton)
 for i in actor.bind.size():
  var bone_path:=NodePath(String(path)+":"+actor.skeleton.get_bone_name(i))
  for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
   var track:=clip.add_track(type);clip.track_set_path(track,bone_path)
 var phases:Array[float]=[]
 for frame in 241:phases.append(frame/240.0)
 phases.append_array([Actor.RUN_SUPPORT,Actor.RUN_SUPPORT+.5]);phases.sort()
 for phase in phases:keys[phase]=true
 for i in phases.size()-1:refine(phases[i],phases[i+1])
 phases.assign(keys.keys());phases.sort()
 for phase in phases:
  var locals:Array=sample_pose(phase)
  for i in actor.bind.size():
   var local:Transform3D=locals[i]
   clip.track_insert_key(i*2,phase*clip.length,local.origin)
   clip.track_insert_key(i*2+1,phase*clip.length,local.basis.get_rotation_quaternion())
 assert(ResourceSaver.save(clip,"res://assets/enemies/third/sprout/run.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("Run: ",clip.get_track_count()," tracks, ",phases.size()," samples, stride ",Actor.RUN_STRIDE,"; speed ",Actor.RUN_SPEED)
 actor.queue_free();await process_frame;quit()
