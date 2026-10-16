extends RefCounted
## Contact geometry in authoring units. +X is the axe's cutting edge, +Y its shaft.
const BodyProfile=preload("res://scripts/prototype_3d/meshy_body_profile.gd")
const TIP := Vector3(11,20,0)
const SUPPORT := 8.25
const MIN_ARM := 8.15
const MAX_ARM := 18.8
# Score order visits the most promising orientation first. Trigonometry is
# immutable; compute it once rather than in every pose and failed weight shift.
static var candidates:Array[Vector4]=build_candidates()
static func build_candidates() -> Array[Vector4]:
 var result:Array[Vector4]=[]
 for sample_roll in 27:
  var roll:float=0.0 if sample_roll==0 else (1.0 if sample_roll%2==0 else -1.0)*ceilf(sample_roll/2.0)*.12
  for degrees in range(16,137,2):
   var angle:=deg_to_rad(float(degrees))
   result.append(Vector4(sin(angle),cos(angle),pow(degrees-52.0,2)*.01+absf(roll)*5,sample_roll*61+(degrees-16)/2))
 result.sort_custom(func(a:Vector4,b:Vector4):return a.z<b.z or (a.z==b.z and a.w<b.w))
 return result

static func frame(shaft: Vector3) -> Basis:
 var y := shaft.normalized()
 var x := Vector3.RIGHT-y*y.dot(Vector3.RIGHT)
 if x.length_squared()<0.01: x=Vector3.FORWARD-y*y.dot(Vector3.FORWARD)
 x=x.normalized()
 return Basis(x,y,x.cross(y).normalized())

const CACHE_LIMIT:=128
static var _solutions:Dictionary={}

static func solve(point: Vector3,shoulders: Array,tip: Vector3 = TIP,active: int = 0,two_hands: bool = true,body:Transform3D=Transform3D.IDENTITY,support_distance:float=SUPPORT,shaft_range:Vector2=Vector2(-4,28)) -> Dictionary:
 # Exact value keys include both shoulder frames and the complete prop profile.
 # Store misses too, and keep entries bounded while the player moves/turns.
 var key:Array=[point,shoulders[0],shoulders[1],tip,active,two_hands,body,support_distance,shaft_range]
 if _solutions.has(key):return _solutions[key].duplicate()
 var result:=search(point,shoulders,tip,active,two_hands,body,support_distance,shaft_range)
 if _solutions.size()>=CACHE_LIMIT:_solutions.clear()
 _solutions[key]=result
 return result.duplicate()

static func search(point:Vector3,shoulders:Array,tip:Vector3,active:int,two_hands:bool,body:Transform3D,support_distance:float,shaft_range:Vector2) -> Dictionary:
 # Necessary reach bounds before trying any orientation: the tip-to-palm
 # distance is invariant under rotation, including the second handle grip.
 # Most distant/low candidates fail here instead of scanning 1647 frames.
 var reach:=MAX_ARM+tip.length()
 if shoulders[active].distance_squared_to(point)>reach*reach:return {}
 if two_hands:
  var support_reach:=MAX_ARM+(tip-Vector3(0,support_distance,0)).length()
  if shoulders[1-active].distance_squared_to(point)>support_reach*support_reach:return {}
 var center: Vector3 = (shoulders[0]+shoulders[1])*0.5
 var forward := center.direction_to(point)
 if forward.is_zero_approx(): forward=Vector3.BACK
 var up := Vector3.UP-forward*Vector3.UP.dot(forward)
 if up.length_squared()<0.01: up=Vector3.BACK-forward*Vector3.BACK.dot(forward)
 up=up.normalized()
 var best: Dictionary = {}; var best_score := INF
 var inverse:=body.affine_inverse()
 var skull:=Basis.IDENTITY.slerp(body.basis,.2)
 var skull_inverse:=skull.inverse()
 var head:Vector3=body*Vector3(0,52,0)+skull*Vector3(0,6,2.2)
 var planes:Array[Vector3]=[]
 for sample_roll in 27:
  var roll:float=0.0 if sample_roll==0 else (1.0 if sample_roll%2==0 else -1.0)*ceilf(sample_roll/2.0)*.12
  planes.append(up.rotated(forward,roll))
 var best_rank:=2147483647
 for candidate in candidates:
  if candidate.z>best_score:break
  var rank:=int(candidate.w)
  var plane_up:Vector3=planes[rank/61]
  var y:=forward*candidate.x+plane_up*candidate.y
  var x:=forward*candidate.y-plane_up*candidate.x
  var z:=x.cross(y).normalized()
  var grip:=point-x*tip.x-y*tip.y-z*tip.z
  var support:=grip+y*support_distance
  var d0_squared:float=shoulders[active].distance_squared_to(grip)
  if d0_squared<MIN_ARM*MIN_ARM or d0_squared>MAX_ARM*MAX_ARM:continue
  var d1_squared:float=shoulders[1-active].distance_squared_to(support)
  if two_hands and (d1_squared<MIN_ARM*MIN_ARM or d1_squared>MAX_ARM*MAX_ARM):continue
  if grip.z<7.0 or support.z<7.0:continue
  var score:float=candidate.z+absf(sqrt(d0_squared)-sqrt(d1_squared))*.2
  if not two_hands:score+=pow(maxf(0,8.0-grip.z),2)*4.0
  if score>best_score or (score==best_score and rank>=best_rank):continue
  var clear:=true
  for shaft_sample in 17:
   var along:float=lerpf(shaft_range.x,shaft_range.y,shaft_sample/16.0)
   var shaft_point:Vector3=grip+y*along
   var head_local:Vector3=skull_inverse*(shaft_point-head)
   if (head_local/Vector3(5.1,6.2,6.2)).length_squared()<1.04:clear=false;break
   var local:Vector3=inverse*shaft_point
   if local.y<=31 or local.y>=51:continue
   var section:Vector4=BodyProfile.section(local.y)
   var radial:=Vector2(local.x/section.y,(local.z-(section.z+section.w)*.5)/((section.w-section.z)*.5)).length_squared()
   if radial<1.10:clear=false;break
  if not clear:continue
  best_score=score;best_rank=rank
  best={"grip":grip,"basis":Basis(x,y,z),"tip":point,"support":support}
 return best
