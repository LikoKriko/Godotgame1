extends Resource
## A reusable meandering path in world metres, with one matching CPU/GPU mask.
@export var origin:=Vector2.ZERO
@export var curve_amplitude_a:=3.0
@export var curve_frequency_a:=.065
@export var curve_amplitude_b:=1.2
@export var curve_frequency_b:=.17
@export var inner_width:=1.6
@export var outer_width:=2.6
@export var ends:=Vector4(-96,-88,5,10)
func valid() -> bool:
 return origin.is_finite() and is_finite(curve_amplitude_a) and is_finite(curve_frequency_a) and is_finite(curve_amplitude_b) and is_finite(curve_frequency_b) and is_finite(inner_width) and is_finite(outer_width) and inner_width>0 and outer_width>inner_width and ends.is_finite() and ends.x<ends.y and ends.y<ends.z and ends.z<ends.w
func x_at(z:float) -> float:
 z-=origin.y
 return origin.x+curve_amplitude_a*sin(-z*curve_frequency_a)+curve_amplitude_b*sin(-z*curve_frequency_b)
func mask(point:Vector2) -> float:
 return (1.0-smoothstep(inner_width,outer_width,absf(point.x-x_at(point.y))))*smoothstep(ends.x,ends.y,point.y-origin.y)*(1.0-smoothstep(ends.z,ends.w,point.y-origin.y))
func apply_material(material:ShaderMaterial) -> void:
 material.set_shader_parameter("trial_path_origin",origin);material.set_shader_parameter("trial_path_curve",Vector4(curve_amplitude_a,curve_frequency_a,curve_amplitude_b,curve_frequency_b))
 material.set_shader_parameter("trial_path_widths",Vector2(inner_width,outer_width));material.set_shader_parameter("trial_path_ends",ends)
