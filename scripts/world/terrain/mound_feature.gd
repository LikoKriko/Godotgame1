extends Resource
## A smooth hill/mountain primitive; negative height can form a depression.
@export var center:=Vector2(23,-66)
@export var radius:=23.0
@export var height:=8.0
func valid() -> bool:return center.is_finite() and is_finite(radius) and radius>0 and is_finite(height)
func sample(point:Vector2,_path:Resource) -> float:
 return height*pow(maxf(0.0,1.0-point.distance_squared_to(center)/(radius*radius)),2.0)
