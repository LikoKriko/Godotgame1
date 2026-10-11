extends RefCounted
## Angle-based steering: 45° turns slow 2.2%, 90° 8.8%, 180° 35%.
const MAX_TURN_TIME := 0.28
const MAX_SLOWDOWN := 0.35
const FACINGS := [&"right", &"down_right", &"down", &"down_left", &"left", &"up_left", &"up", &"up_right"]
var heading := PI / 2.0
var target_direction := Vector2.ZERO
var start_heading := PI / 2.0
var turn_angle := 0.0
var elapsed := 0.0
var duration := 0.0
var speed_factor := 1.0

func reset() -> void:
	heading = PI / 2.0
	start_heading = heading
	target_direction = Vector2.ZERO
	turn_angle = 0.0
	elapsed = 0.0
	duration = 0.0
	speed_factor = 1.0

func step(input_direction: Vector2, delta: float, max_speed: float) -> Vector2:
	var direction := input_direction.normalized()
	if direction == Vector2.ZERO:
		target_direction = Vector2.ZERO
		duration = 0.0
		speed_factor = 1.0
		return Vector2.ZERO
	if not direction.is_equal_approx(target_direction):
		target_direction = direction
		start_heading = heading
		turn_angle = wrapf(direction.angle() - heading, -PI, PI)
		if is_equal_approx(absf(turn_angle), PI):
			turn_angle = -PI
		duration = MAX_TURN_TIME * absf(turn_angle) / PI
		elapsed = 0.0
	elapsed = minf(elapsed + maxf(delta, 0.0), duration)
	var progress := 1.0 if duration < 0.00001 else elapsed / duration
	# Smooth rotation with exact endpoints; slowdown disappears at completion.
	var eased := progress * progress * (3.0 - 2.0 * progress)
	heading = start_heading + turn_angle * eased
	var penalty := MAX_SLOWDOWN * pow(absf(turn_angle) / PI, 2.0)
	speed_factor = 1.0 - penalty * sin(PI * progress)
	if progress >= 1.0:
		heading = direction.angle()
		speed_factor = 1.0
	return Vector2.from_angle(heading) * max_speed * speed_factor

func facing() -> StringName:
	return facing_at(heading)

static func facing_at(angle: float) -> StringName:
	return FACINGS[posmod(roundi(angle / (PI / 4.0)), 8)]

func is_turning() -> bool:
	return target_direction != Vector2.ZERO and duration > 0.00001 and elapsed < duration

func turn_animation() -> StringName:
	var from := facing_at(start_heading)
	var to := facing_at(target_direction.angle())
	return StringName("turn_%s_%s" % [from, to]) if from != to else &""

func turn_progress() -> float:
	var progress := 1.0 if duration < 0.00001 else elapsed / duration
	return progress * progress * (3.0 - 2.0 * progress)
