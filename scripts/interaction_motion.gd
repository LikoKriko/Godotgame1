extends RefCounted
## Temporary interaction costs advance in gameplay time, so menus pause them.
const DRAW_RECOVERY := 1.0
const DRAW_PENALTY := 0.05
const PICKUP_SECONDS := 0.36
const PICKUP_RECOVERY := 0.5
var pickup_remaining := 0.0
var pickup_recovery := 0.0
var draw_remaining := 0.0

func reset() -> void:
	draw_remaining = 0.0
	pickup_remaining = 0.0
	pickup_recovery = 0.0

func draw_object() -> void:
	draw_remaining = DRAW_RECOVERY

func advance(delta: float) -> void:
	var step := maxf(delta,0)
	draw_remaining = maxf(0,draw_remaining-step)
	if picking_up():
		var overflow := maxf(0,step-pickup_remaining)
		pickup_remaining = maxf(0,pickup_remaining-step)
		if not picking_up(): pickup_recovery = maxf(0,PICKUP_RECOVERY-overflow)
	else:
		pickup_recovery = maxf(0,pickup_recovery-step)

func pick_up() -> bool:
	if picking_up(): return false
	pickup_remaining = PICKUP_SECONDS
	pickup_recovery = 0
	return true

func picking_up() -> bool: return pickup_remaining > 0
func pickup_phase() -> float: return 1-pickup_remaining/PICKUP_SECONDS
func cancel_pickup() -> void:
	if picking_up(): pickup_recovery = PICKUP_RECOVERY
	pickup_remaining = 0

func speed_multiplier() -> float:
	var pickup_factor := 0.4 if picking_up() else 1.0-0.6*pickup_recovery/PICKUP_RECOVERY
	return (1.0-DRAW_PENALTY*draw_remaining/DRAW_RECOVERY)*pickup_factor
