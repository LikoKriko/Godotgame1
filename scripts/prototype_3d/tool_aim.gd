extends RefCounted
## Contact geometry in authoring units. +X is the axe's cutting edge, +Y its shaft.
const TIP := Vector3(11,20,0)
const SUPPORT := 7.25
const MIN_ARM := 8.15
const MAX_ARM := 18.8

static func frame(shaft: Vector3) -> Basis:
 var y := shaft.normalized()
 var x := Vector3.RIGHT-y*y.dot(Vector3.RIGHT)
 if x.length_squared()<0.01: x=Vector3.FORWARD-y*y.dot(Vector3.FORWARD)
 x=x.normalized()
 return Basis(x,y,x.cross(y).normalized())

static func solve(point: Vector3,shoulders: Array,tip: Vector3 = TIP,active: int = 0,two_hands: bool = true) -> Dictionary:
 var center: Vector3 = (shoulders[0]+shoulders[1])*0.5
 var forward := center.direction_to(point)
 if forward.is_zero_approx(): forward=Vector3.BACK
 var up := Vector3.UP-forward*Vector3.UP.dot(forward)
 if up.length_squared()<0.01: up=Vector3.BACK-forward*Vector3.BACK.dot(forward)
 up=up.normalized()
 var best: Dictionary = {}; var best_score := INF
 for roll in [0.0,-0.55,0.55,-1.0,1.0,-1.5,1.5]:
  var plane_up := up.rotated(forward,roll)
  for degrees in range(16,137,2):
   var angle := deg_to_rad(float(degrees))
   var y := forward*sin(angle)+plane_up*cos(angle)
   var x := forward*cos(angle)-plane_up*sin(angle)
   var basis := Basis(x,y,x.cross(y).normalized())
   var grip := point-basis*tip
   var support := grip+y*SUPPORT
   var d0: float = shoulders[active].distance_to(grip)
   var d1: float = shoulders[1-active].distance_to(support)
   if d0<MIN_ARM or d0>MAX_ARM:continue
   if two_hands and (d1<MIN_ARM or d1>MAX_ARM): continue
   # Keep the hands in front of the torso instead of solving through the chest.
   if grip.z<7.0 or support.z<7.0: continue
   var score := pow(degrees-52.0,2)*0.01+absf(roll)*5+absf(d0-d1)*0.2
   # A long one-handed blade can reach the target with its palm almost in
   # the chest. Prefer forward grips so the upper arm clears clothing too.
   if not two_hands:score+=pow(maxf(0,8.0-grip.z),2)*4.0
   if score<best_score:
    best_score=score;best={"grip":grip,"basis":basis,"tip":point,"support":support}
 return best
