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
 return LEAD_IN+[.035,minf(.19,duration*.65),duration*.60,maxf(.20,duration-.055),duration+Jump.RECOVER*.45][index]
