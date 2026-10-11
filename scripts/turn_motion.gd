extends RefCounted
## Angle-based steering: 45° turns slow 2.2%, 90° 8.8%, 180° 35%.
const MAX_TURN_TIME := 0.28
const MAX_SLOWDOWN := 0.35
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
	var direction := Vector2.from_angle(heading)
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y > 0.0 else &"up"
