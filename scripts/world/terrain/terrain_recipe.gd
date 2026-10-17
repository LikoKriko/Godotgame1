extends Resource
## Compose a terrain part from reusable primitives and existing scene stamps.
const Surface=preload("res://scripts/world/terrain_surface.gd")
const Support=preload("res://scripts/world/terrain_support.gd")
const Stamp=preload("res://scripts/world/terrain/scene_stamp.gd")
const Path=preload("res://scripts/world/terrain/path_profile.gd")
@export var recipe_id:StringName
@export var bounds:=Rect2(-56,-112,112,140)
@export var grid:=.5
@export var edge_blend:=10.0
@export var path:Resource
@export var features:Array[Resource]=[]
@export var stamps:Array[Resource]=[]
@export var support_margin:=.05
@export var support_blend:=.75
func valid() -> bool:
 if recipe_id.is_empty() or not bounds.position.is_finite() or not bounds.size.is_finite() or not bounds.has_area() or not is_finite(grid) or grid<.1 or not is_finite(edge_blend) or edge_blend<=0 or not is_finite(support_margin) or support_margin<0 or not is_finite(support_blend) or support_blend<=0 or not path is Path or not path.valid():return false
 for feature in features:
  if feature==null or not feature.has_method("sample") or not feature.has_method("valid") or not feature.valid():return false
 for stamp in stamps:
  if not stamp is Stamp or not stamp.valid():return false
 return true
func height(point:Vector2) -> float:
 if not bounds.has_point(point):return 0.0
 var edge:=smoothstep(0.0,edge_blend,minf(minf(point.x-bounds.position.x,bounds.end.x-point.x),minf(point.y-bounds.position.y,bounds.end.y-point.y)))
 var result:=0.0
 for feature in features:result+=feature.sample(point,path)
 return edge*result
func supported_height(point:Vector2,supports:Dictionary={}) -> float:
 var original:=height(point)
 return Support.sample(point,original,supports,support_blend) if bounds.has_point(point) else original
func build_mesh(area:Rect2,supports:Dictionary={}) -> ArrayMesh:
 return Surface.build_mesh(area,supported_height.bind(supports),grid)
