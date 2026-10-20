extends SceneTree
## Actual native playback, including foot constraints and interrupted sequences.
const SCENE="res://assets/characters/prototype_3d/generated/aren_transitions_v1/aren.tscn"
var errors:Array[String]=[]
var skin_check:=false
var skin_floor:=INF
var surfaces:Array=[]
var shapes:Array=[]
var stats:Dictionary={"slip_mps":0.0,"pelvis_step_m":0.0,"torso_step_deg":0.0,"foot_step_m":0.0,"max_ik_error_m":0.0}
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 if not value and message not in errors:errors.append(message);push_error(message)
func snapshot(actor:Node3D) -> Dictionary:
 var n=actor.native
 var feet:Array[Vector3]=[];var planted:Array[bool]=[]
 for side in 2:
  feet.append(n.posed[n.legs[side].ids[2]].origin*actor.SCALE+Vector3.BACK*actor.distance_m)
  planted.append(actor.contacts[side].planted)
 var torso:Array[Quaternion]=[]
 for bone in [n.binding.bone(&"root")]+Array(n.spine):torso.append(n.posed[bone].basis.orthonormalized().get_rotation_quaternion())
 return {"feet":feet,"planted":planted,"hips":n.posed[n.binding.bone(&"root")].origin*actor.SCALE,"torso":torso}
func advance(actor:Node3D,seconds:float,dt:float=1.0/120) -> void:
 var before:=snapshot(actor)
 var steps:=ceili(seconds/dt)
 for frame in steps:
  actor.advance_transition(dt)
  var after:=snapshot(actor)
  check(is_finite(actor.current_speed) and actor.current_speed>=0,"Invalid displacement speed")
  for side in 2:
   stats.foot_step_m=maxf(stats.foot_step_m,after.feet[side].distance_to(before.feet[side])/(dt*120))
   if before.planted[side] and after.planted[side]:stats.slip_mps=maxf(stats.slip_mps,after.feet[side].distance_to(before.feet[side])/dt)
  var pelvis_step:float=after.hips.distance_to(before.hips)
  stats.pelvis_step_m=maxf(stats.pelvis_step_m,pelvis_step/(dt*120))
  for i in after.torso.size():stats.torso_step_deg=maxf(stats.torso_step_deg,rad_to_deg(after.torso[i].angle_to(before.torso[i]))/(dt*120))
  for bone in actor.native.posed.size():
   var posed:Transform3D=actor.native.posed[bone]
   check(posed.is_finite(),"Nonfinite native pose")
   var parent:int=actor.native.parents[bone]
   if parent>=0:
    var local:Transform3D=actor.native.local_globals[parent].affine_inverse()*actor.native.local_globals[bone]
    var expected:float=actor.native.binding.locals[bone].origin.length()
    # Wrist scale is an existing authored proportion, not a changed rest length.
    check(absf(local.origin.length()-expected)<.0001,"Native local length changed")
    check(local.basis.get_scale().distance_to(actor.sampled_scales[bone])<.0001,"Authored bone scale changed")
  if skin_check and frame%60==0:skin_floor=minf(skin_floor,measure_floor(actor))
  before=after
 stats.max_ik_error_m=maxf(stats.max_ik_error_m,actor.max_ik_error_m)
func run() -> void:
 var actor:Node3D=load(SCENE).instantiate();root.add_child(actor);actor.set_process(false)
 check(actor.controls.get_animation_list().size()==6,"Missing transition control clips")
 for path in actor.profile.source_hashes:check(FileAccess.get_sha256(path)==actor.profile.source_hashes[path],"Changed transition source: "+path)
 # Do not rewrite historical source hashes in approved cycle resources.
 for state in ["normal","cautious","tired"]:
  actor.set_style(state)
  surfaces.clear();shapes.clear()
  for surface in actor.native.mesh.mesh.get_surface_count():
   surfaces.append(actor.native.mesh.mesh.surface_get_arrays(surface))
   shapes.append(actor.native.mesh.mesh.surface_get_blend_shape_arrays(surface))
  # The read-only sampler must reproduce the approved cycle, not reinterpret it.
  for name in ["idle","walk","run"]:
   var time:float=actor.library.get_animation(StringName(name)).length*.173
   var sampled:Dictionary=actor.sampler.sample(name,time)
   actor.player.play(StringName("aren/"+name));actor.player.seek(time,true)
   for bone in actor.native.parents.size():
    var actual:Transform3D=actor.native.skeleton.get_bone_pose(bone)
    check(actual.origin.distance_to(sampled.poses[bone].origin)<.00001,"Sampler changed approved positions")
    check(actual.basis.get_rotation_quaternion().angle_to(sampled.poses[bone].basis.get_rotation_quaternion())<.002,"Sampler changed approved rotations")
  for name in actor.profile.recipes:
   for initial_phase in [0.0,.37]:
    skin_check=initial_phase==0.0
    actor.reset_motion(actor.profile.recipes[name].from,initial_phase)
    actor.request_transition(name)
    advance(actor,actor.transition_duration+(1.6 if initial_phase==0.0 else .12))
    check(is_equal_approx(actor.current_speed,actor.speed_for(actor.profile.recipes[name].to)),"Wrong endpoint speed: "+state+"/"+name)
    check(actor.recipe.is_empty(),"Transition did not complete")
    if actor.profile.recipes[name].to=="idle" and initial_phase==0.0:
     var idle:Dictionary=actor.sampler.sample("idle",actor.clock)
     var hip:int=actor.native.binding.bone(&"root");var chain:Array[int]=[];var id:=hip
     while id>=0:chain.push_front(id);id=actor.native.parents[id]
     var expected:Transform3D=actor.native.frame
     for bone in chain:expected=expected*idle.poses[bone]
     check(absf(actor.native.posed[hip].origin.y-expected.origin.y)*actor.SCALE<.005,"Pelvis does not settle into approved idle")
  skin_check=false
  # All six links without resets; then abrupt user changes during acceleration.
  actor.reset_motion()
  for name in ["idle_to_walk","walk_to_run","run_to_walk","walk_to_idle","idle_to_run","run_to_idle"]:
   actor.request_transition(name);advance(actor,actor.transition_duration+.2)
  var stopped:float=actor.distance_m;advance(actor,.6)
  check(is_equal_approx(stopped,actor.distance_m),"Stopped actor keeps moving")
  actor.request_transition("idle_to_run");advance(actor,.55)
  actor.request_transition("run_to_walk");advance(actor,.18)
  actor.request_transition("walk_to_idle");advance(actor,actor.transition_duration+.2)
  print("PASS: six transitions, chained and interrupted, state=",state)
 actor.set_style("normal")
 var reference_distance:=0.0
 for dt in [1.0/120,1.0/30]:
  actor.reset_motion()
  for item in [["idle_to_walk",1.4],["walk_to_run",1.4],["run_to_walk",1.4],["walk_to_idle",1.4],["idle_to_run",2.2],["run_to_idle",2.2]]:
   actor.request_transition(item[0]);advance(actor,item[1],dt)
  if reference_distance==0:reference_distance=actor.distance_m
  else:check(absf(actor.distance_m-reference_distance)<.002,"Frame rate changes transition displacement")
 check(stats.slip_mps<.025,"Planted foot sliding exceeds 2.5 cm/s")
 check(stats.max_ik_error_m<.001,"Unreachable contact")
 check(stats.pelvis_step_m<.012,"Abrupt pelvis displacement")
 check(stats.torso_step_deg<3,"Abrupt pelvis/spine rotation")
 check(stats.foot_step_m<.15,"Foot position discontinuity")
 check(skin_floor>=-.004,"Deformed skin penetrates the floor by more than 4 mm")
 print("skin_floor_m=",skin_floor);print(JSON.stringify(stats));actor.free()
 if errors.is_empty():print("PASS: native transition poses, lengths, six endpoints, foot locks, chaining and interruptions")
 quit(0 if errors.is_empty() else 1)

func measure_floor(actor:Node3D) -> float:
 var native=actor.native
 var matrices:Array[Transform3D]=[]
 for bind in native.mesh.skin.get_bind_count():matrices.append(native.posed[native.mesh.skin.get_bind_bone(bind)]*native.mesh.skin.get_bind_pose(bind))
 var minimum:=INF
 for surface in surfaces.size():
  var arrays:Array=surfaces[surface];var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=ids.size()/vertices.size()
  for vertex in vertices.size():
   var source:Vector3=vertices[vertex]
   for shape in shapes[surface].size():source+=(shapes[surface][shape][Mesh.ARRAY_VERTEX][vertex]-vertices[vertex])*native.mesh.get_blend_shape_value(shape)
   var point:=Vector3.ZERO
   for slot in slots:
    var offset:int=vertex*slots+slot
    if weights[offset]>0:point+=(matrices[ids[offset]]*source)*weights[offset]
   minimum=minf(minimum,point.y*actor.SCALE)
 return minimum
