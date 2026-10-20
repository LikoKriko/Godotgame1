extends "res://scripts/animation/authoring/aren_playback.gd"
## Opt-in straight-line transition player; approved cycle resources are read-only.
const Native=preload("res://scripts/animation/characters/native_survivor.gd")
const Sampler=preload("res://scripts/animation/authoring/aren_cycle_sampler.gd")
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
const Solver=preload("res://scripts/continuous_body_pose.gd")
const SCALE=1.75/64.0
@export_file("*.json") var transition_profile:String
var profile:Dictionary={}
var controls:AnimationLibrary
var style:="normal"
var native=Native.new()
var sampler=Sampler.new()
var sampled_scales:Array[Vector3]=[]
var sampled_feet:Array[Transform3D]=[]
var phase:=0.0
var clock:=0.0
var distance_m:=0.0
var acceleration:=0.0
var recipe:=""
var transition_time:=0.0
var transition_duration:=1.0
var start_speed:=0.0
var end_speed:=0.0
var start_acceleration:=0.0
var lean:=0.0
var lean_velocity:=0.0
var lateral:=0.0
var lateral_velocity:=0.0
var contacts:Array[Dictionary]=[]
var max_ik_error_m:=0.0
var pelvis_lowering:=0.0
var loading:=0.0
var loading_velocity:=0.0
var loading_hold:=0.0
func _ready() -> void:
 var skin:=use_approved_skin;use_approved_skin=false
 super._ready();use_approved_skin=skin;tree.active=false
 native.configure(self,get_node(model_path))
 profile=JSON.parse_string(FileAccess.get_file_as_string(transition_profile))
 controls=load(profile.controls)
 set_style("normal")
func set_style(value:String) -> void:
 if not profile.styles.has(value):return
 style=value
 var packed:PackedScene=load(profile.styles[style].scene)
 var source:Node3D=packed.instantiate();library=source.library;source.free()
 player.remove_animation_library(&"aren");player.add_animation_library(&"aren",library)
 sampler.configure(library,native.skeleton);sampled_scales.resize(native.parents.size())
 reset_motion()
func speed_for(gait:String) -> float:
 return 0.0 if gait=="idle" else float(library.get_animation(StringName(gait)).get_meta("cycle").speed_mps)
func reset_motion(gait:String="idle",at_phase:float=0.0) -> void:
 tree.active=false;player.stop();recipe="";phase=at_phase;clock=0;distance_m=0
 current_speed=speed_for(gait);target_speed=current_speed;acceleration=0;lean=0;lean_velocity=0;lateral=0;lateral_velocity=0;max_ik_error_m=0;pelvis_lowering=0;loading=0;loading_velocity=0;loading_hold=0
 contacts.clear()
 render_pose(0)
 for side in 2:
  var id:int=native.legs[side].ids[2]
  contacts.append({"planted":gait=="idle" or fposmod(phase+side*.5,1)<support_fraction(),"anchor":native.posed[id].origin*SCALE,"offset":Vector3.ZERO,"release":phase+side*.5,"basis":native.posed[id].basis,"nominal":native.posed[id].origin*SCALE})
 render_pose(0)
func request_transition(name:String) -> void:
 if not profile.recipes.has(name):return
 recipe=name;transition_time=0;start_speed=current_speed;start_acceleration=acceleration
 end_speed=speed_for(profile.recipes[name].to)
 target_speed=end_speed
 transition_duration=float(profile.recipes[name].duration)*float(profile.styles[style].timing)
func set_locomotion(speed_mps:float) -> void:
 if not is_finite(speed_mps):return
 var goal:="idle" if speed_mps<.01 else ("walk" if speed_mps<=speed_for("walk") else "run")
 if is_equal_approx(speed_for(goal),target_speed):return
 var origin:="idle" if current_speed<.01 else ("walk" if current_speed<=speed_for("walk") else "run")
 if origin!=goal:request_transition(origin+"_to_"+goal)
func _process(delta:float) -> void:advance_transition(delta)
func advance_transition(delta:float) -> void:
 # Bound the IK/contact clock independently of editor FPS or preview speed.
 var remaining:float=clampf(delta,0,1)
 while remaining>0.0000001:
  var step:float=minf(remaining,1.0/120);remaining-=step;tick(step)
func tick(dt:float) -> void:
 var previous_speed:=current_speed
 if not recipe.is_empty():loading_hold=.8
 else:loading_hold=maxf(0,loading_hold-dt)
 var loading_goal:float=profile.get("loading_m",.028) if loading_hold>0 else 0.0
 var load_spring:=spring(loading,loading_velocity,loading_goal,dt,20)
 loading=load_spring.x;loading_velocity=load_spring.y
 var prepare:=0.0
 if not recipe.is_empty():
  transition_time=minf(transition_time+dt,transition_duration)
  var u:=transition_time/transition_duration
  var control:Animation=controls.get_animation(StringName(recipe))
  var progress:float=control.value_track_interpolate(0,u)
  prepare=control.value_track_interpolate(1,u)
  # Inertial tangent preserves velocity/acceleration when interrupted mid-step.
  var tangent:float=start_acceleration*transition_duration*u*pow(1-u,3)
  current_speed=maxf(0,lerpf(start_speed,end_speed,progress)+tangent)
  acceleration=(current_speed-previous_speed)/dt
  if u>=1:current_speed=end_speed;acceleration=0;recipe=""
 else:acceleration=0
 distance_m+=(previous_speed+current_speed)*.5*dt
 clock+=dt
 var mix:=gait_blend();blend=mix
 if current_speed>.000001:
  var walking:Dictionary=library.get_animation(&"walk").get_meta("cycle")
  var running:Dictionary=library.get_animation(&"run").get_meta("cycle")
  var distance:float=walking.distance_m*mix if mix<=1 else lerpf(walking.distance_m,running.distance_m,mix-1)
  phase+=current_speed/maxf(distance,.000001)*dt
 var stance_side:=0 if fposmod(phase,1)<.5 else 1
 var sway:float=prepare*float(profile.styles[style].weight_shift_m)*(-1 if stance_side==0 else 1)
 var desired:float=clampf(acceleration*.014,-.065,.070)+prepare*.025
 # Exact critically damped springs keep pelvis/spine continuous on interruptions.
 var a:=spring(lean,lean_velocity,desired,dt,12);lean=a.x;lean_velocity=a.y
 var b:=spring(lateral,lateral_velocity,sway,dt,12);lateral=b.x;lateral_velocity=b.y
 render_pose(prepare)
func gait_blend() -> float:
 var walking:=speed_for("walk");var running:=speed_for("run")
 return clampf(current_speed/walking,0,1) if current_speed<=walking else 1+clampf((current_speed-walking)/maxf(running-walking,.001),0,1)
func support_fraction() -> float:
 var mix:=gait_blend()
 var walk:float=library.get_animation(&"walk").get_meta("cycle").support
 var run:float=library.get_animation(&"run").get_meta("cycle").support
 return walk if mix<=1 else lerpf(walk,run,mix-1)
static func spring(value:float,velocity:float,goal:float,dt:float,frequency:float) -> Vector2:
 var offset:=value-goal;var temp:float=(velocity+frequency*offset)*dt;var decay:=exp(-frequency*dt)
 return Vector2(goal+(offset+temp)*decay,(velocity-frequency*temp)*decay)
func render_pose(prepare:float) -> void:
 var mix:=gait_blend()
 var a:String="idle" if mix<1 else "walk";var b:String="walk" if mix<1 else "run"
 var weight:float=mix if mix<1 else mix-1
 var first:=sampler.sample(a,clock if a=="idle" else phase*sampler.clips[a].length)
 var second:=sampler.sample(b,phase*sampler.clips[b].length)
 sampled_feet.clear()
 for side in 2:sampled_feet.append(native.frame*first.feet[side].interpolate_with(second.feet[side],weight))
 for i in native.parents.size():
  var local:Transform3D=first.poses[i].interpolate_with(second.poses[i],weight)
  sampled_scales[i]=local.basis.get_scale()
  var parent:int=native.parents[i]
  native.local_globals[i]=native.local_globals[parent]*local if parent>=0 else local
  native.posed[i]=native.frame*native.local_globals[i]
 for shape in first.shapes:native.mesh.set_blend_shape_value(native.mesh.find_blend_shape_by_name(shape),lerpf(first.shapes[shape],second.shapes.get(shape,first.shapes[shape]),weight))
 var hip:int=native.binding.bone(&"root")
 var pivot:Vector3=native.posed[hip].origin
 var rotation:=Basis(Vector3.RIGHT,lean*.45)
 var translation:=Vector3(lateral, -absf(lean)*.12, -prepare*.006)/SCALE
 Torso.rotate_branch(native,hip,rotation*native.posed[hip].basis,pivot+translation)
 for i in native.spine.size():
  var id:int=native.spine[i]
  Torso.rotate_branch(native,id,Basis(Vector3.RIGHT,lean*.55*[.25,.35,.4][i])*native.posed[id].basis,native.posed[id].origin)
 Torso.rotate_branch(native,native.neck,Basis(Vector3.RIGHT,-lean*.35)*native.posed[native.neck].basis,native.posed[native.neck].origin)
 if not contacts.is_empty():solve_contacts()
 for i in native.posed.size():native.local_globals[i]=native.inverse_frame*native.posed[i]
 native.writer.apply(native.skeleton,native.local_globals)
func solve_contacts() -> void:
 var goals:Array[Transform3D]=[]
 var support:=support_fraction();var mix:=gait_blend()
 for side in 2:
  var id:int=native.legs[side].ids[2]
  # Blend contacts in global space. Local joint crossfades alone can put a
  # sole below the ground even when both approved source soles are planted.
  var goal:Transform3D=sampled_feet[side]
  var world:Vector3=goal.origin*SCALE+Vector3.BACK*distance_m
  var contact:Dictionary=contacts[side]
  var nominal:=world
  var t:float=fposmod(phase+side*.5,1)
  var planted:=mix<.015 or t<support
  if planted:
   if not contact.planted:
    var progress:float=clampf((phase+side*.5-contact.release)/maxf(1-support,.01),0,1)
    contact.anchor=world+contact.offset*(1-smooth5(progress));contact.basis=goal.basis
   world=contact.anchor;goal.basis=contact.basis
  else:
   if contact.planted:
    # Keep the preceding support error, not a new offset that would cancel
    # the first sample of heel lift and overextend the trailing leg.
    contact.offset=contact.anchor-contact.nominal;contact.release=phase+side*.5
   var progress:float=clampf((phase+side*.5-contact.release)/maxf(1-support,.01),0,1)
   var fade:float=1-smooth5(progress)
   world+=contact.offset*fade
   goal.basis=Transform3D(contact.basis,Vector3.ZERO).interpolate_with(Transform3D(goal.basis,Vector3.ZERO),1-fade).basis
  contact.planted=planted;contact.nominal=nominal
  goal.origin=(world-Vector3.BACK*distance_m)/SCALE;goals.append(goal)
 # Prepare reach during swing too, before a new support becomes planted.
 var lowering:float=loading/SCALE
 for side in 2:
  var leg:Dictionary=native.legs[side];var hip:Vector3=native.posed[leg.ids[0]].origin
  var goal:Vector3=goals[side].origin
  var horizontal:=Vector2(hip.x-goal.x,hip.z-goal.z).length_squared()
  var allowed:float=goal.y+sqrt(maxf(.01,pow(leg.a+leg.b-.08,2)-horizontal))
  lowering=maxf(lowering,hip.y-allowed)
 # Release retained compression gradually, never at the instant of toe-off.
 pelvis_lowering=maxf(lowering,lerpf(pelvis_lowering,lowering,1-exp(-1.0/120/.12)))
 for i in native.posed.size():native.posed[i].origin.y-=pelvis_lowering
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  if not contacts[side].planted:
   var root:Vector3=native.posed[ids[0]].origin
   var delta:Vector3=goals[side].origin-root
   if delta.length()>leg.a+leg.b-.08:
    goals[side].origin=root+delta.normalized()*(leg.a+leg.b-.08)
  var pole:Vector3=native.posed[ids[1]].origin-native.posed[ids[0]].origin
  var solution:=Solver.joint(native.posed[ids[0]].origin,goals[side].origin,leg.a,leg.b,pole)
  native.untwisted_chain(ids,0,solution,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],goals[side].basis,solution.end)
  max_ik_error_m=maxf(max_ik_error_m,solution.end.distance_to(goals[side].origin)*SCALE)
  var cosine:float=clampf((solution.joint-solution.root).normalized().dot((solution.end-solution.joint).normalized()),-1,1)
  native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine))))
static func smooth5(t:float) -> float:return t*t*t*(t*(t*6-15)+10)
