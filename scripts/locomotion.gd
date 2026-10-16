extends RefCounted
const JUMP_SECONDS := 0.66
const SLIDE_SECONDS := 0.46
const MAX_AIR_TURN := deg_to_rad(70)
const SLIDE_DISTANCE_FACTOR := 0.85
const SLIDE_JUMP_DISTANCE_FACTOR := 0.70
var from_slide := false
var jump_heading := 0.0
var launch_heading := 0.0
var jump_speed := 0.0
var jump_elapsed := JUMP_SECONDS
var slide_elapsed := SLIDE_SECONDS
var cooldown := 0.0
var crouch := 0.0
var slide_direction := Vector2.ZERO
var slide_distance_scale:=1.0
func reset() -> void:
	jump_elapsed = JUMP_SECONDS
	from_slide = false
	jump_speed = 0.0
	slide_elapsed = SLIDE_SECONDS
	cooldown = 0
	crouch = 0
	slide_direction = Vector2.ZERO
	slide_distance_scale=1.0
func airborne() -> bool: return jump_elapsed < JUMP_SECONDS
func sliding() -> bool: return slide_elapsed < SLIDE_SECONDS
func slide_speed() -> float:
	return lerpf(340*SLIDE_DISTANCE_FACTOR*slide_distance_scale,0,smoothstep(0,SLIDE_SECONDS,slide_elapsed))
func jump(inertia_multiplier: float = 1.0) -> bool:
	if airborne(): return false
	from_slide = sliding()
	if from_slide:
		jump_speed = slide_speed()*inertia_multiplier*SLIDE_JUMP_DISTANCE_FACTOR
		launch_heading = slide_direction.angle()
		jump_heading = launch_heading
		slide_elapsed = SLIDE_SECONDS
		crouch = 0.0
	jump_elapsed = 0
	return true
func steer_air(direction: Vector2, delta: float) -> void:
	if not airborne() or not from_slide or direction.is_zero_approx(): return
	var offset := clampf(wrapf(direction.angle()-launch_heading,-PI,PI),-MAX_AIR_TURN,MAX_AIR_TURN)
	jump_heading = move_toward(jump_heading,launch_heading+offset,maxf(delta,0)*4.0)

func slide(direction: Vector2,distance_scale:float=1.0) -> bool:
	if direction.is_zero_approx() or airborne() or sliding() or cooldown > 0: return false
	slide_direction = direction.normalized()
	slide_distance_scale=clampf(distance_scale,0,1)
	slide_elapsed = 0
	cooldown = 0.9
	return true
func advance(delta: float, crouching: bool) -> void:
	jump_elapsed = minf(JUMP_SECONDS,jump_elapsed+delta)
	if not airborne():
		from_slide = false
		jump_speed = 0
	slide_elapsed = minf(SLIDE_SECONDS,slide_elapsed+delta)
	cooldown = maxf(0,cooldown-delta)
	var target := 1.0 if crouching and not airborne() else 0.0
	crouch = move_toward(crouch,target,delta/0.16)
func height() -> float:
	var phase := jump_elapsed/JUMP_SECONDS
	return 24*4*phase*(1-phase) if airborne() else 0.0
func speed_factor() -> float: return lerpf(1,0.48,crouch)
func velocity(normal: Vector2, multiplier: float) -> Vector2:
	if airborne() and from_slide: return Vector2.from_angle(jump_heading)*jump_speed
	if not sliding(): return normal*speed_factor()
	return slide_direction*slide_speed()*multiplier
