extends RefCounted
const COOLDOWN := 4.0
const BEFORE_IMPACT := 0.5
const AFTER_IMPACT := 0.2
const DAMAGE_DELAY := 0.35
const STUN_SECONDS := 0.75
var time := 0.0
var last_activation := -COOLDOWN
var used := false
var pending: Array[Dictionary] = []

func reset() -> void:
	time = 0; last_activation = -COOLDOWN; used = false; pending.clear()

func cooldown_remaining() -> float:
	return maxf(0,COOLDOWN-(time-last_activation))

func eligible(impact: float) -> bool:
	return not used and last_activation >= impact-BEFORE_IMPACT-0.000001 and last_activation <= impact+AFTER_IMPACT+0.000001

func activate() -> bool:
	if cooldown_remaining() > 0: return false
	last_activation = time; used = false
	# Post-impact attempts can cancel a queued hit before its delayed damage.
	for hit in pending:
		if eligible(hit.impact):
			deflect(hit.attacker); pending.erase(hit); break
	return true

func deflect(attacker) -> void:
	used = true
	if is_instance_valid(attacker) and attacker.has_method("stun"): attacker.stun(STUN_SECONDS)

func impact(attacker, damage: float, contact_time: float = -INF) -> bool:
	if contact_time == -INF: contact_time = time
	if eligible(contact_time): deflect(attacker); return true
	pending.append({"attacker":attacker,"damage":damage,"impact":contact_time})
	return false

func advance(delta: float) -> Array[Dictionary]:
	time += maxf(delta,0)
	var applied: Array[Dictionary] = []
	for hit in pending.duplicate():
		if time+0.000000001 >= hit.impact+DAMAGE_DELAY:
			applied.append(hit); pending.erase(hit)
	return applied
