extends RefCounted
const JUMP_SECONDS := 0.66
const SLIDE_SECONDS := 0.46
const SLIDE_JUMP_MULTIPLIER := 1.15
var jump_multiplier := 1.0
var jump_elapsed := JUMP_SECONDS
var slide_elapsed := SLIDE_SECONDS
var cooldown := 0.0
var crouch := 0.0
var slide_direction := Vector2.ZERO
func reset() -> void:
	jump_elapsed = JUMP_SECONDS
	jump_multiplier = 1.0
	slide_elapsed = SLIDE_SECONDS
	cooldown = 0
	crouch = 0
	slide_direction = Vector2.ZERO
func airborne() -> bool: return jump_elapsed < JUMP_SECONDS
func sliding() -> bool: return slide_elapsed < SLIDE_SECONDS
func slide_jump_window() -> bool:
	return sliding() and slide_elapsed >= SLIDE_SECONDS*0.5
func jump() -> bool:
	if airborne() or (sliding() and not slide_jump_window()): return false
	jump_multiplier = SLIDE_JUMP_MULTIPLIER if slide_jump_window() else 1.0
	if sliding():
		slide_elapsed = SLIDE_SECONDS
		crouch = 0.0
	jump_elapsed = 0
	return true
func slide(direction: Vector2) -> bool:
	if direction.is_zero_approx() or airborne() or sliding() or cooldown > 0: return false
	slide_direction = direction.normalized()
	slide_elapsed = 0
	cooldown = 0.9
	return true
func advance(delta: float, crouching: bool) -> void:
	jump_elapsed = minf(JUMP_SECONDS,jump_elapsed+delta)
	if not airborne(): jump_multiplier = 1.0
	slide_elapsed = minf(SLIDE_SECONDS,slide_elapsed+delta)
	cooldown = maxf(0,cooldown-delta)
	var target := 1.0 if crouching and not airborne() else 0.0
	crouch = move_toward(crouch,target,delta/0.16)
func height() -> float:
	var phase := jump_elapsed/JUMP_SECONDS
	return 24*4*phase*(1-phase) if airborne() else 0.0
func compression() -> float:
	if sliding(): return sin(PI*slide_elapsed/SLIDE_SECONDS)*9
	if airborne(): return sin(PI*jump_elapsed/JUMP_SECONDS)*2
	return crouch*7
func speed_factor() -> float: return lerpf(1,0.48,crouch)
func velocity(normal: Vector2, multiplier: float) -> Vector2:
	if not sliding(): return normal*speed_factor()*(jump_multiplier if airborne() else 1.0)
	return slide_direction*lerpf(340,0,smoothstep(0,SLIDE_SECONDS,slide_elapsed))*multiplier
func torso_transform(player: Vector2, facing: StringName) -> Transform2D:
	var index := preload("res://scripts/turn_motion.gd").FACINGS.find(facing)
	var direction := Vector2.from_angle(index*PI/4)
	var angle := direction.x*(0.52*sin(PI*slide_elapsed/SLIDE_SECONDS) if sliding() else crouch*0.12)
	var pivot := player+Vector2(0,-5)
	return Transform2D(angle,pivot-pivot.rotated(angle)+Vector2(0,compression()-height()))
