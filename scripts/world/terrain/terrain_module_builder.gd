extends RefCounted
## Authoring/preview builder; live worlds stream the same recipe through chunks.
const Terrain=preload("res://scripts/prototype_3d/terrain_chunks.gd")
const Support=preload("res://scripts/world/terrain_support.gd")
const Recipe=preload("res://scripts/world/terrain/terrain_recipe.gd")
const Stamp=preload("res://scripts/world/terrain/scene_stamp.gd")
const Profile=preload("res://scripts/terrain_profile.gd")
var errors:Array[String]=[]
func build(recipe:Resource,profile:Resource,catalog,world_bounds:Rect2,seed_value:int=73129) -> Node3D:
 errors.clear()
 if not recipe is Recipe or not recipe.valid():errors.append("Invalid terrain recipe");return null
 if not profile is Profile or not profile.valid():errors.append("Invalid terrain/biome profile");return null
 if maxf(recipe.bounds.size.x,recipe.bounds.size.y)>512:errors.append("Author one terrain part at a time (maximum 512 metres per side)");return null
 if catalog==null or not catalog.has_method("intersects"):errors.append("A story reservation catalogue is required");return null
 if not world_bounds.encloses(recipe.bounds) or catalog.intersects(recipe.bounds):errors.append("Terrain footprint overlaps a story reservation or world boundary");return null
 # Validate every full rotated/scaled footprint before allocating scene objects.
 var ids:Dictionary={};var records:Array=[]
 for stamp:Resource in recipe.stamps:
  var footprint:Rect2=stamp.reserved_area(recipe.support_margin)
  if ids.has(stamp.stamp_id) or not recipe.bounds.encloses(footprint) or catalog.intersects(footprint):errors.append("Invalid or protected stamp footprint: "+String(stamp.stamp_id));return null
  ids[stamp.stamp_id]=true
  records.append({"position":Vector3(stamp.position.x,0,stamp.position.y),"radius":(stamp.footprint*Vector2(stamp.scale.x,stamp.scale.z)).length()*.5})
 var supports:=Support.build(records,recipe.height,func(record:Dictionary)->float:return record.radius,recipe.bounds,recipe.support_margin,recipe.support_blend)
 var result:=Node3D.new();result.name=String(recipe.recipe_id);result.set_meta("terrain_recipe",recipe.recipe_id)
 var paint:=Terrain.new();paint.use_mask_cache=false;paint.relief_enabled=true;paint.path_definition=recipe.path
 if not paint.configure(seed_value,profile,Rect2(recipe.bounds.position/Terrain.METRES_PER_UNIT,recipe.bounds.size/Terrain.METRES_PER_UNIT)):paint.free();result.free();errors.append("Terrain textures unavailable");return null
 # Keep exported parts chunk-sized, with shared mathematical height seams.
 var first:=Vector2i(floori(recipe.bounds.position.x/28),floori(recipe.bounds.position.y/28))
 var last:=Vector2i(ceili(recipe.bounds.end.x/28),ceili(recipe.bounds.end.y/28))
 for z in range(first.y,last.y):
  for x in range(first.x,last.x):
   var area:=Rect2(Vector2(x,z)*28,Vector2.ONE*28).intersection(recipe.bounds)
   var mesh:ArrayMesh=recipe.build_mesh(area,supports)
   if mesh==null:paint.free();result.free();errors.append("Recipe exceeds safe meshing limits");return null
   var body:=StaticBody3D.new();result.add_child(body);body.owner=result;body.position=Vector3(area.get_center().x,0,area.get_center().y)
   var visual:=MeshInstance3D.new();body.add_child(visual);visual.owner=result;visual.mesh=mesh;visual.set_meta("streamed_terrain",true)
   visual.material_override=paint.material_for(Rect2(area.position/Terrain.METRES_PER_UNIT,area.size/Terrain.METRES_PER_UNIT))
   var collision:=CollisionShape3D.new();body.add_child(collision);collision.owner=result;collision.shape=mesh.create_trimesh_shape()
 for stamp:Resource in recipe.stamps:
  var instance:Node=stamp.scene.instantiate()
  if not instance is Node3D:instance.free();paint.free();result.free();errors.append("Scene stamp must have a Node3D root");return null
  result.add_child(instance);instance.owner=result;instance.set_meta("terrain_stamp_id",stamp.stamp_id)
  instance.position=Vector3(stamp.position.x,recipe.supported_height(stamp.position,supports),stamp.position.y)
  instance.rotation.y=deg_to_rad(stamp.rotation_degrees);instance.scale=stamp.scale
 paint.free();return result
