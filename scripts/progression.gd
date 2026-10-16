extends RefCounted
# All purchases share the player's level points; definitions expose future costs
# while this first catalog enables one ability level and two perk phases.
const SKILLS := {
	&"speed": {"name":"Impulso", "description":"+25% de velocidad durante 5 s.\nEspera: 20 s.\nAtajo: Z", "duration":5.0,"cooldown":20.0},
	&"power": {"name":"Golpe potenciado", "description":"El siguiente impacto con espada o arco causa +50% de daño.\nCaduca a los 5 s. Espera: 15 s.\nAtajo: X", "duration":5.0,"cooldown":15.0}
}
const PERKS := {
	&"life": {"name":"Vitalidad", "description":"+10% de vida máxima por fase."},
	&"attack": {"name":"Ataque", "description":"+10% de ataque base por fase.\nSe aplica a espada y arco."},
	&"critical": {"name":"Probabilidad crítica", "description":"+5 puntos porcentuales de crítico por fase.\nDaño crítico: ×1,1."}
}
const SKILL_LIMIT := 1
const PERK_LIMIT := 2
var skills := {&"speed":0,&"power":0}
var perks := {&"life":0,&"attack":0,&"critical":0}
var active := {&"speed":0.0,&"power":0.0}
var cooldowns := {&"speed":0.0,&"power":0.0}
var health := 20.0
var rng := RandomNumberGenerator.new()

func reset() -> void:
	for id in skills: skills[id] = 0; active[id] = 0.0; cooldowns[id] = 0.0
	for id in perks: perks[id] = 0
	health = 20.0
	rng.randomize()

static func skill_cost(next_level: int) -> int:
	return 1 << (next_level-1)
static func perk_cost(next_phase: int) -> int:
	return 2 if next_phase == 1 else next_phase
func cost(id: StringName, ability: bool) -> int:
	return skill_cost(skills[id]+1) if ability else perk_cost(perks[id]+1)
func can_buy(id: StringName, ability: bool, points: int) -> bool:
	var ranks: Dictionary = skills if ability else perks
	return ranks.has(id) and ranks[id] < (SKILL_LIMIT if ability else PERK_LIMIT) and points >= cost(id,ability)
func purchase(id: StringName, ability: bool, points: int) -> int:
	if not can_buy(id,ability,points): return 0
	var spent := cost(id,ability)
	var previous := max_health()
	if ability: skills[id] += 1
	else: perks[id] += 1
	# Increasing capacity adds the new capacity, without healing old wounds.
	health = minf(max_health(),health+max_health()-previous)
	return spent
func activate(id: StringName) -> bool:
	if not skills.has(id) or skills[id] == 0 or cooldowns[id] > 0 or health <= 0: return false
	active[id] = SKILLS[id].duration
	cooldowns[id] = SKILLS[id].cooldown
	return true
func advance(delta: float) -> void:
	for id in skills:
		active[id] = maxf(0,active[id]-delta)
		cooldowns[id] = maxf(0,cooldowns[id]-delta)
func max_health() -> float:
	return 20.0*(1+0.1*perks[&"life"])
func attack_multiplier() -> float:
	return 1+0.1*perks[&"attack"]
func critical_chance() -> float:
	return 0.01+0.05*perks[&"critical"]
func speed_multiplier() -> float:
	return 1.25 if active[&"speed"] > 0 else 1.0
func combat_damage(base: float, roll: float = -1) -> float:
	var damage := base*attack_multiplier()
	if active[&"power"] > 0:
		damage *= 1.5
		active[&"power"] = 0.0
	if (rng.randf() if roll < 0 else roll) < critical_chance(): damage *= 1.1
	return damage
func take_damage(amount: float) -> void:
	health = clampf(health-maxf(0,amount),0,max_health())
