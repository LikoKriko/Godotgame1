extends RefCounted
## Visual foot direction only. Input, collisions and physical velocity stay live.
const SECONDS:=.12
var initialized:=false
var heading:=0.0
var source:=0.0
var target:=0.0
var elapsed:=SECONDS
func reset() -> void:initialized=false;elapsed=SECONDS
func sample(direction:Vector3,delta:float) -> Vector3:
 if direction.is_zero_approx():reset();return Vector3.ZERO
 var requested:=atan2(direction.x,direction.z)
 if not initialized or delta<=0:
  initialized=true;heading=requested;source=requested;target=requested;elapsed=SECONDS
 if absf(wrapf(requested-target,-PI,PI))>.00001:
  # Small camera-relative changes update the destination without restarting
  # the whole transition every frame during continuous camera movement.
  if absf(wrapf(requested-target,-PI,PI))>deg_to_rad(15):source=heading;elapsed=0
  target=source+wrapf(requested-source,-PI,PI)
 elapsed=minf(SECONDS,elapsed+maxf(0,delta))
 var t:=elapsed/SECONDS
 t=t*t*t*(t*(t*6-15)+10)
 heading=lerpf(source,target,t)
 return Vector3(sin(heading),0,cos(heading))*direction.length()
