extends SceneTree
const Clips=preload('res://scripts/prototype_3d/survivor_animation.gd')
const Response=preload('res://scripts/prototype_3d/movement_response.gd')
const Source=preload('res://tools/animation/characters/motion_source.gd')
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _initialize():call_deferred('run')
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor);actor.family_override=&''
 var native=actor.native
 var directions=[Vector3.BACK,Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT,Vector3(.574,0,.819),Vector3(-.574,0,.819),Vector3(.574,0,-.819),Vector3(-.574,0,-.819)]
 for direction in directions:
  var previous_distance:float=2*7.8*(1.75/64)/.22*Clips.Gait.backward_stride(direction)
  var distance:float=Clips.cycle_distance(1,0,direction)
  require(absf(distance/previous_distance-1.10)<.000001,'Every running direction travels ten percent farther per cycle')
  require(absf(previous_distance/distance-1.0/1.10)<.000001,'The longer cycle slows cadence by the reciprocal amount, preserving speed')
 require(absf(Response.SPRINT_MULTIPLIER*2-4.48)<.000001,'Forward sprint speed stays at 4.48 metres per second')
 var animation:Animation=Clips.Controls.LIBRARY.get_animation(&'run')
 var keys:=0
 for track in animation.get_track_count():keys+=animation.track_get_key_count(track)
 require(keys<601*animation.get_track_count()*.2,'The longer running clip keeps fewer than twenty percent of dense authoring keys')
 for frame in 1201:
  var phase:float=(frame+.37)/1202.0
  var expected:=Source.sample(&'run',phase);var actual:=Clips.Controls.sample(&'run',phase)
  for control in expected:
   var angular:bool=control not in [&'foot_l',&'foot_r',&'body']
   require(expected[control].distance_to(actual[control])<(.00065 if angular else .022),'Reduced running keys preserve the positional and angular error budgets')
 for fps in [30,60,120]:
  for direction in directions:
   actor.displayed_pose.clear();actor.gait_active=false;actor.gait_direction.reset();actor.sprint_weight=-1
   var speed:float=4.48*Clips.Gait.backward_speed(direction)
   var distance:float=Clips.cycle_distance(1,0,direction)
   var support:float=Clips.Gait.RUN_SUPPORT*Clips.directional_stride(direction)*lerpf(1,Clips.LATERAL_STEP_SCALE,smoothstep(sqrt(.5),1,absf(direction.x)))
   var previous:=Vector3.ZERO;var drift:=0.0;var count:=0
   for frame in fps*2:
    var phase:=fposmod(frame*speed/distance/fps,1)
    actor.animate(&'run',phase,false,1.0/fps,phase,direction)
    var foot:Vector3=native.posed[native.legs[0].ids[2]].origin*(1.75/64)+direction*frame*speed/fps
    var prior_phase:=fposmod((frame-1)*speed/distance/fps,1)
    if frame>fps/2 and phase>.01 and phase<support-.01 and prior_phase>.01 and prior_phase<phase:
     drift+=Vector2(foot.x-previous.x,foot.z-previous.z).length()*fps;count+=1
    previous=foot
   if (support-.02)*distance/speed>2.0/fps:require(count>0,'Every sufficiently long support interval has measured ground contacts')
   require(drift/maxi(count,1)<.15,'The visible running foot stays planted at the unchanged physical speed')
 # All native limbs and the body use one continuous distance-based clock.
 # Interrupt startup, full sprint and deceleration, then resume walking/running.
 for stop_time in [.08,.55,1.3]:
  actor.displayed_pose.clear();actor.gait_active=false;actor.gait_direction.reset()
  actor.sprint_weight=0;actor.animate(&'idle',0,false)
  var envelope:=Response.new();var phase:=0.0
  var previous:Array[Transform3D]=native.posed.duplicate()
  for frame in 360:
   var time:=frame/120.0
   var sprint:bool=time<stop_time or time>2.0
   var moving:bool=time<stop_time or time>1.6
   envelope.advance(Vector2.UP if moving else Vector2.ZERO,sprint,0,1.0/120)
   phase=fposmod(phase+2*envelope.speed*Clips.gait_playback_rate(envelope.sprint_weight)/Clips.cycle_distance(envelope.sprint_weight)/120,1)
   actor.sprint_weight=envelope.sprint_weight
   var state:StringName=&'start_run' if envelope.stage==&'start' else (&'run' if envelope.stage==&'maximum' else (&'stop_run' if envelope.stage==&'brake' and envelope.speed>.001 else (&'walk' if moving else &'idle')))
   actor.animate(state,phase if state in [&'walk',&'run'] else envelope.phase(),false,1.0/120,phase,Vector3.BACK,clampf(envelope.speed,0,1))
   for side in 2:
    for bone in native.legs[side].ids+native.arms[side].ids:
     require(native.posed[bone].origin.distance_to(previous[bone].origin)<3.2,'Native transition %.2f at %.3f %s bone %s distance %.3f'%[stop_time,time,state,native.skeleton.get_bone_name(bone),native.posed[bone].origin.distance_to(previous[bone].origin)])
     require(native.posed[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(previous[bone].basis.orthonormalized().get_rotation_quaternion())<.7,'The longer gait does not flip a knee, elbow or wrist during transitions')
   for bone in native.spine+[native.neck,native.head]:require(native.posed[bone].origin.distance_to(previous[bone].origin)<2,'Spine and head continue smoothly while the shared gait clock changes speed')
   previous=native.posed.duplicate()
 # Follow the same physical steering used by the player, including its
 # short corner stop and full reversal stop, without a second visual filter.
 actor.steering_is_physical=true
 for fps in [30,120]:
  for angle in [35.,90.,180.]:
   actor.displayed_pose.clear();actor.gait_active=false;actor.gait_direction.reset();actor.sprint_weight=1
   actor.animate(&'run',0,false,0,0,Vector3.BACK)
   var previous:Array[Transform3D]=native.posed.duplicate()
   var envelope:=Response.new();envelope.advance(Vector2.UP,true,0,2)
   var phase:=0.0
   for frame in fps*4:
    var target:=Vector2.UP if frame<fps*.8 else Vector2.UP.rotated(deg_to_rad(angle))
    var travel:Vector2=envelope.advance(target,true,0,1.0/fps)
    var direction:=Vector3(travel.x,0,-travel.y).normalized()
    phase=fposmod(phase+2*envelope.speed*Clips.gait_playback_rate(envelope.sprint_weight)/Clips.cycle_distance(envelope.sprint_weight,0,direction)/fps,1)
    actor.sprint_weight=envelope.sprint_weight
    var state:StringName=&'idle' if envelope.stage==&'reverse_hold' else (&'stop_run' if envelope.stage==&'reverse_brake' else (&'start_run' if envelope.stage==&'start' else &'run'))
    actor.animate(state,phase if state==&'run' else envelope.phase(),false,1.0/fps,phase,direction,clampf(envelope.speed,0,1))
    for side in 2:
     for bone in native.legs[side].ids+native.arms[side].ids:
      require(native.posed[bone].origin.distance_to(previous[bone].origin)<3.2*120.0/fps,'The longer gait stays fluid through 35/90/180-degree physical direction changes')
      require(native.posed[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(previous[bone].basis.orthonormalized().get_rotation_quaternion())<.7*120.0/fps,'Physical turns do not introduce native knee or elbow flips')
    previous=native.posed.duplicate()
 actor.free();print('%s: %d longer-stride, reduced-key, planted-foot and full-body transition checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
