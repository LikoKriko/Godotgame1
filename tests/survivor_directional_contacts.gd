extends SceneTree
const Clips=preload('res://scripts/prototype_3d/survivor_animation.gd')
const Anatomy=preload('res://scripts/prototype_3d/survivor_anatomy.gd')
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<15:push_error(message)
func _initialize():call_deferred('run')
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 var directions:Array[Vector3]=[]
 for x in [-1,0,1]:
  for z in [-1,0,1]:
   if x!=0 or z!=0:directions.append(Vector3(x,0,z).normalized())
 # Signed checks distinguish the support return from the lifted forward swing.
 # Test final rendered bones, with the runtime delta/blending enabled.
 for family in [&'',&'axe',&'bow']:
  actor.family_override=family
  for state in [&'walk',&'run',&'crouch_walk']:
   var weight:=1.0 if state==&'run' else 0.0
   var crouch:=1.0 if state==&'crouch_walk' else 0.0
   actor.sprint_weight=weight;actor.sprint_crouch=crouch
   for fps in [30,60,120]:
    for direction in directions:
     actor.displayed_pose.clear();actor.gait_direction.reset();actor.gait_active=false
     var cycle:=Clips.cycle_distance(weight,crouch,direction)
     var rate:=Clips.gait_playback_rate(weight)
     var dt:float=1.0/fps
     var previous:Array=[]
     for frame in int(ceil(cycle*.5*fps/rate))*3:
      var phase:=fposmod(frame*dt*2.0/cycle*rate,1)
      actor.animate(state,phase,family!=&'',dt,phase,direction)
      var foot:Vector3=actor.rig.posed[12].origin
      if frame*dt>cycle*.5/rate:
       var delta:Vector3=(foot-previous[0])*Anatomy.HEIGHT_METRES/64
       var support:float=Clips.Gait.RUN_SUPPORT*Clips.directional_stride(direction)*lerpf(1,Clips.LATERAL_STEP_SCALE,smoothstep(sqrt(.5),1,absf(direction.x))) if state==&'run' else Clips.Gait.WALK_SUPPORT*Clips.directional_stride(direction)*lerpf(1,Clips.LATERAL_STEP_SCALE,smoothstep(sqrt(.5),1,absf(direction.x)))
       if state==&'crouch_walk':support=.4
       if phase>support*.25 and phase<support*.75:
        var expected_return:=direction*2.0*Clips.GAIT_STRIDE_LENGTH*rate
        if state==&'run':expected_return=direction*2.0
        var return_velocity:=delta/dt
        if state==&'crouch_walk':
         expected_return*=lerpf(1,Clips.LATERAL_STEP_SCALE,smoothstep(sqrt(.5),1,absf(direction.x)))
         require(Vector2((return_velocity+expected_return).x,(return_velocity+expected_return).z).length()<.09,'Crouching retains its grounded support rate')
        else:
         require(return_velocity.dot(direction)<.06 and Vector2(return_velocity.x,return_velocity.z).length()<=expected_return.length()+.12,'Upright support keeps the return direction and limits its rate within anatomical reach')
       var swing_start:float=support+(1-support)*.30 if state!=&'crouch_walk' else .74
       var swing_end:float=support+(1-support)*.70 if state!=&'crouch_walk' else .86
       if phase>swing_start and phase<swing_end:
        require(delta.dot(direction)>.0001,'Lifted foot returns in the signed travel direction: %s %s %s'%[family,state,direction])
      for side in 2:
       var leg:Dictionary=actor.last_pose.legs[side]
       require(absf(leg.root.distance_to(leg.joint)-Anatomy.THIGH)<.001 and absf(leg.joint.distance_to(leg.end)-Anatomy.SHIN)<.001,'Directional gait preserves both leg lengths')
       var across:Vector3=actor.last_pose.leg_frame.x
       require(leg.end.dot(across)*(-1 if side==0 else 1)>Anatomy.FOOT_HALF_WIDTH,'Foot keeps clearance from opposite lane')
      previous=[foot]
 require(is_equal_approx(Clips.GAIT_STRIDE_LENGTH,1.10),'Stride grows by ten percent')
 require(is_equal_approx(Clips.gait_playback_rate(0),.90),'Walking cadence slows by ten percent')
 require(is_equal_approx(Clips.gait_playback_rate(1),1.0),'Running contact clock follows travelled distance without the former visual slowdown')
 # Walk/run acceleration retains a continuous reference distance.
 require(Clips.cycle_distance(.5)==(Clips.cycle_distance(0)+Clips.cycle_distance(1))*.5,'Acceleration shares the visual stride metric')
 require(Clips.directional_stride(Vector3.RIGHT)<.5,'Lateral steps recover faster than the previous .65 stride')
 actor.free();print('%s: %d signed directional contact, swing, cadence and anatomy checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
