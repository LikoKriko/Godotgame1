extends RefCounted
## Shared authoring/runtime dimensions, in the survivor's 64-unit space.
const STRIDE_LENGTH:=1.10
const WALK_SUPPORT:=.25
const WALK_HALF_STRIDE:=8.8
const WALK_FOOT_LIFT:=2.8
const WALK_HIP_HEIGHT:=29.8
const RUN_SUPPORT:=.22
const RUN_HALF_STRIDE:=8.58
const RUN_FOOT_LIFT:=5.6
const RUN_HIP_HEIGHT:=29.8
const WALK_KNEE_SPREAD:=1.10
const RUN_KNEE_SPREAD:=WALK_KNEE_SPREAD*1.20
const WALK_LEAN:=deg_to_rad(4.0)
const WALK_SPINE_LEAN:Array[float]=[.40,.60,.80]
const DIAGONAL_TORSO_TURN:=deg_to_rad(20.0)
const DIAGONAL_TORSO_RESPONSE:=14.0
const RUN_LEAN:=deg_to_rad(7.2)
const RUN_SPINE_LEAN:Array[float]=[2.0/6.2,3.4/6.2,4.8/6.2]
const RUN_BACK_CURVE:=deg_to_rad(2.0)
# Cumulative rotations: each back bone adds one third; neck/head follow.
const RUN_BACK_CURVE_SHARES:Array[float]=[1.0/3.0,2.0/3.0,1.0]
const DIAGONAL_TORSO_SPEED:=deg_to_rad(120.0)
const HIP_MOTION:=.45
const HIP_REDUCTION:=.40
const TORSO_YAW:=deg_to_rad(3.0)
const RUN_TORSO_YAW:=deg_to_rad(7.0)
const PELVIS_YAW:=.025
const RUN_TWIST_SCALE:=2.0
const HEAD_TWIST_SHARE:=.25
const WALK_HEAD_EXTRA:=deg_to_rad(1.0)
const RUN_HEAD_EXTRA:=deg_to_rad(2.0)

# Rearward travel is slower without playing the whole gait in slow motion.
const BACKWARD_SPEED:=.30
const BACKWARD_CADENCE:=.80
const DIAGONAL_ANGLE:=deg_to_rad(35.0)
static func head_twist(torso_yaw:float,sprint_weight:float=0.0) -> float:
 var weight:=clampf(sprint_weight,0,1)
 var amplitude:=lerpf(TORSO_YAW,RUN_TORSO_YAW,weight)
 var extra:=lerpf(WALK_HEAD_EXTRA,RUN_HEAD_EXTRA,weight)
 # Reuse the reduced chest curve so the added head motion shares its phase.
 return torso_yaw*(HEAD_TWIST_SHARE+extra/amplitude)
static func backward_weight(direction:Vector3) -> float:
 return smoothstep(0,.35,-direction.normalized().z)
static func backward_stride(direction:Vector3) -> float:
 var weight:=backward_weight(direction)
 return lerpf(1,BACKWARD_SPEED,weight)/lerpf(1,BACKWARD_CADENCE,weight)
static func backward_speed(direction:Vector3) -> float:
 return lerpf(1,BACKWARD_SPEED,backward_weight(direction))
