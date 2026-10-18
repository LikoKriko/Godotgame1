extends RefCounted
## Fixed-length native fingers wrap the actual shaft, with opposing thumb.
const PROFILE=preload('res://data/animation/characters/hand_grips.tres')
var fingers:Array=[]
var shafts:Dictionary=PROFILE.get_meta('shafts')
func configure(native:RefCounted) -> void:
 for side in 2:
  var label:='Right' if side==0 else 'Left'
  var hand:Array=[]
  for name in ['Index','Middle','Ring','Pinky','Thumb']:
   var chain:Array[int]=[]
   for segment in range(1,5):chain.append(native.binding.names['smartrig_'+label+'Hand'+name+str(segment)])
   hand.append(chain)
  fingers.append(hand)
func palm(family:StringName,side:int,tool:Basis,fallback:Basis) -> Basis:
 var offsets:Dictionary=PROFILE.get_meta('palms',{})
 return tool*offsets[family][side] if offsets.has(family) else fallback
func apply(native:RefCounted,control:RefCounted,pose:Dictionary) -> void:
 var family:StringName=pose.get('family',&'')
 if not shafts.has(family) or pose.get('clip_state',&'')==&'death':return
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
   var surface_radius:float=section.z+(.25 if finger==4 else .30)
   for segment in 3:
    var bone:int=chain[segment];var child:int=chain[segment+1];var parent:int=native.parents[bone]
    var transform:Transform3D=native.posed[parent]*native.inverse_rest[parent]*native.rest[bone]
    var source:Vector3=native.rest[child].origin-native.rest[bone].origin
    var open_delta:Vector3=transform.basis*native.rest[bone].basis.inverse()*source
    var axial:float=clampf(open_delta.dot(shaft),-source.length()*.20,source.length()*.20)
    var perpendicular:=sqrt(maxf(.0001,source.length_squared()-axial*axial))
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
