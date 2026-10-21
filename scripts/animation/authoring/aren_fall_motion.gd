extends RefCounted
const Jump=preload("res://scripts/animation/authoring/aren_jump_motion.gd")
const RECIPES=["idle_to_fall","walk_to_fall","run_to_fall","fall_short","fall_long","fall_sequences"]
const LABELS=["Reposo → Caída","Caminata → Caída","Carrera → Caída","Caída corta","Caída prolongada","Caídas encadenadas"]
const PHASES=["Pérdida de apoyo","Reacción","Caída","Preparar contacto","Recuperación provisional"]
const CHAIN=["idle_to_fall","walk_to_fall","run_to_fall"]
const HEIGHTS=[.55,1.5,3.0,8.0]
const LEAD_IN=.55
const BODY_RELEASE=.22
static func flight_duration(height:float) -> float:return sqrt(2*height/Jump.GRAVITY)
static func height_for(name:String,selected:float) -> float:
 return .55 if name=="fall_short" else (8.0 if name=="fall_long" else selected)
static func gait_for(name:String) -> String:
 if name in ["idle","walk","run"]:return name
 if name.ends_with("_to_fall"):return name.trim_suffix("_to_fall")
 return "walk"
static func phase_time(index:int,height:float) -> float:
 var duration:=flight_duration(height)
 return LEAD_IN+[.035,minf(.19,duration*.65),duration*.60,maxf(.20,duration-.055),duration+recovery_duration(height)*.45][index]

# Relative to the existing provisional contact, not a new landing catalogue.
static func recovery_scale(height:float) -> float:
 if height<=.55:return lerpf(1.0,1.1,clampf(height/.55,0,1))
 if height<=1.5:return lerpf(1.1,1.2,(height-.55)/.95)
 if height<=3.0:return lerpf(1.2,1.3,(height-1.5)/1.5)
 return 1.3
static func recovery_duration(height:float) -> float:return Jump.RECOVER*recovery_scale(height)
static func collapse_pending(height:float) -> bool:return height>=8.0-.001
