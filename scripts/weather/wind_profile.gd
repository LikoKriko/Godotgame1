extends Resource
## Metres, seconds and world-space direction; shared by future foliage/hair/
## cloth consumers. The field is global; only its visible streaks are local.
@export var direction:=Vector3.FORWARD
@export var base_speed:=0.55
@export var gust_speed:=0.20
@export var gust_period:=7.0
@export var gust_wavelength:=16.0
@export var response_amplitude:=0.015
@export var visible_radius:=10.0
@export var particle_count:=18
@export var particle_lifetime:=3.5
@export var streak_length:=0.65
@export var streak_width:=0.012
@export var opacity:=0.018
@export var tint:=Color(0.78,0.82,0.80)
func gust_at(position:Vector3,time:float) -> float:
 var phase:float=(position.dot(direction.normalized())/gust_wavelength-time/gust_period)*TAU
 var wave:float=0.5+0.5*sin(phase)
 return wave*wave*wave
func velocity_at(position:Vector3,time:float) -> Vector3:
 return direction.normalized()*(base_speed+gust_speed*gust_at(position,time))
