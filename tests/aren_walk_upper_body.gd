extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
var errors:Array[String]=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 if not value and message not in errors:errors.append(message);push_error(message)
func span(values:Array[Vector3]) -> Vector3:
 var low:=values[0];var high:=low
 for value in values:low=low.min(value);high=high.max(value)
 return high-low
func skin_points(n:RefCounted,indices:Array[int],arrays:Array) -> Array[Vector3]:
 var matrices:Array[Transform3D]=[]
 for bind in n.mesh.skin.get_bind_count():matrices.append(n.posed[n.mesh.skin.get_bind_bone(bind)]*n.mesh.skin.get_bind_pose(bind))
 var points:Array[Vector3]=[]
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var slots:int=bones.size()/vertices.size();var hip:int=n.binding.bone(&"root")
 for vertex in indices:
  var point:=Vector3.ZERO
  for slot in slots:
   var at:int=vertex*slots+slot
   if weights[at]>0:point+=(matrices[bones[at]]*vertices[vertex])*weights[at]
  points.append((point-n.posed[hip].origin)*(1.75/64.0))
 return points
func advance_contacts(actor:Node3D,seconds:float) -> void:
 var n=actor.native
 for frame in ceili(seconds*120):
  var feet:Array[Vector3]=[];var planted:Array[bool]=[];var rotations:Array[Quaternion]=[]
  var hip:int=n.binding.bone(&"root");var origin:Vector3=n.posed[hip].origin
  for side in 2:
   feet.append(n.posed[n.legs[side].ids[2]].origin*actor.SCALE+Vector3.BACK*actor.distance_m);planted.append(actor.contacts[side].planted)
  for id in [hip]+Array(n.spine):rotations.append(n.posed[id].basis.orthonormalized().get_rotation_quaternion())
  actor.advance_transition(1.0/120)
  for side in 2:
   if planted[side] and actor.contacts[side].planted:
    var foot:Vector3=n.posed[n.legs[side].ids[2]].origin*actor.SCALE+Vector3.BACK*actor.distance_m
    check(foot.distance_to(feet[side])*120<.025,"Planted foot slips during transition")
  check(n.posed[hip].origin.distance_to(origin)*actor.SCALE<.012,"Pelvis jumps during transition")
  var index:=0
  for id in [hip]+Array(n.spine):
   check(rad_to_deg(n.posed[id].basis.orthonormalized().get_rotation_quaternion().angle_to(rotations[index]))<3,"Torso jumps during transition");index+=1
func run() -> void:
 var old=load(ROOT+"aren_coordination_v1/aren.tscn").instantiate();root.add_child(old);old.set_process(false)
 var new=load(ROOT+"aren_walk_upper_v1/aren.tscn").instantiate();root.add_child(new);new.set_process(false)
 for path in new.profile.source_hashes:check(preload("res://tests/aren_branch_cache.gd").source_matches(path,new.profile.source_hashes[path]),"Stale authoring source: "+path)
 var n=new.native;var hip:int=n.binding.bone(&"root")
 var arrays:Array=n.mesh.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:Array[int]=[]
 for vertex in range(0,vertices.size(),4):
  var point:Vector3=n.frame*vertices[vertex]
  if absf(point.x)<8 and point.y>n.rest[n.spine[1]].origin.y and point.y<n.rest[n.neck].origin.y-2:indices.append(vertex)
 check(indices.size()>30,"Missing visible upper torso samples")
 for state in ["normal","cautious","tired"]:
  old.set_style(state);new.set_style(state)
  check(old.library==new.library,"Approved cycle library changed")
  var before:Array=[[],[],[],[],[],[]];var after:Array=[[],[],[],[],[],[]]
  var surface_before:Array=[];var surface_after:Array=[]
  var ids:Array=[hip]+Array(n.spine)+[n.neck,n.head]
  var duration:float=new.sampler.clips.walk.length
  for frame in 120:
   var time:float=frame/120.0*duration
   var a:Dictionary=old.sampler.sample("walk",time);var b:Dictionary=new.sampler.sample("walk",time)
   check(a.feet==b.feet and a.shapes==b.shapes,"Walking contacts or correctives changed")
   for bone in new.sampler.arm_bones:
    check(a.poses[bone].origin.distance_to(b.poses[bone].origin)<.00001 and a.poses[bone].basis.get_rotation_quaternion().angle_to(b.poses[bone].basis.get_rotation_quaternion())<.002,"Contralateral arm gesture changed")
   for name in ["idle","run"]:check(old.sampler.sample(name,time)==new.sampler.sample(name,time),"Nonwalking animation changed")
   old.seek_cycle("walk",time);new.seek_cycle("walk",time)
   for side in 2:
    for id in n.legs[side].ids:check(n.posed[id].origin.distance_to(old.native.posed[id].origin)*new.SCALE<.00001,"Walking leg/foot trajectory changed")
   for i in ids.size():
    before[i].append((old.native.posed[ids[i]].basis*old.native.inverse_rest[ids[i]].basis).orthonormalized().get_euler())
    after[i].append((n.posed[ids[i]].basis*n.inverse_rest[ids[i]].basis).orthonormalized().get_euler())
   if frame%4==0:
    surface_before.append(skin_points(old.native,indices,arrays));surface_after.append(skin_points(n,indices,arrays))
  for i in 6:
   var a:Array[Vector3]=[];a.assign(before[i]);var b:Array[Vector3]=[];b.assign(after[i])
   var old_range:=span(a);var new_range:=span(b)
   var mean:=Vector3.ZERO
   for frame in 120:mean+=b[frame]-a[frame]
   check((mean/120).length()<deg_to_rad(.02),"Approved mean posture changed")
   if i in [1,2,3]:
    check(new_range.x>old_range.x*1.5 and new_range.z>old_range.z*1.4,"Upper torso still lacks distributed motion")
    var covariance:=0.0
    for frame in 120:covariance+=after[0][frame].y*after[i][frame].y
    check(covariance<0,"Spine does not counter-rotate against pelvis")
   if i==3:
    check(new_range.x<deg_to_rad(2.0) and new_range.y<deg_to_rad(9) and new_range.z<deg_to_rad(3.3),"Exaggerated chest motion")
    print("chest_span_deg ",state," = ",new_range*180/PI)
   if i==5:
    var chest:Array[Vector3]=[];chest.assign(after[3]);var chest_range:=span(chest)
    check(new_range.x<chest_range.x*.3 and new_range.y<chest_range.y*.3 and new_range.z<chest_range.z*.3,"Head is not relatively stable")
  var old_motion:=0.0;var new_motion:=0.0;var old_frontal:=0.0;var new_frontal:=0.0;var skin_delta:=0.0
  for vertex in indices.size():
   var a:Array[Vector3]=[];var b:Array[Vector3]=[]
   for frame in surface_before.size():
    a.append(surface_before[frame][vertex]);b.append(surface_after[frame][vertex]);skin_delta=maxf(skin_delta,a[-1].distance_to(b[-1]))
   old_motion+=span(a).length();new_motion+=span(b).length()
   old_frontal+=Vector2(span(a).x,span(a).y).length();new_frontal+=Vector2(span(b).x,span(b).y).length()
  check(new_frontal>old_frontal*1.1 and skin_delta>.002,"New movement does not reach the visible upper torso")
  var start:Dictionary=new.sampler.sample("walk",0);var end:Dictionary=new.sampler.sample("walk",duration-.000001)
  for bone in n.parents.size():check(start.poses[bone].origin.distance_to(end.poses[bone].origin)<.001 and start.poses[bone].basis.get_rotation_quaternion().angle_to(end.poses[bone].basis.get_rotation_quaternion())<.002,"Walking loop seam")
  new.reset_motion()
  for recipe in ["idle_to_walk","walk_to_run","run_to_walk","walk_to_idle","idle_to_run","run_to_idle"]:
   new.request_transition(recipe);advance_contacts(new,new.transition_duration+.2)
  new.reset_motion();new.request_transition("idle_to_run");advance_contacts(new,.55)
  new.request_transition("run_to_walk");advance_contacts(new,.18)
  new.request_transition("walk_to_idle");advance_contacts(new,new.transition_duration+.2)
  print(state," visible_torso_motion_ratio=",new_motion/old_motion," frontal_motion_ratio=",new_frontal/old_frontal," max_visible_pose_delta_m=",skin_delta)
 if errors.is_empty():print("PASS: coordinated whole torso, visible skin, stable head, preserved arms/legs and loops")
 old.free();new.free();quit(0 if errors.is_empty() else 1)
