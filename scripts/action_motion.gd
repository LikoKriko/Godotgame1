extends RefCounted
## Durations shared by gameplay contact and exported complete-sprite actions.
const DURATION := {&"axe": 0.82, &"pickaxe": 0.96, &"": 0.52, &"sword": 0.62, &"bow": 0.82}

const BOW_DRAW_SECONDS := 0.5
static func contact_time(category: StringName, duration: float) -> float:
	return BOW_DRAW_SECONDS if category == &"bow" else duration*0.5
