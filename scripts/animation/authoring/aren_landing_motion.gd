extends RefCounted
## One continuous reception family. The full collapse at >=8 m is separate.
const Jump=preload("res://scripts/animation/authoring/aren_jump_motion.gd")
const HEIGHTS=[.55,1.5,3.0,3.5,4.0,4.8,5.5,6.0,6.8,7.5,7.9,8.0]
const PHASES=["Contacto de pies","Absorción","Rodilla y palma","Retirar mano","Elevar pelvis y rodilla","Equilibrio"]
static func accepts(height:float) -> bool:return height>=3.0-.001 and height<8.0-.001
static func profile(velocity_y:float) -> Dictionary:
 var speed:=absf(velocity_y)
 var weight:=Jump.smooth5((speed-sqrt(2*Jump.GRAVITY*3))/(sqrt(2*Jump.GRAVITY*8)-sqrt(2*Jump.GRAVITY*3)))
 return {"intensity":weight,"duration":1.8+.7*Jump.smooth5((speed-sqrt(2*Jump.GRAVITY*4))/(sqrt(2*Jump.GRAVITY*8)-sqrt(2*Jump.GRAVITY*4))),"absorb":.29+.07*weight,"hold":.58+.16*weight,"rise_end":1.50+.57*weight,"release":.62+.16*weight,"release_end":.92+.22*weight,"brake":.10+.04*weight,"pelvis_deg":65+2*weight,"spine_deg":Vector3(12,14,8)+Vector3(1,1,1)*weight,"elbow_peak_deg":45+15*weight,"stagger":.24+.025*weight}
static func load_at(time:float,p:Dictionary) -> float:
 if time<p.absorb:return Jump.smooth5(time/p.absorb)
 if time<p.hold:return lerpf(1,.992,Jump.smooth5((time-p.absorb)/(p.hold-p.absorb)))
 return .992*(1-Jump.smooth5((time-p.hold)/(p.rise_end-p.hold)))
static func release_at(time:float,p:Dictionary) -> float:return Jump.smooth5((time-p.release)/(p.release_end-p.release))
static func carry(time:float,p:Dictionary) -> float:
 var u:=clampf(time/p.brake,0,1)
 return p.brake*(u-2.5*pow(u,4)+3*pow(u,5)-pow(u,6))
static func phase_time(index:int,p:Dictionary) -> float:
 return [0.0,p.absorb*.85,(p.absorb+p.release)*.5,(p.release+p.release_end)*.5,p.release_end+(p.rise_end-p.release_end)*.4,p.duration-.12][index]

static func phase_index(time:float,p:Dictionary) -> int:
 if time<=.001:return 0
 if time<p.absorb:return 1
 if time<p.release:return 2
 if time<p.release_end:return 3
 return 4 if time<p.rise_end else 5
