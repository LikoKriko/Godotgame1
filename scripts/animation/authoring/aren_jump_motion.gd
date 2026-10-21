extends RefCounted
## Voluntary jump timing. Preview flight remains ballistic, with no gameplay hook.
const PREPARE=.50
const PUSH=.105
const LEAD_IN=.55
const RECOVER=.34
const SETTLE=.65
const LAUNCH_SPEED=3.8
const GRAVITY=9.8
const AIR_ACCELERATION=2.5
const PHASES=["Preparación","Impulso","Ascenso","Fase aérea","Descenso","Recuperación provisional"]
const RECIPES=["idle_to_jump","walk_to_jump","run_to_jump","jump_to_idle","jump_to_walk","jump_to_run","jump_transitions"]
const LABELS=["Reposo → Salto","Caminata → Salto","Carrera → Salto","Salto → Reposo","Salto → Caminata","Salto → Carrera","Saltos encadenados"]
const CHAIN=["idle_to_jump","jump_to_walk","walk_to_jump","jump_to_run","run_to_jump","jump_to_idle"]
static func smooth5(value:float) -> float:
 var u:=clampf(value,0,1)
 return u*u*u*(u*(u*6-15)+10)
static func flight_duration() -> float:return 2*LAUNCH_SPEED/GRAVITY
static func apex_time() -> float:return PREPARE+PUSH+LAUNCH_SPEED/GRAVITY
static func duration() -> float:return PREPARE+PUSH+flight_duration()
static func preview(seconds:float,horizontal_speed:float) -> Dictionary:
 var t:=clampf(seconds,0,duration())
 var air:=maxf(0,t-PREPARE-PUSH)
 var velocity:=LAUNCH_SPEED-GRAVITY*air
 var grounded:=t<=PREPARE+PUSH
 var phase:=0 if t<PREPARE else 1
 if not grounded:phase=2 if velocity>.8 else (3 if velocity>-.8 else 4)
 return {"time":t,"phase":phase,"grounded":grounded,"air_time":air,
  "vertical_velocity":0.0 if grounded else velocity,
  "height":maxf(0,LAUNCH_SPEED*air-.5*GRAVITY*air*air),
  "distance":horizontal_speed*t,"finished":seconds>=duration()}
static func phase_time(index:int) -> float:
 return [PREPARE*.72,PREPARE+PUSH*.65,PREPARE+PUSH+.15,
  apex_time(),duration()-.10,duration()+RECOVER*.45][index]
static func preview_duration(name:String) -> float:
 if name.ends_with("_to_jump"):return LEAD_IN+apex_time()
 if name.begins_with("jump_to_"):return flight_duration()*.5+RECOVER+SETTLE
 return LEAD_IN+duration()+RECOVER+SETTLE
static func steer(velocity:Vector3,intent:Vector3,delta:float) -> Vector3:
 var horizontal:=Vector3(velocity.x,0,velocity.z)
 var target:=Vector3(intent.x,0,intent.z)
 if target.length_squared()>.000001:horizontal=horizontal.move_toward(target,AIR_ACCELERATION*maxf(0,delta))
 return Vector3(horizontal.x,velocity.y,horizontal.z)
