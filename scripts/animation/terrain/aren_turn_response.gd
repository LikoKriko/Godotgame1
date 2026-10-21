extends "res://scripts/prototype_3d/movement_response.gd"
## Keep the existing start/stop envelopes; cornering never enters a zero-speed hold.
const WALK_TURN_SPEED:=deg_to_rad(300)
const RUN_TURN_SPEED:=deg_to_rad(360)
var heading:=PI
var angular_velocity:=0.0
var style_timing:=1.0
var pivoting:=false
var turn_sign:=1.0
var angular_limit:=WALK_TURN_SPEED
var support_factor:=1.0
var corner_speed:=1.0

static func shortest_angle(from:float,to:float) -> float:
 return wrapf(to-from,-PI,PI)

func advance(travel:Vector2,sprint:bool,crouch:float,delta:float,direction_scale:float=1.0,allow_reversal:bool=true) -> Vector2:
 var dt:=maxf(0,delta)
 var moving:=not travel.is_zero_approx()
 heading=wrapf(heading,-PI,PI)
 var angle:=shortest_angle(heading,atan2(travel.x,travel.y)) if moving else 0.0
 pivoting=moving and absf(angle)>deg_to_rad(135) and speed>.03
 angular_limit=lerpf(WALK_TURN_SPEED,RUN_TURN_SPEED,sprint_weight)*clampf(support_factor,.8,1.0)/maxf(style_timing,.1)
 # Suppress only the inherited corner/reversal stops. Acceleration, release,
 # sprint weight and posture still come from the existing response system.
 var motion:=super.advance(travel,sprint,crouch,dt,direction_scale,false)
 var retained:=lerpf(1.0,.2 if sprint else .3,smoothstep(deg_to_rad(45),PI,absf(angle)))
 var seconds:float=(.10 if retained<corner_speed else .18)*style_timing
 corner_speed=move_toward(corner_speed,retained,dt/maxf(seconds,.001))
 if moving:rotate_heading(travel,dt)
 else:angular_velocity=move_toward(angular_velocity,0,deg_to_rad(3600)*dt)
 direction=Vector2(sin(heading),cos(heading)) if speed>.00001 else Vector2.ZERO
 return direction*motion.length()*corner_speed

func rotate_heading(target:Vector2,dt:float) -> void:
 if target.is_zero_approx():return
 var angle:=shortest_angle(heading,atan2(target.x,target.y))
 # Only an exact half-turn has two equally short arcs. Near-180 input must
 # retain its actual sign; inertia must never continue along the longer arc.
 if absf(absf(angle)-PI)<.000001:angle=PI*turn_sign
 elif absf(angle)>.000001:turn_sign=signf(angle)
 if angular_velocity*angle<0:angular_velocity=0
 var wanted:=clampf(angle*24,-angular_limit,angular_limit)
 angular_velocity=move_toward(angular_velocity,wanted,deg_to_rad(3600)*dt/maxf(style_timing,.1))
 var step:=signf(angle)*minf(absf(angle),absf(angular_velocity*dt))
 heading=wrapf(heading+step,-PI,PI)
 if absf(step)>=absf(angle):angular_velocity=0

func steer(travel:Vector2,delta:float) -> void:
 rotate_heading(travel,delta)
 direction=Vector2(sin(heading),cos(heading))
