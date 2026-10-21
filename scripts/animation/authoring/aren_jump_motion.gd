extends RefCounted
## Voluntary jump timing shared by authoring and future physics consumers.
## Air poses consume measured vertical velocity; this preview is ballistic only.
const PREPARE=.18
const PUSH=.12
const LAUNCH_SPEED=3.6
const GRAVITY=9.8
const AIR_ACCELERATION=2.5
const CONTACT_MARGIN=.025
const PHASES=["Preparación","Impulso","Ascenso","Fase aérea","Descenso"]
static func smooth5(value:float) -> float:
 var u:=clampf(value,0,1)
 return u*u*u*(u*(u*6-15)+10)
static func flight_duration() -> float:
 return (LAUNCH_SPEED+sqrt(LAUNCH_SPEED*LAUNCH_SPEED-2*GRAVITY*CONTACT_MARGIN))/GRAVITY
static func duration() -> float:return PREPARE+PUSH+flight_duration()
static func preview(seconds:float,horizontal_speed:float) -> Dictionary:
 var t:=clampf(seconds,0,duration())
 var air:=maxf(0,t-PREPARE-PUSH)
 var velocity:=LAUNCH_SPEED-GRAVITY*air
 var grounded:=t<PREPARE+PUSH
 var phase:=0 if t<PREPARE else 1
 if not grounded:phase=2 if velocity>.8 else (3 if velocity>-.8 else 4)
 return {"time":t,"phase":phase,"grounded":grounded,"air_time":air,
  "vertical_velocity":0.0 if grounded else velocity,
  "height":0.0 if grounded else LAUNCH_SPEED*air-.5*GRAVITY*air*air,
  "distance":horizontal_speed*t,"finished":seconds>=duration()}
static func phase_time(index:int) -> float:
 return [PREPARE*.7,PREPARE+PUSH*.65,PREPARE+PUSH+.12,
  PREPARE+PUSH+LAUNCH_SPEED/GRAVITY,duration()-.04][index]
static func steer(velocity:Vector3,intent:Vector3,delta:float) -> Vector3:
 # Vertical motion belongs to CharacterBody3D; preserve momentum with no input.
 var horizontal:=Vector3(velocity.x,0,velocity.z)
 if intent.length_squared()>.000001:
  horizontal=horizontal.move_toward(intent,AIR_ACCELERATION*maxf(0,delta))
 return Vector3(horizontal.x,velocity.y,horizontal.z)
