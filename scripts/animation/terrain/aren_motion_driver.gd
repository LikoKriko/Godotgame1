extends RefCounted
## Shared by the comparison viewer and the provisional terrain scene.
const Response=preload("res://scripts/prototype_3d/movement_response.gd")
const Turning=preload("res://scripts/animation/terrain/aren_turn_response.gd")
const Step=preload("res://scripts/animation/terrain/terrain_step.gd")
var response:RefCounted
var corrected:=true
var requested_gait:="idle"
var walk_speed:=0.0
var run_speed:=0.0
var pose_ms:=0.0

func _init(use_correction:bool=true) -> void:
 corrected=use_correction
 response=Turning.new() if corrected else Response.new()

func advance(body:CharacterBody3D,actor:Node3D,input:Vector2,running:bool,yaw:float,dt:float) -> void:
 var direction:Vector3=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y).normalized()
 if corrected:
  response.style_timing=float(actor.profile.styles[actor.style].timing)
  var planted:=0
  for contact in actor.terrain_contacts:
   if contact.planted:planted+=1
  response.support_factor=.75 if planted==2 else 1.0
  if not input.is_zero_approx():
   var requested_angle:=wrapf(atan2(direction.x,direction.z)-response.heading,-PI,PI)
   var turn_sign:float=response.turn_sign if absf(requested_angle)>PI-.01 else signf(requested_angle)
   for contact in actor.terrain_contacts:
    if not contact.planted or not contact.has("heading"):continue
    var planted_heading:Vector3=contact.heading
    var twist:float=wrapf(response.heading-atan2(planted_heading.x,planted_heading.z),-PI,PI)*turn_sign
    var available:float=clampf((deg_to_rad(50)-twist)/deg_to_rad(25),.1,1.0)
    response.support_factor=minf(response.support_factor,available)
 var velocity_input:Vector2=response.advance(Vector2(direction.x,direction.z),running,0,dt)
 if walk_speed==0:walk_speed=actor.speed_for("walk");run_speed=actor.speed_for("run")
 walk_speed=lerpf(walk_speed,actor.speed_for("walk"),1-exp(-dt*8))
 run_speed=lerpf(run_speed,actor.speed_for("run"),1-exp(-dt*8))
 var amount:float=velocity_input.length()/lerpf(1,Response.SPRINT_MULTIPLIER,response.sprint_weight)
 var speed:float=lerpf(walk_speed,run_speed,response.sprint_weight)*amount
 var travel:Vector2=velocity_input.normalized()*speed
 var gait:="idle" if speed<.01 else ("run" if running and not response.reversing() else "walk")
 if gait!=requested_gait:
  var origin:="idle" if actor.current_speed<.01 else ("walk" if actor.current_speed<=actor.speed_for("walk") else "run")
  if origin!=gait:actor.request_transition(origin+"_to_"+gait)
  requested_gait=gait
 body.velocity.x=travel.x;body.velocity.z=travel.y
 if not body.is_on_floor():body.velocity.y-=20*dt
 else:body.velocity.y=-.1
 body.floor_snap_length=maxf(.025,speed*dt*tan(body.floor_max_angle)+.005)
 var before:=body.position
 # The viewer's slow-motion clock must scale physical travel as well as pose.
 var engine_dt:float=body.get_physics_process_delta_time() if Engine.is_in_physics_frame() else body.get_process_delta_time()
 var time_ratio:float=dt/maxf(engine_dt,.000001)
 body.velocity*=time_ratio
 if not Step.move(body,Vector3(travel.x,0,travel.y)*dt):body.move_and_slide()
 body.velocity/=time_ratio
 var displacement:=body.position-before
 var old_heading:float=actor.rotation.y
 if corrected:
  actor.rotation.y=response.heading
 else:
  var planar:=Vector2(displacement.x,displacement.z)
  if planar.length()>.00001:actor.rotation.y=rotate_toward(actor.rotation.y,atan2(planar.x,planar.y),Response.STEER_SPEED*dt)
 actor.turn_rate=wrapf(actor.rotation.y-old_heading,-PI,PI)/maxf(dt,.00001) if corrected else 0.0
 actor.turn_correction=corrected
 var actual_speed:=Vector2(displacement.x,displacement.z).length()/maxf(dt,.00001)
 var bank_limit:float=deg_to_rad(lerpf(6,12,response.sprint_weight))/maxf(float(actor.profile.styles[actor.style].timing),1)
 actor.turn_bank_target=clampf(-atan2(actual_speed*actor.turn_rate,9.81)*.3,-bank_limit,bank_limit) if corrected else 0.0
 var start:=Time.get_ticks_usec()
 actor.evaluate_motion(dt,displacement/dt,body.is_on_floor())
 pose_ms=(Time.get_ticks_usec()-start)/1000.0
