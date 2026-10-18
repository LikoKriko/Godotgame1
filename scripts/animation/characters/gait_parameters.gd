extends RefCounted
## Shared authoring/runtime dimensions, in the survivor's 64-unit space.
const STRIDE_LENGTH:=1.10
const WALK_SUPPORT:=.25
const WALK_HALF_STRIDE:=8.8
const WALK_FOOT_LIFT:=2.8
const WALK_HIP_HEIGHT:=29.8
const RUN_SUPPORT:=.22
const RUN_HALF_STRIDE:=7.8
const RUN_FOOT_LIFT:=5.6
const RUN_HIP_HEIGHT:=29.8
const WALK_KNEE_SPREAD:=1.10
const WALK_LEAN:=deg_to_rad(3.0)
const WALK_SPINE_LEAN:Array[float]=[.40,.60,.80]
const DIAGONAL_TORSO_TURN:=deg_to_rad(20.0)
const DIAGONAL_TORSO_RESPONSE:=14.0
const RUN_LEAN:=deg_to_rad(6.2)
const RUN_SPINE_LEAN:Array[float]=[2.0/6.2,3.4/6.2,4.8/6.2]
const DIAGONAL_TORSO_SPEED:=deg_to_rad(120.0)
const HIP_MOTION:=.45
const HIP_REDUCTION:=.40
const TORSO_YAW:=deg_to_rad(2.0)
const PELVIS_YAW:=.025
const RUN_TWIST_SCALE:=2.0
const HEAD_TWIST_SHARE:=.25

# Rearward travel is slower without playing the whole gait in slow motion.
const BACKWARD_SPEED:=.30
const BACKWARD_CADENCE:=.80
const DIAGONAL_ANGLE:=deg_to_rad(35.0)
static func backward_weight(direction:Vector3) -> float:
 return smoothstep(0,.35,-direction.normalized().z)
static func backward_stride(direction:Vector3) -> float:
 var weight:=backward_weight(direction)
 return lerpf(1,BACKWARD_SPEED,weight)/lerpf(1,BACKWARD_CADENCE,weight)
static func backward_speed(direction:Vector3) -> float:
 return lerpf(1,BACKWARD_SPEED,backward_weight(direction))
