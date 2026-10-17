extends Resource
## A ramp following a path corridor; all dimensions are in metres.
@export var grade_degrees:=5.0
@export var start_distance:=18.0
@export var length:=20.0
@export var fade_distances:=Vector2(65,100)
@export var shoulder_widths:=Vector2(10,36)
func valid() -> bool:
 return is_finite(grade_degrees) and absf(grade_degrees)<45 and is_finite(start_distance) and is_finite(length) and length>0 and fade_distances.is_finite() and fade_distances.x<fade_distances.y and shoulder_widths.is_finite() and shoulder_widths.x>=0 and shoulder_widths.x<shoulder_widths.y
func sample(point:Vector2,path:Resource) -> float:
 var ramp:=clampf((-point.y+path.origin.y-start_distance),0.0,length)*tan(deg_to_rad(grade_degrees))
 ramp*=1.0-smoothstep(fade_distances.x,fade_distances.y,-point.y+path.origin.y)
 return ramp*(1.0-smoothstep(shoulder_widths.x,shoulder_widths.y,absf(point.x-path.x_at(point.y))))
