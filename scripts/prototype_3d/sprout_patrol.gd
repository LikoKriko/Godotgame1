extends RefCounted
## Two fixed endpoints, twenty horizontal metres apart. No pursuit or combat.
const DISTANCE:=20.0
const TURN_SECONDS:=.65
var origin:=Vector3.ZERO
var axis:=Vector3.FORWARD
var returning:=false
var turning:=false
var turn_elapsed:=0.0
var turn_start:=0.0
var heading:=0.0
func configure(start:Vector3,direction:Vector3) -> void:
 origin=start;axis=Vector3(direction.x,0,direction.z).normalized()
 if axis.length_squared()<.5:axis=Vector3(0,0,1)
 heading=atan2(axis.x,axis.z)
func target() -> Vector3:return origin if returning else origin+axis*DISTANCE
func remaining(position:Vector3) -> float:
 var offset:=target()-position;offset.y=0;return offset.length()
func direction(position:Vector3) -> Vector3:
 var offset:=target()-position;offset.y=0;return offset.normalized()
func begin_turn() -> void:
 turning=true;turn_elapsed=0;turn_start=heading
func turn(delta:float) -> void:
 turn_elapsed=minf(TURN_SECONDS,turn_elapsed+delta)
 heading=turn_start+PI*smoothstep(0,TURN_SECONDS,turn_elapsed)
 if turn_elapsed>=TURN_SECONDS:
  heading=wrapf(heading,-PI,PI);returning=not returning;turning=false
func snapshot() -> Dictionary:
 return {"origin":[origin.x,origin.y,origin.z],"axis":[axis.x,axis.y,axis.z],"returning":returning,"turning":turning,"turn_elapsed":turn_elapsed,"turn_start":turn_start,"heading":heading}
func restore(data:Dictionary) -> void:
 origin=Vector3(data.origin[0],data.origin[1],data.origin[2]);axis=Vector3(data.axis[0],data.axis[1],data.axis[2])
 returning=data.returning;turning=data.turning;turn_elapsed=data.turn_elapsed;turn_start=data.turn_start;heading=data.heading
