extends RefCounted
## Physical speed and animation envelopes share the same interruptible clock.
const START_SECONDS:=.16
const MAXIMUM_SECONDS:=1.0
const BRAKE_SECONDS:=.24
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
const VALUES:=["elapsed","speed","sprint_weight","entry_speed","entry_weight","destination","maximum_from","maximum_weight"]
func snapshot() -> Dictionary:
 var data:Dictionary={"stage":String(stage),"requested":requested,"direction":[direction.x,direction.y]}
 for key in VALUES:data[key]=get(key)
 return data
static func valid(data) -> bool:
 if not data is Dictionary or data.get("stage") not in ["idle","start","maximum","brake"] or not data.get("requested") is bool:return false
 for key in VALUES:
  var value=data.get(key)
  if not (value is float or value is int) or not is_finite(value) or value<0 or value>1.600001:return false
 if not data.get("direction") is Array or data.direction.size()!=2:return false
 for value in data.direction:
  if not (value is float or value is int) or not is_finite(value) or absf(value)>1:return false
 return true
func restore(data:Dictionary) -> void:
 stage=StringName(data.stage);requested=data.requested;direction=Vector2(data.direction[0],data.direction[1])
 for key in VALUES:set(key,float(data[key]))
func advance(travel:Vector2,sprint:bool,crouch:float,delta:float) -> Vector2:
 var moving:=not travel.is_zero_approx()
 sprint=sprint and moving and crouch<.01
 var target:=lerpf(1,.48,crouch) if moving else 0.0
 if sprint and not requested:
  stage=&"start";elapsed=0;entry_speed=speed;entry_weight=sprint_weight
 elif not sprint and (requested or not is_equal_approx(target,destination)):
  stage=&"brake";elapsed=0;entry_speed=speed;entry_weight=sprint_weight
 destination=target;requested=sprint
 var remaining:=maxf(0,delta)
 if stage==&"start":
  var used:=minf(remaining,START_SECONDS-elapsed)
  elapsed+=used;remaining-=used
  var t:=smoothstep(0,START_SECONDS,elapsed)
  speed=lerpf(entry_speed,maxf(1,entry_speed),t);sprint_weight=entry_weight
  if elapsed>=START_SECONDS-.000001:stage=&"maximum";elapsed=0;maximum_from=speed;maximum_weight=sprint_weight
 if stage==&"maximum":
  elapsed=minf(MAXIMUM_SECONDS,elapsed+remaining)
  var t:=smoothstep(0,MAXIMUM_SECONDS,elapsed)
  sprint_weight=lerpf(maximum_weight,1,t);speed=lerpf(maximum_from,1.6,t)
 elif stage==&"brake":
  elapsed=minf(BRAKE_SECONDS,elapsed+remaining)
  var t:=smoothstep(0,BRAKE_SECONDS,elapsed)
  speed=lerpf(entry_speed,destination,t);sprint_weight=lerpf(entry_weight,0,t)
  if elapsed>=BRAKE_SECONDS:stage=&"idle"
 elif stage==&"idle":speed=destination;sprint_weight=0
 if moving:direction=travel.normalized()
 if speed<.00001:direction=Vector2.ZERO
 return direction*speed
func phase() -> float:
 return clampf(elapsed/(START_SECONDS if stage==&"start" else (MAXIMUM_SECONDS if stage==&"maximum" else BRAKE_SECONDS)),0,1)
