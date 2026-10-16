extends RefCounted
## Percentages are visual budgets, never collision or simulation scales.
const DISTANCES:=[30.0,40.0,50.0,65.0,75.0,90.0]
const QUALITY:=[95,90,80,65,45,35]
const TICK:=0.1
const ENEMY_DISTANCE:=150.0
static func distance_percent(distance:float) -> int:
 var result:=100
 for i in DISTANCES.size():
  if distance>=DISTANCES[i]:result=QUALITY[i]
 return result
static func behind(point:Vector3,observer:Vector3,forward:Vector3) -> bool:
 return observer.distance_squared_to(point)>=2500.0 and (point-observer).dot(forward)<0
static func advance(state:Dictionary,distance:float,rear:bool,delta:float) -> int:
 var limit:=distance_percent(distance)
 var target:=mini(limit,50) if rear else limit
 if state.is_empty():
  state.merge({"quality":target,"rear":rear,"recovering":false,"elapsed":0.0})
 else:
  if state.rear and not rear:state.recovering=true;state.elapsed=0.0
  state.rear=rear
  if rear or target<=state.quality:
   state.quality=target;state.elapsed=0.0
   if rear:state.recovering=false
  elif state.recovering:
   state.elapsed+=maxf(0,delta)
   var steps:=int(floor((state.elapsed+0.000001)/TICK))
   state.elapsed-=steps*TICK
   state.quality=mini(target,state.quality+steps*10)
   if state.quality==target:state.recovering=false;state.elapsed=0.0
  else:state.quality=target
 return state.quality
