extends SceneTree
## Read-only native pose reference for a same-rig Blender absorption edit.
func _initialize():call_deferred("run")
func row(t:Transform3D,scale:float) -> Array:
 return [[t.basis.x.x,t.basis.x.y,t.basis.x.z],[t.basis.y.x,t.basis.y.y,t.basis.y.z],[t.basis.z.x,t.basis.z.y,t.basis.z.z],[t.origin.x*scale,t.origin.y*scale,t.origin.z*scale]]
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 var directory:String=args[1] if args.size()==2 and args[0]=="--output-dir" else "res://work/landing_absorption_reference"
 DirAccess.make_dir_recursive_absolute(directory)
 var actor=load("res://scenes/prototype_3d/aren_blender_landing_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 for key in ["previous","previous_heavy"]:
  var bones:Array=[];var samples:Array=[]
  for bone in actor.native.parents.size():bones.append({"name":str(actor.native.skeleton.get_bone_name(bone)).replace("smartrig_","smartrig:"),"rest":row(actor.native.rest[bone],actor.SCALE)})
  for frame in 156:
   var pose:Dictionary=actor.pilot_sampler.sample(key,minf(frame/60.0,actor.PilotClip.length-.000001))
   actor.landing.restore(actor,pose.poses)
   var points:Array=[]
   for bone in actor.native.parents.size():points.append(row(actor.native.posed[bone],actor.SCALE))
   samples.append(points)
  var path:String=directory.path_join(key+".json")
  var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"bones":bones,"samples":samples}));file.close()
 actor.free();quit()
