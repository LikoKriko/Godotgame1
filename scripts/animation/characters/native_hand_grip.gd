extends RefCounted
## Fixed-length native fingers wrap the actual shaft, with opposing thumb.
const PROFILE=preload('res://data/animation/characters/hand_grips.tres')
const HAND_SCALE:=.90
var fingers:Array=[]
var shafts:Dictionary=PROFILE.get_meta('shafts')
# Relaxed cascade: most flexion belongs to the knuckle and middle joint.
# Keep the distal joints soft, rather than closing an empty fist into the palm.
const RELAXED_DEGREES=[Vector3(16,26,7),Vector3(20,30,9),Vector3(24,34,11),Vector3(28,38,13),Vector3(8,14,7)]
const RELAXED_STATES=[&'idle',&'walk',&'run',&'start',&'stop',&'start_run',&'stop_run',&'equip_walk',&'equip_run']
var relaxed:Dictionary={}
func configure(native:RefCounted) -> void:
 for side in 2:
  var label:='Right' if side==0 else 'Left'
  var hand:Array=[]
  for name in ['Index','Middle','Ring','Pinky','Thumb']:
   var chain:Array[int]=[]
   for segment in range(1,5):chain.append(native.binding.names['smartrig_'+label+'Hand'+name+str(segment)])
   var finger:int=hand.size()
   for segment in 3:
    var bone:int=chain[segment]
    var inward:=Vector3(0,-.6,-.8) if finger==4 else Vector3.DOWN
    var axis:Vector3=native.rest[bone].basis.inverse()*(native.rest[bone].basis.y.normalized().cross(inward)).normalized()
    relaxed[bone]=Basis(axis.normalized(),deg_to_rad(RELAXED_DEGREES[finger][segment]))
   relaxed[chain[3]]=Basis.IDENTITY
   hand.append(chain)
  fingers.append(hand)
func palm(family:StringName,side:int,tool:Basis,fallback:Basis) -> Basis:
 var offsets:Dictionary=PROFILE.get_meta('palms',{})
 return tool*offsets[family][side] if offsets.has(family) else fallback
func apply(native:RefCounted,control:RefCounted,pose:Dictionary) -> void:
 var family:StringName=pose.get('family',&'')
 if not shafts.has(family) or pose.get('clip_state',&'')==&'death':return
 if String(pose.get('clip_state',&'')).begins_with('equip') or pose.get('clip_state',&'')==&'unequip':
  equipment(native,control,pose)
  return
 var shaft:Vector3=pose.shaft.normalized()
 var grip_origin:Vector3=control.posed[6+pose.active*3].origin
 var tool:Basis=pose.get("tool_basis",Basis.IDENTITY)
 for side in 2:
  if native.Clips.arm_is_free(pose,side):continue
  var weight:float=pose.get('equipment_weight',1.0)
  if side!=pose.active:weight*=pose.get('support_weight',1.0)
  var section:Vector3=shafts[family][0 if side==pose.active else 1]
  var center:Vector3=grip_origin+tool.x*section.x+tool.z*section.y
  # The native palm uses one persistent winding around the shaft. Inferring
  # its sign from the changing tool angle can flip every finger mid-strike.
  var curl_sign:=1.0
  for finger in fingers[side].size():
   var chain:Array=fingers[side][finger]
   var direction:float=curl_sign*(-1 if finger==4 else 1)
   var surface_radius:float=section.z+(.25 if finger==4 else .30)*HAND_SCALE
   for segment in 3:
    var bone:int=chain[segment];var child:int=chain[segment+1];var parent:int=native.parents[bone]
    var transform:Transform3D=native.posed[parent]*native.inverse_rest[parent]*native.rest[bone]
    var source:Vector3=native.rest[child].origin-native.rest[bone].origin
    var open_delta:Vector3=transform.basis*native.rest[bone].basis.inverse()*source
    var length:=open_delta.length()
    var axial:float=clampf(open_delta.dot(shaft),-length*.20,length*.20)
    var perpendicular:=sqrt(maxf(.0001,length*length-axial*axial))
    var root_radius:Vector3=transform.origin-center-shaft*(transform.origin-center).dot(shaft)
    var distance:float=maxf(.01,root_radius.length())
    var target_radius:=maxf(surface_radius,distance-perpendicular*.65)
    target_radius=clampf(target_radius,absf(distance-perpendicular)+.001,distance+perpendicular-.001)
    var cosine:=clampf((distance*distance+target_radius*target_radius-perpendicular*perpendicular)/(2*distance*target_radius),-1,1)
    var next_radial:Vector3=root_radius.normalized().rotated(shaft,acos(cosine)*direction)*target_radius
    var desired:Vector3=next_radial-root_radius+shaft*axial
    var rotation:=Basis(Quaternion(open_delta.normalized(),desired.normalized()))*transform.basis
    var blended:=transform.basis.orthonormalized().slerp(rotation.orthonormalized(),clampf(weight,0,1))*Basis.from_scale(transform.basis.get_scale())
    native.posed[bone]=Transform3D(blended,transform.origin)
   var end:int=chain[3];var parent:int=native.parents[end]
   native.posed[end]=native.posed[parent]*native.inverse_rest[parent]*native.rest[end]

func equipment(native:RefCounted,control:RefCounted,pose:Dictionary) -> void:
 # Solve the closed grip at its final contact, then blend native local joints.
 # Solving around a shaft while the wrist is still travelling towards it
 # lets the finger roots cross the shaft axis and suddenly reverse the curl.
 var actual:Array[Transform3D]=[]
 var tool:Basis=pose.get('tool_basis',Basis.IDENTITY)
 var origin:Vector3=control.posed[6+pose.active*3].origin
 for side in 2:
  var hand:int=native.arms[side].ids[3]
  actual.append(native.posed[hand])
  if native.Clips.arm_is_free(pose,side):continue
  var facing:=palm(pose.family,side,tool,Basis.IDENTITY)
  var contact:Vector3=origin
  if side!=pose.active:contact+=pose.shaft*native.Clips.Profiles.profile(pose.family).get('support',0.0)
  var wrist:Vector3=contact-facing*native.arms[side].palm*native.arms[side].contact*HAND_SCALE
  native.posed[hand]=Transform3D(facing*native.arms[side].palm*native.rest[hand].basis*HAND_SCALE,wrist)
 var closed:=pose.duplicate()
 closed.clip_state=&'idle';closed.equipment_weight=1.0;closed.support_weight=1.0
 apply(native,control,closed)
 var targets:Dictionary={}
 for side in 2:
  if native.Clips.arm_is_free(pose,side):continue
  for chain in fingers[side]:
   for bone in chain:targets[bone]=native.posed[native.parents[bone]].basis.inverse()*native.posed[bone].basis
 for side in 2:
  native.posed[native.arms[side].ids[3]]=actual[side]
  if native.Clips.arm_is_free(pose,side):continue
  var weight:float=pose.get('equipment_weight',1.0)*(pose.get('support_weight',1.0) if side!=pose.active else 1.0)
  for chain in fingers[side]:
   for bone in chain:
    var parent:int=native.parents[bone]
    var local:Transform3D=native.inverse_rest[parent]*native.rest[bone]
    local.basis=local.basis.orthonormalized().slerp((targets[bone] as Basis).orthonormalized(),clampf(weight,0,1))*Basis.from_scale(local.basis.get_scale())
    native.posed[bone]=native.posed[parent]*local
