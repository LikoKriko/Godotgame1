extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
var errors:Array[String]=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 if not value and message not in errors:errors.append(message);push_error(message)
func run() -> void:
 var old=load(ROOT+"aren_walk_upper_v1/aren.tscn").instantiate();root.add_child(old);old.set_process(false)
 var new=load(ROOT+"aren_short_run_v1/aren.tscn").instantiate();root.add_child(new);new.set_process(false)
 for path in new.profile.source_hashes:check(preload("res://tests/aren_branch_cache.gd").source_matches(path,new.profile.source_hashes[path]),"Stale source: "+path)
 for state in ["normal","cautious","tired"]:
  old.set_style(state);new.set_style(state)
  var before:Animation=old.library.get_animation(&"run");var after:Animation=new.library.get_animation(&"run")
  var a:Dictionary=before.get_meta("cycle");var b:Dictionary=after.get_meta("cycle")
  check(absf(after.length/before.length-.9)<.000001,"Unexpected cadence")
  check(a.speed_mps==b.speed_mps and absf(b.distance_m/after.length-a.speed_mps)<.000001,"Displacement speed changed")
  check(absf(a.support*before.length-b.support*after.length)<.000001,"Physical support duration changed")
  for name in [&"walk",&"idle"]:
   check(old.library.get_animation(name)==new.library.get_animation(name),"Approved nonrunning clip was copied or replaced")
   check(old.sampler.sample(name,.173)==new.sampler.sample(name,.173),"Approved nonrunning pose changed")
  var splits:=Vector2.ZERO;var fronts:=Vector2.ZERO;var rears:=Vector2.ZERO
  var minimum:=180.0;var maximum:=0.0;var max_slip:=0.0
  var previous:Array[Vector3]=[];var planted:Array[bool]=[]
  for frame in 721:
   var phase:float=frame/720.0
   old.seek_cycle("run",phase*before.length);new.seek_cycle("run",phase*after.length)
   var n=new.native
   var old_feet:Array[Vector3]=[];var feet:Array[Vector3]=[]
   for side in 2:
    var ids:Array=n.legs[side].ids
    var foot:Vector3=n.posed[ids[2]].origin*new.SCALE;feet.append(foot)
    old_feet.append(old.native.posed[ids[2]].origin*old.SCALE)
    var thigh:Vector3=(n.posed[ids[1]].origin-n.posed[ids[0]].origin).normalized();var shin:Vector3=(n.posed[ids[2]].origin-n.posed[ids[1]].origin).normalized()
    var signed_angle:float=rad_to_deg(atan2(Vector3.RIGHT.dot(thigh.cross(shin)),thigh.dot(shin)))
    var flexion:float=rad_to_deg(acos(clampf(thigh.dot(shin),-1,1)))
    minimum=minf(minimum,signed_angle);maximum=maxf(maximum,flexion)
    var support:bool=fposmod(phase+side*.5,1)<b.support
    var world:Vector3=foot+Vector3.BACK*phase*b.distance_m
    if frame>0 and support and planted[side]:max_slip=maxf(max_slip,world.distance_to(previous[side])/(after.length/720))
    if frame==0:previous.append(world);planted.append(support)
    else:previous[side]=world;planted[side]=support
    fronts.x=maxf(fronts.x,old_feet[side].z);fronts.y=maxf(fronts.y,feet[side].z)
    rears.x=maxf(rears.x,-old_feet[side].z);rears.y=maxf(rears.y,-feet[side].z)
   splits.x=maxf(splits.x,absf(old_feet[0].z-old_feet[1].z));splits.y=maxf(splits.y,absf(feet[0].z-feet[1].z))
   for bone in n.spine:
    check(n.posed[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(old.native.posed[bone].basis.orthonormalized().get_rotation_quaternion())<.002,"Approved running torso inclination or gesture changed")
   for bone in n.parents.size():
    var local:Transform3D=n.skeleton.get_bone_pose(bone);var parent:int=n.parents[bone]
    if parent>=0:check(absf(local.origin.length()-n.binding.locals[bone].origin.length())<.0001,"Bone length changed")
    check(local.basis.get_scale().distance_to(old.native.skeleton.get_bone_pose(bone).basis.get_scale())<.0001,"Bone scale changed")
  check(absf(splits.y/splits.x-.8)<.002,"Actual lateral leg split was not reduced by twenty percent")
  check(fronts.y<fronts.x*.9 and rears.y<rears.x*.9,"Airborne reach remains excessive")
  check(minimum>=-.5 and maximum<155,"Anatomically invalid knee")
  check(max_slip<.025,"Steady running stance slides")
  var start:Dictionary=new.sampler.sample("run",0);var end:Dictionary=new.sampler.sample("run",after.length-.000001)
  for bone in new.native.parents.size():check(start.poses[bone].origin.distance_to(end.poses[bone].origin)<.001 and start.poses[bone].basis.get_rotation_quaternion().angle_to(end.poses[bone].basis.get_rotation_quaternion())<.002,"Run loop seam")
  print(state," split_ratio=",splits.y/splits.x," gap_m=",splits.y," knee_range_deg=",minimum,"..",maximum," slip_mps=",max_slip," cadence_spm=",120/after.length)
 old.free();new.free()
 if errors.is_empty():print("PASS: shorter actual leg split, natural knees, same speed/support time, stable torso and preserved walk/idle")
 quit(0 if errors.is_empty() else 1)
