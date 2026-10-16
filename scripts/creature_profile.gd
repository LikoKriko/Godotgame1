extends Resource
## Species personality and habitat; animation and combat stay on the creature.
@export var species_id: StringName = &"young_mole"
@export var curious := true
@export var aggressive_to_player := true
@export var tree_habitat := true
@export var alert_radius := 250.0
@export var chase_fraction := 0.85
@export var wander_fraction := 0.425
@export var feeding_seconds := Vector2(2,10)
@export var resting_seconds := Vector2(4,8)
@export var posture_seconds := 0.3
@export var head_cycle_seconds := 4.0
@export var food: StringName = &"tree_insects"
