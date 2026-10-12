extends RefCounted
const STATES := [&"idle",&"walk",&"jump",&"crouch",&"slide",&"equip",&"axe",&"pickaxe",&"punch"]
const FRAMES := 8
static var catalogue: Dictionary = build_catalogue()
static func authored(state: StringName, facing: int, phase: float) -> Dictionary:
	var wave := sin(phase*TAU)
	var load := sin(phase*PI)
	var twist := 0.0
	var flutter := 0.0
	var fold := 0.0
	match state:
		&"idle":
			twist = wave*0.04
			fold = cos(phase*TAU)*0.04
		&"walk":
			twist = wave*0.24
			flutter = sin(phase*TAU+0.5)*0.36
			fold = absf(wave)*0.45
		&"jump":
			twist = -load*0.10
			flutter = -load*0.5
			fold = load*0.85
		&"crouch":
			twist = smoothstep(0,1,phase)*0.10
			flutter = phase*0.22
			fold = smoothstep(0,1,phase)*0.9
		&"slide":
			twist = load*0.36
			flutter = load*0.65
			fold = load
		&"equip":
			twist = load*0.18
			flutter = wave*0.16
			fold = load*0.3
		&"axe":
			twist = sin(phase*TAU-0.4)*0.36*sin(phase*PI)
			flutter = sin(phase*TAU+0.4)*0.38*load
			fold = load*0.5
		&"pickaxe":
			twist = wave*0.08
			flutter = sin(phase*TAU+1)*0.25*load
			fold = load*0.65
		&"punch":
			twist = wave*0.2
			flutter = wave*0.18
			fold = load*0.35
	var direction := Vector2.from_angle(facing*PI/4-PI/2)
	return {"twist":twist,"flutter":flutter,"fold":fold,"pocket":cos(phase*TAU)*0.10*fold,"depth":0.72+0.28*absf(direction.y)}
static func build_catalogue() -> Dictionary:
	var result := {}
	for facing in 8:
		for state in STATES:
			var poses := []
			for frame in FRAMES:
				poses.append(authored(state,facing,float(frame)/(FRAMES-1)))
			result["%d/%s" % [facing,state]] = poses
	return result
static func sample(state: StringName,facing: int,phase: float) -> Dictionary:
	var poses: Array = catalogue["%d/%s" % [facing,state]]
	var position := clampf(phase,0,1)*(FRAMES-1)
	var first := floori(position)
	var second := mini(first+1,FRAMES-1)
	var result := {}
	for key in poses[first]:
		result[key] = lerpf(poses[first][key],poses[second][key],position-first)
	return result
