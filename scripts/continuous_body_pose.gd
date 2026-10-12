extends RefCounted
## Authoring rig only: the game displays exported whole sprites.
const UPPER_ARM := 10.0
const FOREARM := 9.0
const THIGH := 12.5
const SHIN := 12.5
const CONTACT := 0.5

static func joint(root: Vector3, end: Vector3, a: float, b: float, pole: Vector3) -> Dictionary:
	var offset := end - root
	var minimum := sqrt(a*a+b*b+2*a*b*cos(deg_to_rad(130))) if a == UPPER_ARM and b == FOREARM else absf(a-b)+0.01
	var distance := clampf(offset.length(),minimum,a+b-0.04)
	var axis := offset.normalized() if offset.length() > 0.001 else Vector3.DOWN
	var across := (pole-axis*pole.dot(axis)).normalized()
	if across.length_squared() < 0.01:
		across = axis.cross(Vector3.RIGHT).normalized()
	var along := (a*a-b*b+distance*distance)/(2*distance)
	var height := sqrt(maxf(0, a*a-along*along))
	return {"root":root, "joint":root+axis*along+across*height, "end":root+axis*distance}

static func gait(phase: float, amplitude: float, running: bool = false) -> Dictionary:
	var cycle := fposmod(phase, 1.0)
	var support := 0.4 if running else 0.6
	var stride := 10.1 if running else 12.0
	var stance := cycle < support
	var t := cycle/support if stance else (cycle-support)/(1-support)
	return {"z":(lerpf(stride,-stride,t) if stance else lerpf(-stride,stride,smoothstep(0,1,t)))*amplitude,
		"lift":0.0 if stance else sin(t*PI)*(9.0 if running else 5.0)*amplitude,
		"pitch":(0.12*sin(t*PI) if stance else -0.18*sin(t*PI))*amplitude}

static func gesture(rest: Vector3, windup: Vector3, impact: Vector3, phase: float, family: StringName) -> Vector3:
	if phase <= 0.30:
		return rest.lerp(windup, smoothstep(0,0.30,phase))
	if phase <= CONTACT:
		return windup.lerp(impact, pow(clampf((phase-0.30)/0.20,0,1),2.1))
	var recovery := smoothstep(0.61,1,phase)
	var recoil := sin(clampf((phase-CONTACT)/0.12,0,1)*PI)*exp(-(phase-CONTACT)*9)
	var resistance := 0.65 if family == &"pickaxe" else 0.35
	return impact.lerp(rest,recovery)+Vector3(0,recoil*resistance,-recoil*resistance)

static func sample(family: StringName, state: StringName, phase: float, stop_phase: float = 0.20, stop_amplitude: float = 1.0, direction: int = -1) -> Dictionary:
	phase = clampf(phase,0,1)
	var crouch_walking := state == &"crouch_walk"
	if crouch_walking: state = &"walk"
	var running := state == &"run" or String(state).ends_with("_run")
	if state == &"run": state = &"walk"
	elif state == &"start_run": state = &"start"
	elif state == &"stop_run": state = &"stop"
	var walking := state in [&"walk",&"start",&"stop"]
	var amplitude := 1.0 if state == &"walk" else (1-smoothstep(0,1,phase) if state == &"stop" else (smoothstep(0,1,phase) if state == &"start" else 0.0))
	var walk_phase := phase if state == &"walk" else (stop_phase if state == &"stop" else 0.0)
	if state == &"stop": amplitude *= stop_amplitude
	var bounce := -2.2-1.4*cos(walk_phase*TAU*2) if walking else 0.0
	var compression := 6.0 if crouch_walking else (phase*6.0 if state == &"crouch" else 0.0)
	if state == &"slide": compression = 8*sin(phase*PI)
	if state == &"jump": compression = 1.4*sin(phase*PI)
	var action := state == &"action"
	var load := sin(phase*PI) if action else 0.0
	var twist := -0.25*sin(phase*TAU) if action and family == &"axe" else 0.0
	if action and family == &"sword": twist = -0.30*sin(phase*TAU)
	if action and family == &"bow": twist = 0.70*smoothstep(0,0.26,phase)*(1-smoothstep(0.72,1,phase))
	var lean := ((0.12+0.035*sin(walk_phase*TAU)) if running else 0.04*sin(walk_phase*TAU))*amplitude if walking else 0.0
	if action: lean = -0.07*sin(phase*TAU)
	if state == &"slide": lean = 0.4*sin(phase*PI)
	var body := Transform3D(Basis.from_euler(Vector3(lean,twist,0)),Vector3(0,bounce*amplitude-compression-load*0.55,0))
	var shoulders: Array[Vector3] = [body*Vector3(-7.6,45.7,0),body*Vector3(7.6,45.7,0)]
	var hips: Array[Vector3] = [body*Vector3(-4.4,26.9,0),body*Vector3(4.4,26.9,0)]
	var legs := []
	for side in 2:
		var step := gait(walk_phase+side*0.5,amplitude,running)
		var ankle := Vector3(-4.4 if side == 0 else 4.4,2+step["lift"],step["z"])
		if state == &"slide": ankle += Vector3(0,0,(7 if side == 0 else -4)*sin(phase*PI))
		if state == &"jump": ankle += Vector3(0,sin(phase*PI)*3,-sin(phase*PI)*2)
		var leg := joint(hips[side],ankle,THIGH,SHIN,Vector3.BACK)
		leg["pitch"] = step["pitch"]
		legs.append(leg)
	var hands: Array[Vector3] = []
	for side in 2:
		var swing := -sin((walk_phase+side*0.5)*TAU)*(7.5 if running else 4.5)*amplitude
		hands.append(body*Vector3(-8.5 if side == 0 else 8.5,28.1,swing+1.5))
	var grip := body*Vector3(4,32,6)
	var shaft := Vector3(0,0.72,0.69).normalized()
	var active := 1
	if family == &"bow":
		active = 0
		grip = body*Vector3(-3.5,36,13)
		shaft = Vector3.UP
		hands[1] = grip+Vector3(0,1,-6)
		if action:
			var lift := smoothstep(0,0.26,phase)*(1-smoothstep(0.72,1,phase))
			grip = grip.lerp(Vector3(2.5,50.5,21.0)+body.origin,lift)
			var draw := smoothstep(0.20,0.44,phase)*(1-smoothstep(0.57,1,phase))
			hands[1] = (grip+Vector3(0,1,-6)).lerp(Vector3(2.5,51.5,3.5)+body.origin,draw)
	elif family == &"sword":
		grip = body*Vector3(6,31,5)
		shaft = Vector3(0,0.35,0.94).normalized()
		if action:
			grip = body*gesture(Vector3(6,31,5),Vector3(3,43,-7),Vector3(6,37,14),phase,family)
			shaft = gesture(Vector3(0,0.35,0.94),Vector3(0,0.6,-0.8),Vector3(-0.35,-0.2,0.9),phase,family).normalized()
			hands[0] = hands[0].lerp(body*Vector3(-5.5,38,5),load)
	elif family in [&"axe",&"pickaxe"]:
		if action:
			var windup := Vector3(3,47,0) if family == &"axe" else Vector3(1.5,49,4)
			var impact := Vector3(4.5,35,13) if family == &"axe" else Vector3(1,31.5,13)
			grip = body*gesture(Vector3(4,32,6),windup,impact,phase,family)
			var wind_direction := Vector3(0,0.95,-0.28) if family == &"axe" else Vector3.UP
			var hit_direction := Vector3(-0.15,0.05,0.98) if family == &"axe" else Vector3(0,-0.55,0.84)
			shaft = body.basis*gesture(Vector3(0,0.72,0.69),wind_direction,hit_direction,phase,family).normalized()
	elif action:
		hands[1] = body*gesture(Vector3(8.5,28.1,1.5),Vector3(7,37,3),Vector3(7,38,16),phase,family)
	# The overhead camera foreshortens a tool held straight forward in north/
	# south views. Open the grip and strike plane obliquely in those views,
	# without stretching limbs or changing timing. Lateral pickaxe/sword poses
	# retain their existing trajectory.
	if direction >= 0 and family in [&"axe",&"pickaxe",&"sword"]:
		var openness := pow(absf(sin(direction*TAU/16)),0.8)
		var open_grip := Vector3(7.5,34,8)
		var open_axis := Vector3(0.5,0.7,0.65)
		if action:
			var wind := Vector3(9,47,5)
			var hit := Vector3(8,32,13)
			var wind_axis := Vector3(0.55,0.82,-0.12)
			var hit_axis := Vector3(0.6,-0.3,0.72)
			if family == &"pickaxe": hit_axis = Vector3(0.4,-0.68,0.6)
			if family == &"sword": wind = Vector3(10,43,1); hit = Vector3(8,37,13); wind_axis = Vector3(0.75,0.6,-0.25)
			open_grip = gesture(open_grip,wind,hit,phase,family)
			open_axis = gesture(open_axis,wind_axis,hit_axis,phase,family)
		grip = grip.lerp(body*open_grip,openness)
		shaft = shaft.lerp(body.basis*open_axis.normalized(),openness).normalized()
	if family != &"":
		if walking: grip += Vector3(0,bounce*0.25*amplitude,sin(walk_phase*TAU)*0.65*amplitude)
		if state == &"equip":
			grip = (body*Vector3(8,28,1.5)).lerp(grip,smoothstep(0,1,phase))
		hands[active] = grip
	return {"body":body,"shoulders":shoulders,"hips":hips,"legs":legs,"hands":hands,"grip":grip,"shaft":shaft,"active":active,"state":state,"phase":phase}
