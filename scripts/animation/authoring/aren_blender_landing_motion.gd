extends RefCounted
## Whole-pose Blender family, selected by physical vertical impact speed.
const Jump=preload("res://scripts/animation/authoring/aren_jump_motion.gd")
const HEIGHTS=[3.0,3.5,4.0,4.8,5.5,6.0,6.8,7.5,7.9]
const BASE_DURATION=1.8
static func accepts(height:float) -> bool:return height>=3.0 and height<8.0
static func profile(impact_velocity:float) -> Dictionary:
 var low:=sqrt(2*Jump.GRAVITY*3.0)
 var high:=sqrt(2*Jump.GRAVITY*8.0)
 var intensity:=Jump.smooth5((absf(impact_velocity)-low)/(high-low))
 var duration:=BASE_DURATION+.6*intensity
 var scale:=duration/BASE_DURATION
 return {"duration":duration,"scale":scale,"absorb":.20*scale,"release":23.0/60*scale,"release_end":.65*scale,"hold":.42*scale,"rise_end":1.50*scale,"intensity":intensity}
