extends SceneTree
const Clips=preload('res://scripts/prototype_3d/survivor_animation.gd')
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _initialize():call_deferred('run')
func unleaned(actor,bone:int,share:float=1.0) -> Basis:
 var n=actor.native
 var pelvis:Basis=actor.last_pose.pelvis.basis
 var lean:float=Clips.Gait.WALK_LEAN*n.walk_posture*Clips.Gait.WALK_SPINE_LEAN[2]+Clips.Gait.RUN_LEAN*n.run_posture*Clips.Gait.RUN_SPINE_LEAN[2]
 if bone==n.neck or bone==n.head:lean=Clips.Gait.WALK_LEAN*n.walk_posture+Clips.Gait.RUN_LEAN*n.run_posture
 lean+=Clips.Gait.RUN_BACK_CURVE*n.run_posture+Clips.Gait.CROUCH_BACK_CURVE*n.crouch_posture
 return Basis(pelvis.x.normalized(),-lean*share)*(n.posed[bone].basis*n.inverse_rest[bone].basis)
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 var n=actor.native
 for state in [&'walk',&'run']:
  var scale:=1.0 if state==&'walk' else 2.0
  for phase in [.25,.75]:
   actor.animate(state,phase,false,0,phase,Vector3.BACK)
   var sign:float=1 if phase==.25 else -1
   var yaw:float=unleaned(actor,n.spine[2]).get_euler().y
   require(absf(rad_to_deg(yaw)-sign*(3 if state==&'walk' else 7))<.04,'Visible torso reaches three degrees in walk and seven in run')
   var hip:float=actor.last_pose.pelvis.basis.get_euler().y
   require(hip*sign<0 and absf(rad_to_deg(hip))<.31*scale,'Pelvis counter-rotates gently instead of cancelling or amplifying the chest turn')
   var neck:float=unleaned(actor,n.neck).get_euler().y
   var head:float=unleaned(actor,n.head).get_euler().y
   require(head*sign>0 and neck*sign>head*sign and yaw*sign>neck*sign,'Neck and head follow with a progressively smaller twist')
   require(absf(rad_to_deg(head)-sign*(2.35 if state==&'walk' else 5.15))<.04,'Head adds one degree in walk and two in run while staying below torso amplitude')
   var upper:Transform3D=n.posed[n.spine[2]]*n.inverse_rest[n.spine[2]]
   var lowered:=0
   for side in 2:
    var ids:Array=n.arms[side].ids
    var offset:Vector3=upper.basis.inverse()*(n.posed[ids[1]].origin-n.posed[ids[0]].origin)
    var rest_offset:Vector3=n.rest[ids[1]].origin-n.rest[ids[0]].origin
    if offset.y<rest_offset.y-.1:lowered+=1
   require(lowered==1,'The active shoulder lowers one entire arm while the opposite shoulder balances')
 # Reduced keys retain phase and angular approximation tolerances.
 for frame in 121:
  var phase:=frame/120.0
  var walking:=Clips.Controls.sample(&'walk',phase)
  var running:=Clips.Controls.sample(&'run',phase)
  require(absf(running.chest.y-walking.chest.y*7.0/3.0)<.0012,'Chest curves preserve the requested three-to-seven-degree ratio')
  require(absf(running.pelvis.y-2*walking.pelvis.y)<.0012,'The existing pelvis counter-turn stays separate from the extra spine rotation')
  var walk_twist:float=walking.spine.y+walking.pelvis.y*Clips.Gait.HIP_MOTION*Clips.Gait.HIP_REDUCTION
  var run_twist:float=running.spine.y+running.pelvis.y*Clips.Gait.HIP_MOTION*Clips.Gait.HIP_REDUCTION
  require(absf(run_twist-walk_twist*7.0/3.0)<.0012,'Spine compensation preserves the requested total torso rotation')
  require((running.shoulders-walking.shoulders*2).length()<.0012,'Shoulders retain their existing gentle accompaniment')
 # Sprint startup must interpolate the new amplitudes, even while its
 # selected clip is already run and its physical envelope is still walk.
 for step in 21:
  var weight:=step/20.0;actor.sprint_weight=weight
  actor.animate(&'start_run',.6,false,0,.25,Vector3.BACK)
  var yaw:float=unleaned(actor,n.spine[2]).get_euler().y
  require(absf(rad_to_deg(yaw)-lerpf(3,7,weight))<.05,'Sprint startup interpolates the visible spine amplitude smoothly between three and seven degrees')
  var head:float=unleaned(actor,n.head).get_euler().y
  require(absf(rad_to_deg(head)-lerpf(2.35,5.15,weight))<.06,'Head accompaniment blends smoothly through every intermediate sprint weight')
  for side in 2:
   var ids:Array=n.arms[side].ids
   for segment in 3:
    var a:int=ids[segment];var b:int=ids[segment+1]
    require(absf(n.posed[a].origin.distance_to(n.posed[b].origin)-n.rest[a].origin.distance_to(n.rest[b].origin))<.0001,'Larger twist never stretches clavicles or either arm segment')
 actor.free();print('%s: %d torso amplitude, pelvis counter-turn, neck/head, shoulder, arm and sprint blending checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
