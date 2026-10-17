extends Resource
## Low bumps and ruts limited to the path rather than scattered through the world.
@export var amplitude:=.1
@export var frequency_z:=1.1
@export var frequency_x:=.8
@export var shear:=.4
@export var fade_distances:=Vector2(5,12)
func valid() -> bool:return is_finite(amplitude) and is_finite(frequency_z) and is_finite(frequency_x) and is_finite(shear) and fade_distances.is_finite() and fade_distances.x<fade_distances.y
func sample(point:Vector2,path:Resource) -> float:
 var local:Vector2=point-path.origin
 return amplitude*sin(local.y*frequency_z)*sin(local.x*frequency_x+local.y*shear)*path.mask(point)*smoothstep(fade_distances.x,fade_distances.y,-local.y)
