extends RefCounted
## Physical speed and animation envelopes share the same interruptible clock.
const SPRINT_MULTIPLIER:=1.6*1.4
const Gait=preload("res://scripts/animation/characters/gait_parameters.gd")
const BACKWARD_MULTIPLIER:=Gait.BACKWARD_SPEED
const GAIT_MULTIPLIER:=1.6
const START_SECONDS:=.16
const MAXIMUM_SECONDS:=1.0
const WALK_START_SECONDS:=.24
const BRAKE_SECONDS:=.12
const REVERSE_BRAKE_SECONDS:=.4
const CORNER_BRAKE_SECONDS:=.2
const REVERSE_HOLD_SECONDS:=.1
const REVERSE_DOT:=-.999998477 # 0.1-degree tolerance for an opposite direction.
const CORNER_DOT_TOLERANCE:=.001745328 # Same tolerance around ninety degrees.
const STEER_RESPONSE:=15.0
const STEER_SPEED:=deg_to_rad(540.0)
var stage:StringName=&"idle"
var elapsed:=0.0
var speed:=0.0
var sprint_weight:=0.0
var direction:=Vector2.ZERO
var entry_speed:=0.0
var entry_weight:=0.0
var destination:=0.0
var maximum_from:=1.0
var maximum_weight:=0.0
var requested:=false
var reverse_scale:=1.0
var reference_scale:=1.0
var pending_direction:=Vector2.ZERO
var turn_brake_seconds:=REVERSE_BRAKE_SECONDS
var turn_hold_seconds:=REVERSE_HOLD_SECONDS
const VALUES:=["elapsed","speed","sprint_weight","entry_speed","entry_weight","destination","maximum_from","maximum_weight","reverse_scale","reference_scale","turn_brake_seconds","turn_hold_seconds"]
static func legacy_default(key:String):
 if key=="turn_brake_seconds":return REVERSE_BRAKE_SECONDS
 if key=="turn_hold_seconds":return REVERSE_HOLD_SECONDS
 return 1.0 if key in ["reverse_scale","reference_scale"] else null
func snapshot() -> Dictionary:
 var data:Dictionary={"stage":String(stage),"requested":requested,"direction":[direction.x,direction.y],"pending_direction":[pending_direction.x,pending_direction.y]}
 for key in VALUES:data[key]=get(key)
 return data
static func valid(data) -> bool:
 if not data is Dictionary or data.get("stage") not in ["idle","start","maximum","brake","walk_start","reverse_brake","reverse_hold"] or not data.get("requested") is bool:return false
 for key in VALUES:
  var value=data.get(key,legacy_default(key))
  if not (value is float or value is int) or not is_finite(value) or value<0 or value>SPRINT_MULTIPLIER+.000001:return false
 for key in ["direction","pending_direction"]:
  var vector=data.get(key,[0.0,0.0] if key=="pending_direction" else null)
  if not vector is Array or vector.size()!=2:return false
  for value in vector:
   if not (value is float or value is int) or not is_finite(value) or absf(value)>1.000001:return false
 if data.get("reverse_scale",1.0)<1 or data.get("reference_scale",1.0)>1:return false
 if data.get("turn_brake_seconds",REVERSE_BRAKE_SECONDS)<=0:return false
 return true
func restore(data:Dictionary) -> void:
 stage=StringName(data.stage);requested=data.requested;direction=Vector2(data.direction[0],data.direction[1])
 for key in VALUES:set(key,float(data.get(key,legacy_default(key))))
 var pending:Array=data.get("pending_direction",[0.0,0.0])
 pending_direction=Vector2(pending[0],pending[1])
static func direction_multiplier(camera_input:Vector2) -> float:
 # Camera-relative S, S+A and S+D share one speed; normalization must not
 # make either backward diagonal faster than walking straight backward.
 return BACKWARD_MULTIPLIER if camera_input.y>0 else 1.0
func reversing() -> bool:return stage in [&"reverse_brake",&"reverse_hold"]
func steer(travel:Vector2,delta:float) -> void:
 if travel.is_zero_approx():return
 var target:=travel.normalized()
 if direction.is_zero_approx():direction=target;return
 var angle:=direction.angle_to(target)
 var eased:=angle*(1-exp(-maxf(0,delta)*STEER_RESPONSE))
 direction=direction.rotated(clampf(eased,-STEER_SPEED*maxf(0,delta),STEER_SPEED*maxf(0,delta))).normalized()
func reverse_motion(delta:float,sprint:bool,direction_scale:float) -> float:
 var remaining:=maxf(0,delta)
 if stage==&"reverse_brake":
  var duration:=turn_brake_seconds*reverse_scale
  var used:=minf(remaining,maxf(0,duration-elapsed))
  elapsed+=used;remaining-=used
  var t:=smoothstep(0,duration,elapsed)
  speed=lerpf(entry_speed,0,t);sprint_weight=lerpf(entry_weight,0,t)
  if elapsed>=duration-.00000001:
   stage=&"reverse_hold";elapsed=0;speed=0;sprint_weight=0;direction=Vector2.ZERO
 if stage==&"reverse_hold":
  var duration:=turn_hold_seconds*reverse_scale
  var used:=minf(remaining,maxf(0,duration-elapsed))
  elapsed+=used;remaining-=used
  speed=0;sprint_weight=0;direction=Vector2.ZERO
  if elapsed>=duration-.00000001:
   elapsed=0;entry_speed=0;entry_weight=0;reference_scale=direction_scale
   # Reuse the established startup: walking .24 s, sprint .16 s + 1 s.
   stage=(&"start" if sprint else &"walk_start") if not pending_direction.is_zero_approx() else &"idle"
   if stage==&"idle":destination=0;requested=false
 return remaining
func advance(travel:Vector2,sprint:bool,crouch:float,delta:float,direction_scale:float=1.0,allow_reversal:bool=true) -> Vector2:
 var moving:=not travel.is_zero_approx()
 sprint=sprint and moving and crouch<.01
 var target:=lerpf(1,.48,crouch)*clampf(direction_scale,0,1) if moving else 0.0
 var remaining:=maxf(0,delta)
 if reversing() and not allow_reversal:
  stage=&"brake";elapsed=0;entry_speed=speed;entry_weight=sprint_weight;requested=false
 if not reversing() and allow_reversal and moving and speed>.03 and not direction.is_zero_approx():
  var alignment:=direction.dot(travel.normalized())
  var opposite:=alignment<=REVERSE_DOT
  if opposite or absf(alignment)<=CORNER_DOT_TOLERANCE:
   turn_brake_seconds=REVERSE_BRAKE_SECONDS if opposite else CORNER_BRAKE_SECONDS
   turn_hold_seconds=REVERSE_HOLD_SECONDS if opposite else 0.0
   reverse_scale=lerpf(1,SPRINT_MULTIPLIER,clampf(sprint_weight,0,1))
   stage=&"reverse_brake";elapsed=0;entry_speed=speed;entry_weight=sprint_weight
 if reversing():
  pending_direction=travel.normalized() if moving else Vector2.ZERO
  requested=sprint;destination=target
  remaining=reverse_motion(remaining,sprint,direction_scale)
  if reversing() or remaining<=.00000001:return direction*speed
 if moving:reference_scale=direction_scale
 if sprint and not requested:
  stage=&"start";elapsed=0;entry_speed=speed;entry_weight=sprint_weight
 elif sprint and requested and not is_equal_approx(target,destination):
  # Retarget the running envelope from its current speed when W/A/D changes
  # to S (or back again); do not jump straight to the other speed limit.
  stage=&"maximum";elapsed=0;maximum_from=speed;maximum_weight=sprint_weight
 elif not sprint and (requested or not is_equal_approx(target,destination)):
  stage=&"walk_start" if target>speed and sprint_weight==0 else &"brake"
  elapsed=0;entry_speed=speed;entry_weight=sprint_weight
 destination=target;requested=sprint
 if stage==&"start":
  var used:=minf(remaining,START_SECONDS-elapsed)
  elapsed+=used;remaining-=used
  var t:=smoothstep(0,START_SECONDS,elapsed)
  speed=lerpf(entry_speed,maxf(direction_scale,entry_speed),t);sprint_weight=entry_weight
  if elapsed>=START_SECONDS-.000001:stage=&"maximum";elapsed=0;maximum_from=speed;maximum_weight=sprint_weight
 if stage==&"maximum":
  elapsed=minf(MAXIMUM_SECONDS,elapsed+remaining)
  var t:=smoothstep(0,MAXIMUM_SECONDS,elapsed)
  sprint_weight=lerpf(maximum_weight,1,t);speed=lerpf(maximum_from,SPRINT_MULTIPLIER*direction_scale,t)
 elif stage==&"walk_start":
  elapsed=minf(WALK_START_SECONDS,elapsed+remaining)
  speed=lerpf(entry_speed,destination,smoothstep(0,WALK_START_SECONDS,elapsed));sprint_weight=0
  if elapsed>=WALK_START_SECONDS:stage=&"idle"
 elif stage==&"brake":
  elapsed=minf(BRAKE_SECONDS,elapsed+remaining)
  var t:=smoothstep(0,BRAKE_SECONDS,elapsed)
  speed=lerpf(entry_speed,destination,t);sprint_weight=lerpf(entry_weight,0,t)
  if elapsed>=BRAKE_SECONDS:stage=&"idle"
 elif stage==&"idle":speed=destination;sprint_weight=0
 if moving:
  if allow_reversal:steer(travel,remaining)
  else:direction=travel.normalized()
 if speed<.00001:direction=Vector2.ZERO
 return direction*speed
func phase() -> float:
 var seconds:=START_SECONDS if stage==&"start" else (MAXIMUM_SECONDS if stage==&"maximum" else BRAKE_SECONDS)
 if stage==&"walk_start":seconds=WALK_START_SECONDS
 elif stage==&"reverse_brake":seconds=turn_brake_seconds*reverse_scale
 elif stage==&"reverse_hold":seconds=turn_hold_seconds*reverse_scale
 return clampf(elapsed/maxf(seconds,.00000001),0,1)
