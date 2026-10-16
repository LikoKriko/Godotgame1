extends SceneTree
const Geometry=preload("res://scripts/prototype_3d/tree_geometry.gd")
const TreeModel=preload("res://scripts/prototype_3d/tree_model.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var shapes:Dictionary={};var vertex_count:=0;var started:=Time.get_ticks_usec()
 for design in 9:
  var builder:=Geometry.new();var mesh:=builder.build(design,0);var repeat:=Geometry.new().build(design,0)
  var arrays:Array=mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
  vertex_count+=vertices.size()
  require(vertices.to_byte_array()==repeat.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array(),"A tree regenerated from the same shape and variation is identical")
  shapes[hash(vertices)]=true
  var finite:=true;var valid_normals:=true;var bark_count:=0;var leaf_count:=0
  for i in vertices.size():
   finite=finite and vertices[i].is_finite() and uv[i].is_finite()
   valid_normals=valid_normals and absf(normals[i].length()-1)<0.001
   if tags[i].x>.5:leaf_count+=1
   else:bark_count+=1
  require(finite and valid_normals,"Tree surfaces have finite geometry, UVs and unit normals")
  require(bark_count>3000 and leaf_count>10000,"Each shape contains real branches, roots and individual leaf geometry")
  require(mesh.get_surface_count()==1,"Wood and leaves share one draw surface")
  var bounds: AABB=mesh.get_aabb()
  require(absf(bounds.end.y-Geometry.HEIGHTS[design])<0.0001,"Each shape retains its canonical height")
  require(bounds.position.y<0.03 and bounds.position.y>-.12,"Root contacts meet the ground instead of floating")
  require(bounds.size.z/bounds.size.x>.5,"The side view has real crown depth, not a flat extrusion")
  for direction in 16:
   var axis:=Vector3(cos(direction*TAU/16),0,sin(direction*TAU/16))
   var low:=INF;var high:float=-INF
   for point in vertices:
    var p:float=point.dot(axis);low=minf(low,p);high=maxf(high,p)
   require(high-low>Geometry.HEIGHTS[design]*.24,"Every viewing direction retains a substantial silhouette")
 require(shapes.size()==9,"All nine uploaded silhouettes are distinct")
 require(absf(Geometry.HEIGHTS[5]-1.75*1.05)<0.00001,"Sixth tree stays five percent taller than the survivor")
 for design in 9:
  var first:Mesh
  for variation in 4:
   var tree:=TreeModel.new();tree.design_id=design;tree.variant_id=variation;root.add_child(tree)
   var visual:MeshInstance3D=tree.crown.get_child(0)
   require(visual.mesh.get_surface_count()==1 and tree.crown.get_child_count()==1,"Tree instances use the single cached mesh")
   var again:=TreeModel.new();again.design_id=design;again.variant_id=variation+4;root.add_child(again)
   require(again.crown.get_child(0).mesh==visual.mesh,"Equivalent variations reuse mesh/material resources")
   if variation==0:first=visual.mesh
   else:require(first!=visual.mesh,"Subtle leaf/root variants have independent deterministic shapes")
   require(tree.hit() and tree.hit() and tree.hit() and tree.health==0,"Harvesting retains three hits")
   var active:=tree.collision_layer!=0
   for child in tree.get_children():
    if child is CollisionObject3D:active=active or child.collision_layer!=0
   require(not active and not tree.visible and not tree.hit(),"A felled tree has no active walking/camera collider or duplicate rewards")
   tree.free();again.free()
 require(TreeModel.mesh_cache.size()==36,"Shared tree geometry cache is bounded at 36 reference variants")
 for name in ["bark","leaves"]:
  var texture:Texture2D=TreeModel.material().get_shader_parameter(name)
  require(texture.get_width()==512 and texture.get_height()==512 and texture.get_image().has_mipmaps(),"Own pixel textures have high resolution and distant mip levels")
 print("%s: %d tree shape, 360-degree volume, physics, cache and texture checks; %d base vertices, %.1f ms"%["PASS" if failures==0 else "FAIL",checks,vertex_count,(Time.get_ticks_usec()-started)/1000.0]);quit(1 if failures else 0)
