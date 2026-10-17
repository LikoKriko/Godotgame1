extends SceneTree
## Bake the procedural first walk to a normal Godot Animation, usable by AI/tools.
const Actor=preload("res://scripts/prototype_3d/sprout_model.gd")
func _initialize():call_deferred("run")
func run() -> void:
 var actor:=Actor.new();root.add_child(actor)
 var model:Node=actor.get_child(0)
 var walk:=Animation.new();walk.resource_name="Enemy3 walk";walk.length=Actor.CYCLE_SECONDS;walk.loop_mode=Animation.LOOP_LINEAR
 var rest:=Animation.new();rest.length=.001
 var path:=model.get_path_to(actor.skeleton)
 for i in actor.bind.size():
  var bone_path:=NodePath(String(path)+":"+actor.skeleton.get_bone_name(i))
  for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
   var track:=walk.add_track(type);walk.track_set_path(track,bone_path)
   var reset:=rest.add_track(type);rest.track_set_path(reset,bone_path)
   rest.track_insert_key(reset,0,actor.local_bind[i].origin if type==Animation.TYPE_POSITION_3D else actor.local_bind[i].basis.get_rotation_quaternion())
 for frame in 61:
  actor.animate(frame/60.0)
  for i in actor.bind.size():
   var local:Transform3D=actor.posed[actor.parents[i]].affine_inverse()*actor.posed[i] if actor.parents[i]>=0 else actor.posed[i]
   walk.track_insert_key(i*2,frame*walk.length/60,local.origin)
   walk.track_insert_key(i*2+1,frame*walk.length/60,local.basis.get_rotation_quaternion())
 assert(ResourceSaver.save(walk,"res://assets/enemies/third/sprout/walk.res",ResourceSaver.FLAG_COMPRESS)==OK)
 assert(ResourceSaver.save(rest,"res://assets/enemies/third/sprout/rest.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("Walk: ",walk.get_track_count()," tracks, 61 samples, path ",path)
 actor.queue_free();await process_frame;quit()
