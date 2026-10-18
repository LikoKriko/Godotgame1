extends Resource
## Painted, natural daylight palette. One shared clock controls both the lights
## and the inexpensive background; no additional light or shadow pass is added.
@export var noon_sun:=Color(1.0,0.975,0.93)
@export var low_sun:=Color(1.0,0.73,0.49)
@export var sun_energy:=1.02
@export var noon_fill:=Color(0.80,0.86,0.92)
@export var low_fill:=Color(0.56,0.57,0.63)
@export var fill_energy:=0.55
@export var sky_zenith:=Color(0.28,0.46,0.66)
@export var sky_horizon:=Color(0.68,0.78,0.82)
@export var twilight_horizon:=Color(0.69,0.49,0.38)
@export var haze_begin:=35.0
@export var haze_end:=220.0
@export var haze_opacity:=0.12
func sample(daylight:Dictionary,night_background:Color) -> Dictionary:
 var elevation:float=daylight.elevation
 var morning:float=smoothstep(0,0.12,elevation)
 var clear:float=smoothstep(0.10,0.65,elevation)
 var horizon:=night_background.lerp(twilight_horizon,morning).lerp(sky_horizon,clear)
 return {"sun_color":low_sun.lerp(noon_sun,smoothstep(0,0.60,elevation)),"sun_energy":elevation*sun_energy,
 "ambient":Color(0.19,0.235,0.34).lerp(low_fill,morning).lerp(noon_fill,clear),"ambient_energy":lerpf(0.32,fill_energy,elevation),
 "zenith":(night_background*Color(0.58,0.58,0.58,1)).lerp(sky_zenith,smoothstep(0,0.60,elevation)),"horizon":horizon,
 "haze_color":horizon,"haze_opacity":haze_opacity*smoothstep(0,0.3,elevation)}
