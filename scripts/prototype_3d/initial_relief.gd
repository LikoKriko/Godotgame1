extends RefCounted
## Local, metre-based prototype. Outside this rectangle the world remains flat.
const RECIPE=preload("res://data/world/recipes/initial_relief.tres")
static var AREA:Rect2=RECIPE.bounds
static var GRID:float=RECIPE.grid
static var SUPPORT_MARGIN:float=RECIPE.support_margin
static var SUPPORT_BLEND:float=RECIPE.support_blend
const Catalog=preload("res://scripts/prototype_3d/story_zone_catalog.gd")
static func path_x(z:float) -> float:return RECIPE.path.x_at(z)
static func path_mask(p:Vector2) -> float:return RECIPE.path.mask(p)
static func base_height(p:Vector2) -> float:return RECIPE.height(p)
static func support_radius(record:Dictionary) -> float:
 # Ground-contact footprint: roots, rock silhouette, or plant stem/leaf support.
 if record.kind==2:return record.height*.28
 if record.kind==1:return 1.5
 return .47 if record.kind==4 else .32
static func prepare_supports(records:Array) -> Dictionary:
 return preload("res://scripts/world/terrain_support.gd").build(records,base_height,support_radius,AREA,SUPPORT_MARGIN,SUPPORT_BLEND)
static func height(p:Vector2,supports:Dictionary={}) -> float:
 var original:=base_height(p)
 if not AREA.has_point(p):return original
 return preload("res://scripts/world/terrain_support.gd").sample(p,original,supports,SUPPORT_BLEND)
static func normal(p:Vector2,supports:Dictionary={}) -> Vector3:
 return preload("res://scripts/world/terrain_surface.gd").normal_at(p,height.bind(supports))
static func geometry(area:Rect2,supports:Dictionary={}) -> ArrayMesh:
 return preload("res://scripts/world/terrain_surface.gd").build_mesh(area,height.bind(supports),GRID)
static func install_collision(parent:Node3D,bounds:Rect2,supports:Dictionary={}) -> void:
 # Reserve the full footprint, including the blending border, against story zones.
 assert(not Catalog.new().intersects(AREA),"Initial relief overlaps a fixed story reservation")
 var areas:=[Rect2(bounds.position,Vector2(AREA.position.x-bounds.position.x,bounds.size.y)),Rect2(Vector2(AREA.end.x,bounds.position.y),Vector2(bounds.end.x-AREA.end.x,bounds.size.y)),Rect2(Vector2(AREA.position.x,bounds.position.y),Vector2(AREA.size.x,AREA.position.y-bounds.position.y)),Rect2(Vector2(AREA.position.x,AREA.end.y),Vector2(AREA.size.x,bounds.end.y-AREA.end.y))]
 for area:Rect2 in areas:
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(area.size.x,.4,area.size.y);shape.shape=box;shape.position=Vector3(area.get_center().x,-.2,area.get_center().y);parent.add_child(shape)
 var patch:=CollisionShape3D.new();patch.name="InitialReliefCollision";patch.shape=geometry(AREA,supports).create_trimesh_shape();patch.position=Vector3(AREA.get_center().x,0,AREA.get_center().y);parent.add_child(patch)
static func clear_of_path(p:Vector2,radius:float) -> bool:
 if p.y+radius< -96.0 or p.y-radius>10.0:return true
 # Conservative footprint clearance, including the maximum sideways curve rate.
 return absf(p.x-path_x(p.y))>2.6+radius*1.5
