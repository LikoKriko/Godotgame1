extends RefCounted
## Reward amounts belong to future quest/achievement/boss/item definitions.
## Register the permitted sources without inventing any reward or content.
const SOURCES := {
	&"main_quest":"Misiones principales",
	&"side_quest":"Misiones secundarias",
	&"achievement":"Logros",
	&"boss":"Derrotar jefes",
	&"craft":"Craftear objetos",
}
static func accepts(source: StringName) -> bool: return SOURCES.has(source)
