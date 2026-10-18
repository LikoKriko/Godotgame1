extends SceneTree
const Clips=preload('res://scripts/prototype_3d/survivor_animation.gd')
const Response=preload('res://scripts/prototype_3d/movement_response.gd')
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<14:push_error(message)
func _initialize():call_deferred('run')
func run():
 var camera=load('res://scripts/prototype_3d/shoulder_camera.gd').new()
 for yaw in [-2.1,0.,.7,PI]:
  camera.yaw=yaw
  for x in [-1,1]:
   for y in [-1,1]:
    var travel:Vector3=camera.movement_direction(Vector2(x,y))
    var local:Vector3=Basis(Vector3.UP,-yaw)*travel
    require(absf(rad_to_deg(atan2(absf(local.x),absf(local.z)))-35)<.0001,'Every forward/rear diagonal travels at 35 degrees in the camera frame')
    require(absf(travel.length()-1)<.00001,'Diagonal input never increases physical speed')
    require(local.x*x>0 and local.z*y>0,'Diagonal remapping preserves the requested signs')
 # Camera objects not added to the tree still own their unparented cameras.
 camera.camera.free();camera.aim_camera.free();camera.free()
 for fps in [30,60,120]:
  for input in [Vector2.DOWN,Vector2(-1,1),Vector2(1,1)]:
   var response:=Response.new()
   var scale:float=Response.direction_multiplier(input)
   for frame in fps*2:response.advance(input,true,0,1.0/fps,scale)
   require(absf(response.speed*2-1.344)<.00001,'All three rear running directions use thirty percent of forward sprint speed')
   var saved:=response.snapshot();var restored:=Response.new();restored.restore(saved)
   require(Response.valid(saved),'Rear running retains a valid save envelope')
   restored.advance(input,true,0,1.0/fps,scale)
   require(absf(response.speed-restored.speed)<.00001,'Saved rear running resumes at the same speed')
   response.advance(Vector2.UP,true,0,0,1)
   var previous:float=response.speed
   for frame in fps:
    response.advance(Vector2.UP,true,0,1.0/fps,1)
    require(response.speed>=previous-.00001 and response.speed-previous<.09,'Rear-to-front sprint changes its limit continuously')
    previous=response.speed
   require(absf(response.speed-Response.SPRINT_MULTIPLIER)<.00001,'Forward sprint still reaches its unchanged maximum')
   response.advance(input,true,0,0,scale)
   require(absf(response.speed-previous)<.00001,'Front-to-rear sprint retargeting starts at the current speed')
   for frame in fps:
    response.advance(input,true,0,1.0/fps,scale)
    require(response.speed<=previous+.00001 and previous-response.speed<.09,'Front-to-rear sprint decelerates without a snap')
    previous=response.speed
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 for state in [&'walk',&'run']:
  var run_weight:=1.0 if state==&'run' else 0.0
  var speed:=4.48 if state==&'run' else 2.0
  for x in [-1,0,1]:
   var front:=Vector3(x*sin(Clips.Gait.DIAGONAL_ANGLE),0,cos(Clips.Gait.DIAGONAL_ANGLE) if x!=0 else 1)
   var rear:=Vector3(front.x,0,-front.z)
   var front_cycle:float=Clips.cycle_distance(run_weight,0,front)/Clips.gait_playback_rate(run_weight)
   var rear_cycle:float=Clips.cycle_distance(run_weight,0,rear)/Clips.gait_playback_rate(run_weight)
   require(absf(rear_cycle/front_cycle-.375)<.00001,'Rearward walk and run use a proportional 37.5 percent stride')
   require(absf((speed*.3/rear_cycle)/(speed/front_cycle)-.8)<.00001,'Rearward leg cadence is exactly twenty percent slower than its forward counterpart')
   var forward_pose:Dictionary=Clips.sample(&'',state,.15,.15,front)
   var rear_pose:Dictionary=Clips.sample(&'',state,.15,.15,rear)
   require(absf(rear_pose.gait_extent/forward_pose.gait_extent-.375)<.00001,'Runtime foot reach uses the shortened stride, not only the clock')
   require(absf(absf(rear_pose.leg_frame.get_euler().y)-(Clips.Gait.DIAGONAL_ANGLE if x!=0 else 0))<.00001,'Knee and foot lanes share the new diagonal direction')
   var support:float=(Clips.Gait.RUN_SUPPORT if state==&'run' else Clips.Gait.WALK_SUPPORT)*Clips.directional_stride(rear)
   for family in [&'',&'axe',&'sword',&'bow']:
    actor.family_override=family
    for side in 2:
     for sample in 12:
      var phase:float=support*lerpf(.20,.75,sample/11.0)
      var advance:=support*.005
      actor.animate(state,fposmod(phase-side*.5,1),family!=&'',0,fposmod(phase-side*.5,1),rear)
      var a:Vector3=actor.native.posed[actor.native.legs[side].ids[2]].origin*(1.75/64)
      actor.animate(state,fposmod(phase+advance-side*.5,1),family!=&'',0,fposmod(phase+advance-side*.5,1),rear)
      var b:Vector3=actor.native.posed[actor.native.legs[side].ids[2]].origin*(1.75/64)
      var slip:Vector3=(b-a)/(advance*rear_cycle/(speed*.3))+rear*speed*.3
      require(Vector2(slip.x,slip.z).length()<.15,'Native rear support matches the real world displacement, including weapons')
      require(actor.native.hand_error<.08,'Shorter rear steps preserve native equipment grips')
 actor.free();print('%s: %d rear walk/run cadence, stride, speed, 35-degree diagonal, contact and transition checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
