extends "res://scripts/prototype_3d/movement_response.gd"
## Aren-only steering adapter. Keep the game's speed/brake/start envelopes.
var heading:=PI
var angular_velocity:=0.0
var style_timing:=1.0
var pivoting:=false
var turn_sign:=1.0
var angular_limit:=deg_to_rad(180)
var support_factor:=1.0

func advance(travel:Vector2,sprint:bool,crouch:float,delta:float,direction_scale:float=1.0,allow_reversal:bool=true) -> Vector2:
 pivoting=false
 angular_limit=lerpf(deg_to_rad(180),deg_to_rad(135),sprint_weight)*support_factor/style_timing
 if not travel.is_zero_approx() and not reversing():
  var forward:=Vector2(sin(heading),cos(heading))
  var alignment:=forward.dot(travel.normalized())
  # A broad reversal cone also catches W/S while the camera is moving.
  if alignment<cos(deg_to_rad(135)) and speed>.03:
   stage=&"reverse_brake";elapsed=0;entry_speed=speed;entry_weight=sprint_weight
   turn_brake_seconds=REVERSE_BRAKE_SECONDS;turn_hold_seconds=REVERSE_HOLD_SECONDS
   reverse_scale=lerpf(1,SPRINT_MULTIPLIER,sprint_weight)
   pending_direction=travel.normalized()
  elif speed<=.03 and alignment<cos(deg_to_rad(35)):
   stage=&"reverse_hold";elapsed=0;pending_direction=travel.normalized()
   turn_hold_seconds=REVERSE_HOLD_SECONDS;reverse_scale=1
 if direction.is_zero_approx() and not reversing():direction=Vector2(sin(heading),cos(heading))
 var result:=super.advance(travel,sprint,crouch,delta,direction_scale,allow_reversal)
 if stage!=&"reverse_hold":pivoting=false
 if travel.is_zero_approx() and not reversing():angular_velocity=move_toward(angular_velocity,0,deg_to_rad(720)*delta)
 return result

func rotate_heading(target:Vector2,dt:float) -> void:
 if target.is_zero_approx():return
 var desired:=atan2(target.x,target.y)
 var angle:=wrapf(desired-heading,-PI,PI)
 if absf(angle)>PI-.01:angle=absf(angle)*turn_sign
 elif absf(angle)>.01:turn_sign=signf(angle)
 var wanted:=clampf(angle*8,-angular_limit,angular_limit)
 angular_velocity=move_toward(angular_velocity,wanted,deg_to_rad(720)*dt/style_timing)
 var step:=angular_velocity*dt
 if absf(step)>absf(angle) and step*angle>=0:step=angle;angular_velocity=0
 heading=wrapf(heading+step,-PI,PI)

func steer(travel:Vector2,delta:float) -> void:
 rotate_heading(travel,delta)
 direction=Vector2(sin(heading),cos(heading))

func reverse_motion(delta:float,sprint:bool,direction_scale:float) -> float:
 if stage==&"reverse_hold" and not pending_direction.is_zero_approx():
  pivoting=true
  angular_limit=deg_to_rad(135)*support_factor/style_timing
  rotate_heading(pending_direction,delta)
  var error:=absf(wrapf(atan2(pending_direction.x,pending_direction.y)-heading,-PI,PI))
  if error>deg_to_rad(3):
   speed=0;sprint_weight=0;direction=Vector2.ZERO
   return 0.0
 return super.reverse_motion(delta,sprint,direction_scale)
