extends RefCounted
## One anatomy shared by mesh, skeleton, collisions and every animation.
const HEIGHT_METRES := 1.75
const WEIGHT_KG := 60.0
# Leg lengths measured against the user-supplied Meshy body at 64 author units.
const THIGH := 14.5
const SHIN := 14.5
const BODY_WIDTH := 0.84
const BODY_DEPTH := 0.82
const MOUTH := Vector3(0,54.4,7.0)
const HEAD_ANCHOR := Vector3(0,52,0)
const SHOULDER := Vector3(6.2,48,1.3)
const HIP := Vector3(3.6,31,0)
const FOOT_HALF_WIDTH := 2.3*BODY_WIDTH
const FOOT_GAP := 0.65

static func limb(point: Vector3) -> Vector3:
 return point*Vector3(BODY_WIDTH,1,BODY_DEPTH)

# Immutable joint seeds shipped with the imported skin. Rest geometry must not
# depend on an editable idle animation, breathing phase or IK clearance pass.
static var bind_seeds:Array=[]
static func bind_pose() -> Dictionary:
 if bind_seeds.is_empty():bind_seeds=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/prototype_3d/meshy/rig_seeds.json"))
 var arms:Array=[];var legs:Array=[];var shoulders:Array=[];var hands:Array=[]
 for side in 2:
  for kind in 2:
   var start:=4+side*3 if kind==0 else 10+side*3
   var points:Array[Vector3]=[]
   for index in range(start,start+3):
    var point:Array=bind_seeds[index].a
    points.append(Vector3(point[0],point[1],point[2]))
   var chain:Dictionary={"root":points[0],"joint":points[1],"end":points[2],"pitch":0.0}
   if kind==0:arms.append(chain);shoulders.append(points[0]);hands.append(points[2])
   else:legs.append(chain)
 return {"body":Transform3D.IDENTITY,"arms":arms,"legs":legs,"shoulders":shoulders,"hands":hands,"family":&"","clip_state":&"idle"}
