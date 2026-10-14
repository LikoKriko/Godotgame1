extends RefCounted
## One anatomy shared by mesh, skeleton, collisions and every animation.
const HEIGHT_METRES := 1.75
const WEIGHT_KG := 60.0
const BODY_WIDTH := 0.84
const BODY_DEPTH := 0.82
const HEAD_ANCHOR := Vector3(0,48.5,0)
const HEAD_SCALE := Vector3(0.58,0.68,0.65)
const SHOULDER := Vector3(7.6*BODY_WIDTH,45.7,0)
const HIP := Vector3(4.4*BODY_WIDTH,26.9,0)
const FOOT_HALF_WIDTH := 1.8*BODY_WIDTH
const FOOT_GAP := 0.65

static func limb(point: Vector3) -> Vector3:
 return point*Vector3(BODY_WIDTH,1,BODY_DEPTH)

static func head(point: Vector3) -> Vector3:
 return HEAD_ANCHOR+(point-HEAD_ANCHOR)*HEAD_SCALE

static func geometry(point: Vector3,tag: int) -> Vector3:
 return head(point) if tag==3 else limb(point)
