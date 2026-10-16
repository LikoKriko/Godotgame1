extends RefCounted
## Reusable timed states. New states add a definition and their own behavior.
const STUN_SECONDS := 1.5
const DEFINITIONS := {&"stun":{"duration":STUN_SECONDS,"color":Color("e6dfa6")}}
var active: Dictionary = {}
func remaining(id: StringName) -> float: return active.get(id,{}).get("remaining",0.0)
func set_remaining(id: StringName, seconds: float) -> void:
	if not DEFINITIONS.has(id) or not is_finite(seconds): return
	if seconds <= 0: active.erase(id); return
	if not active.has(id): apply(id,seconds)
	else: active[id].remaining = seconds; active[id].total = active[id].elapsed+seconds
func apply(id: StringName, seconds: float = -1) -> bool:
	if not DEFINITIONS.has(id): return false
	if seconds < 0: seconds = DEFINITIONS[id].duration
	if seconds <= 0 or not is_finite(seconds): return false
	if active.has(id):
		active[id].remaining = maxf(active[id].remaining,seconds)
		active[id].total = active[id].elapsed+active[id].remaining
	else: active[id] = {"remaining":seconds,"total":seconds,"elapsed":0.0}
	return true
func advance(delta: float) -> void:
	for id in active.keys():
		active[id].elapsed += maxf(delta,0)
		active[id].remaining = maxf(0,active[id].remaining-maxf(delta,0))
		if active[id].remaining <= 0.000001: active.erase(id)
func fraction(id: StringName) -> float:
	return clampf(remaining(id)/maxf(0.000001,active.get(id,{}).get("total",1.0)),0,1)
func elapsed(id: StringName) -> float: return active.get(id,{}).get("elapsed",0.0)
static func valid_snapshot(value) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if not DEFINITIONS.has(id) or not value[id] is Dictionary: return false
		for field in ["remaining","total","elapsed"]:
			if not value[id].get(field) is float or not is_finite(value[id][field]): return false
		if value[id].remaining <= 0 or value[id].remaining > value[id].total or value[id].elapsed < 0 or absf(value[id].elapsed+value[id].remaining-value[id].total) > 0.00001: return false
	return true
