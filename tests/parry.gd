extends SceneTree
const Parry = preload("res://scripts/parry.gd")
var failures := 0
var checks := 0
class Attacker extends RefCounted:
	var stunned := 0.0
	func stun(seconds: float): stunned = seconds
func require(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize() -> void:
	var attacker := Attacker.new()
	for before in [0.0,0.25,0.5]:
		var parry = Parry.new(); parry.advance(1)
		require(parry.activate(),"A ready attempt activates")
		parry.advance(before)
		require(parry.impact(attacker,2) and attacker.stunned == 1.5 and parry.pending.is_empty(),"An attempt up to exactly 0.5 seconds early deflects and stuns")
	for after in [0.0,0.1,0.2]:
		var parry = Parry.new(); parry.advance(1); attacker.stunned = 0
		require(not parry.impact(attacker,2),"Unprotected contact queues damage")
		require(parry.advance(after).is_empty(),"Damage does not apply inside the post-contact window")
		require(parry.activate() and parry.pending.is_empty() and attacker.stunned == 1.5,"An attempt up to exactly 0.2 seconds late cancels the pending hit")
		require(parry.advance(1).is_empty(),"Cancelled contact cannot later apply damage")
	var late = Parry.new(); late.advance(1); late.impact(attacker,2); late.advance(0.201)
	require(late.activate() and late.pending.size() == 1,"A late attempt spends its cooldown and cannot erase the hit")
	require(late.advance(0.148).is_empty(),"Damage remains deferred until 0.35 seconds")
	var damage: Array = late.advance(0.002)
	require(damage.size() == 1 and damage[0].damage == 2,"Exactly one hit delivers its correct delayed damage")
	require(late.advance(1).is_empty(),"A delivered hit cannot damage twice")
	var early = Parry.new(); early.advance(1); early.activate(); early.advance(0.501)
	require(not early.impact(attacker,2),"An attempt more than 0.5 seconds early misses")
	require(not early.activate(),"Cooldown prevents another attempt")
	early.advance(3.499)
	require(early.activate(),"Another attempt becomes available exactly four seconds after activation")
	print("%s: %d parry boundary, stun and delayed-damage checks" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(0 if failures == 0 else 1)
