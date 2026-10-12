extends RefCounted
## Tuned animation parameters: masses/inertia are game values, not force measurements.
const TOOL_MASS := {&"axe": 1.2, &"pickaxe": 1.6}
const DURATION := {&"axe": 0.82, &"pickaxe": 0.96, &"": 0.52, &"sword": 0.62, &"bow": 0.65}
const RESPONSE := {&"madera": 0.13, &"piedra": 0.23, &"chatarra": 0.18, &"fibra": 0.055}
const WINDUP_END := 0.28
const CONTACT := 0.5

static func inertia(item: StringName) -> float:
	# Effective grip-to-head length and distribution chosen for these sprites.
	return TOOL_MASS.get(item,1.0)*0.75*0.75*0.6

static func preparation(phase: float) -> float:
	return smoothstep(0,WINDUP_END,phase)
static func acceleration(phase: float) -> float:
	return pow(clampf((phase-WINDUP_END)/(CONTACT-WINDUP_END),0,1),2.2)
static func rebound(phase: float, item: StringName, material: StringName) -> float:
	if phase <= CONTACT or phase >= 1 or not RESPONSE.has(material):
		return 0.0
	var elapsed: float = (phase-CONTACT)*DURATION.get(item,0.6)
	var frequency := sqrt(350.0/inertia(item))
	return RESPONSE[material]*sin(elapsed*frequency)*exp(-elapsed*13.0)* (1-smoothstep(0.85,1,phase))
static func recovery(phase: float, material: StringName) -> float:
	return smoothstep(0.56 if RESPONSE.has(material) else 0.64,1,phase)
static func body(phase: float, item: StringName, material: StringName) -> Dictionary:
	if item not in TOOL_MASS:
		return {"lean": 0.0,"crouch": 0.0}
	var load := preparation(phase)
	var strike := acceleration(phase)
	var recover := recovery(phase,material)
	var lean := lerpf(-0.045*load,0.075,strike)*(1-recover)-rebound(phase,item,material)*0.10
	var crouch := (0.8*load*(1-strike)+0.25*strike)*(1-recover)
	return {"lean": lean,"crouch": crouch}
static func torso_transform(player: Vector2, facing: StringName, phase: float, item: StringName, material: StringName) -> Transform2D:
	var state := body(phase,item,material)
	var direction := Vector2.from_angle(preload("res://scripts/turn_motion.gd").FACINGS.find(facing)*PI/4)
	var angle: float = state["lean"]*direction.x
	var pivot := player+Vector2(0,-5)
	return Transform2D(angle,pivot-pivot.rotated(angle)+Vector2(0,state["crouch"]))
