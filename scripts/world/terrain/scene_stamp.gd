extends Resource
## Reuse an existing scene without editing its mesh, textures or rig.
@export var stamp_id:StringName
@export var scene:PackedScene
@export var position:=Vector2.ZERO
@export var rotation_degrees:=0.0
@export var scale:=Vector3.ONE
@export var footprint:=Vector2.ONE
func valid() -> bool:
 return not stamp_id.is_empty() and scene!=null and position.is_finite() and is_finite(rotation_degrees) and scale.is_finite() and minf(scale.x,minf(scale.y,scale.z))>0 and footprint.is_finite() and footprint.x>0 and footprint.y>0
func reserved_area(margin:float=.05) -> Rect2:
 var angle:=deg_to_rad(rotation_degrees)
 var half:=footprint*Vector2(scale.x,scale.z)*.5
 var extent:=Vector2(absf(cos(angle))*half.x+absf(sin(angle))*half.y,absf(sin(angle))*half.x+absf(cos(angle))*half.y)
 var padding:=maxf(footprint.x*scale.x,footprint.y*scale.z)*margin
 return Rect2(position-extent-Vector2.ONE*padding,(extent+Vector2.ONE*padding)*2)
