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
