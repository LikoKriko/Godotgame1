extends RefCounted
## One authoritative clock drives sunlight and the daily nutrition ledger.
const DAY_SECONDS := 960.0
const START_HOUR := 8.0
var day := 1
var hour := START_HOUR
var day_seconds := DAY_SECONDS

func reset() -> void:
	day = 1
	hour = START_HOUR

func advance(delta: float) -> int:
	var total := hour + maxf(delta,0.0)*24.0/day_seconds
	var crossed := floori(total/24.0)
	day += crossed
	hour = fposmod(total,24.0)
	return crossed

func sun_state() -> Dictionary:
	var progress := clampf((hour-6.0)/14.0,0,1)
	var elevation := maxf(0,sin(progress*PI)) if hour >= 6 and hour <= 20 else 0.0
	var visibility := smoothstep(0,0.22,elevation)
	var afternoon := smoothstep(10,13,hour)*(1-smoothstep(17,20,hour))
	var strength := visibility*lerpf(0.10,0.34,maxf(elevation,afternoon))
	var direction := Vector2(lerpf(-1,1,progress),0.48).normalized()
	var stretch := 0.36+(lerpf(2.6,0.36,elevation)-0.36)*0.8
	var night := Color(0.19,0.235,0.34)
	var twilight := Color(0.62,0.49,0.39)
	var daylight := Color(0.94,0.97,0.91)
	var ambient := night.lerp(twilight,smoothstep(0,0.12,elevation)).lerp(daylight,smoothstep(0.06,0.65,elevation))
	return {"progress": progress,"elevation": elevation,"visible": elevation > 0.001,"direction": direction,"stretch": stretch,"shadow_alpha": strength,"ambient": ambient,"energy": elevation*0.10,"warmth": 1-smoothstep(0.05,0.55,elevation)}

func moon_state() -> Dictionary:
	# Ten hours between sunset (20:00) and sunrise (06:00), continuous at midnight.
	var progress := clampf(fposmod(hour-20.0,24.0)/10.0,0,1)
	var elevation := maxf(0,sin(progress*PI)) if hour >= 20 or hour < 6 else 0.0
	return {"progress": progress,"elevation": elevation,"strength": smoothstep(0,0.25,elevation)}

func clock_text() -> String:
	var minutes := floori(hour*60)
	return "Día %d · %02d:%02d" % [day,floori(minutes/60.0),minutes%60]
