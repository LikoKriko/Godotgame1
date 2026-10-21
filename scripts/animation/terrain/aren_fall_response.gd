extends RefCounted
## Physics-only classifier. Feed AFTER movement, never from foot IK contacts.
## voluntary_jump means a successful take-off event, not a pressed input.
const GRACE=.10
const MIN_DROP=.08
const STEP_CLEARANCE=.28 # Existing step solver supports up to .26 m.
const RELEASE=.12
const REACQUIRE=.12
var mode:="grounded"
var airborne_time:=0.0
var fall_time:=0.0
var dropped_distance:=0.0
var maximum_gap:=0.0
var support_weight:=1.0
var release_weight:=1.0
var vertical_velocity:=0.0
static func smooth5(value:float) -> float:
 var u:=clampf(value,0,1)
 return u*u*u*(u*(u*6-15)+10)
func reset() -> void:
 mode="grounded";airborne_time=0;fall_time=0;dropped_distance=0;maximum_gap=0;support_weight=1;release_weight=1;vertical_velocity=0
func update(delta:float,body_grounded:bool,velocity_y:float,ground_gap:float,step_supported:bool=false,voluntary_jump:bool=false) -> bool:
 var dt:=maxf(0,delta)
 vertical_velocity=velocity_y
 if voluntary_jump:mode="voluntary"
 if body_grounded or (step_supported and mode!="voluntary"):
  if not voluntary_jump:mode="grounded"
  airborne_time=0;fall_time=0;dropped_distance=0;maximum_gap=0
  support_weight=minf(1,support_weight+dt/REACQUIRE)
  return false
 if airborne_time<=0:release_weight=support_weight
 airborne_time+=dt
 dropped_distance+=maxf(0,-velocity_y)*dt
 maximum_gap=maxf(maximum_gap,maxf(0,ground_gap))
 support_weight=release_weight*(1-smooth5(airborne_time/RELEASE))
 if mode=="voluntary":return false
 if mode!="falling" and airborne_time>=GRACE and dropped_distance>=MIN_DROP and velocity_y<-.1 and (maximum_gap>STEP_CLEARANCE or dropped_distance>STEP_CLEARANCE):
  mode="falling";fall_time=0
 elif mode=="falling":fall_time+=dt
 else:mode="unsupported"
 return mode=="falling"
