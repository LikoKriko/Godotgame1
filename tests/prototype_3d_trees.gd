extends SceneTree
const Geometry=preload("res://scripts/prototype_3d/tree_geometry.gd")
const TreeModel=preload("res://scripts/prototype_3d/tree_model.gd")
const FOLDER:="res://assets/models/meshy/twisted_oak/"
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var provenance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"source.json"))
 require(FileAccess.get_sha256("res://"+provenance.source_fbx)==provenance.fbx_sha256,"Delivered FBX remains intact")
 for category in ["textures_sha256","derived_textures_sha256"]:
  for key:String in provenance[category]:require(FileAccess.get_sha256(FOLDER+key+".png")==provenance[category][key],"Runtime bark maps match their source/authoring manifest: "+key)
 var controls:Dictionary=Geometry.CONTROLS.data
 var primaries:Array=[];var secondary_counts:Dictionary={};var twig_counts:Dictionary={};var all:Dictionary={}
 for branch:Dictionary in controls.branches:
  all[int(branch.id)]=branch
  var level:=int(branch.level)
  require(level in [0,1,2,3],"Only the leader and the requested three branch levels exist")
  if level==0:continue
  var parent:Dictionary=all[int(branch.parent)]
  require(int(parent.level)==level-1,"Every branch has a parent in the preceding level")
  if level==1:primaries.append(branch);secondary_counts[int(branch.id)]=0
  elif level==2:secondary_counts[int(branch.parent)]+=1;twig_counts[int(branch.id)]=0
  else:twig_counts[int(branch.parent)]+=1
  var points:Array=branch.points
  var first:=(Geometry.point(points[1])-Geometry.point(points[0])).normalized()
  var last:=(Geometry.point(points[-1])-Geometry.point(points[-2])).normalized()
  var limit:float=[0,30,15,5][level]
  require(rad_to_deg(first.angle_to(last))<=limit+.001 and branch.curve_degrees<=limit,"Branch tangent change respects its 30/15/5 degree limit")
  var previous:=first;var length:=0.0
  for i in points.size()-1:
   var a:=Geometry.point(points[i]);var b:=Geometry.point(points[i+1]);var tangent:=(b-a).normalized()
   require(a.is_finite() and b.is_finite() and b.distance_to(a)>0,"No degenerate or non-finite branch segments")
   require(rad_to_deg(previous.angle_to(tangent))<limit*.6,"Bends are distributed smoothly instead of concentrated at one ring")
   previous=tangent;length+=a.distance_to(b)
  require(branch.radii[0]>branch.radii[-1] and float(branch.radii[-1])>0,"Branches taper to finite, visible twigs")
  require(branch.clearance>0,"Offline capsule checks leave clearance outside the embedded fork collars")
  # Its first centre must lie on the actual parent centreline, not float nearby.
  var start:=Geometry.point(points[0]);var distance:=INF
  for i in parent.points.size()-1:
   var a:=Geometry.point(parent.points[i]);var b:=Geometry.point(parent.points[i+1]);var d:=b-a
   distance=minf(distance,start.distance_to(a+d*clampf((start-a).dot(d)/d.length_squared(),0,1)))
  require(distance<.00001,"Every daughter starts inside its parent wood")
 require(primaries.size()>=10 and primaries.size()==15,"The full turn has fifteen main boughs")
 primaries.sort_custom(func(a,b):return a.azimuth_degrees<b.azimuth_degrees)
 for i in primaries.size():
  var gap:float=fposmod(primaries[(i+1)%primaries.size()].azimuth_degrees-primaries[i].azimuth_degrees,360)
  require(gap>=20 and gap<=30,"Main branches are separated by 20–30 degrees, including the wraparound")
 for count:int in secondary_counts.values():require(count>=3 and count<=7,"Each main bough carries 3–7 finer branches")
 for count:int in twig_counts.values():require(count>=2 and count<=3,"Every fine branch carries 2–3 terminal twigs")
 var mesh:=Geometry.SOURCE
 require(mesh.get_surface_count()==2,"Original trunk and transferred bark use two shared material surfaces")
 require(absf(mesh.get_aabb().size.y-1)<.000001 and absf(mesh.get_aabb().position.y)<.000001,"Shared source is one metre tall and rests on the ground")
 require(mesh.get_meta("source_zip_sha256")==provenance.zip_sha256,"Runtime geometry identifies the supplied release")
 var triangles:=0
 for surface in mesh.get_surface_count():
  var arrays:=mesh.surface_get_arrays(surface)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var valid:=true
  for i in points.size():valid=valid and points[i].is_finite() and normals[i].is_finite() and absf(normals[i].length()-1)<.002 and uv[i].is_finite()
  require(valid,"Baked positions, shading normals and UVs are valid")
  triangles+=(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
  var material:Material=mesh.surface_get_material(surface)
  require(material!=null and material.next_pass==null,"Bark uses the supplied painted finish without an extra outline draw")
  var textures:Array=[]
  if material is StandardMaterial3D:
   require(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"Delivered bark has stable filtered detail")
   textures=[material.albedo_texture,material.normal_texture,material.roughness_texture,material.metallic_texture]
  else:
   require(material is ShaderMaterial and material.shader.resource_path=="res://assets/shaders/tree_bark_junction.gdshader","Only the authored leader uses the local bark transition shader")
   var source_uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2];var masks:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
   require(source_uv.size()==points.size() and masks.size()==points.size(),"Leader junction retains its delivered UV projection and blend mask")
   var opaque:=0;var transferred:=0;var blended:=0;var valid_masks:=true
   for i in masks.size():
    valid_masks=valid_masks and source_uv[i].is_finite() and masks[i].a>=0 and masks[i].a<=1
    if masks[i].a>.999:opaque+=1
    elif masks[i].a>.001:blended+=1
    else:transferred+=1
   require(valid_masks and opaque>10 and blended>10 and transferred>1000,"Only a short leader collar blends from source bark to transferred bark")
   var original:=mesh.surface_get_arrays(1)
   var root_points:PackedVector3Array=original[Mesh.ARRAY_VERTEX];var root_uv:PackedVector2Array=original[Mesh.ARRAY_TEX_UV]
   var joined:=true;var bark_covered:=0
   for i in masks.size():
    if masks[i].a<.001 and uv[i].distance_squared_to(Vector2(0,1))>.001:bark_covered+=1
    if masks[i].a<.999:continue
    var found:=false
    for j in root_points.size():
     if points[i].distance_to(root_points[j])<.00002 and source_uv[i].distance_to(root_uv[j])<.001:found=true;break
    joined=joined and found
   require(joined,"Every leader boundary vertex meets the original root position and exact source UV island")
   require(bark_covered>transferred*.9,"UV0 covers all daughter branches; source projection cannot replace the cylinder unwrap")
   var quality=preload("res://scripts/prototype_3d/quality_materials.gd").new()
   var distant:ShaderMaterial=quality.material(material,40)
   var names:Array=[]
   for uniform:Dictionary in distant.shader.get_shader_uniform_list():names.append(str(uniform.name))
   require("distance_quality" in names and distant.get_shader_parameter("albedo_map")==material.get_shader_parameter("albedo_map"),"Shared distance quality compiles the junction shader and retains its bark textures")
   for key in ["albedo","normal","roughness","metallic"]:
    textures.append(material.get_shader_parameter(key+"_map"));textures.append(material.get_shader_parameter("delivered_"+key))
  for texture:Texture2D in textures:require(texture!=null and texture.get_image().has_mipmaps(),"Every bark map has real mip levels")

 require(triangles==int(provenance.runtime_triangles),"All authored triangles are present in the runtime resource")
 for direction in 16:
  var axis:=Vector3(cos(direction*TAU/16),0,sin(direction*TAU/16));var low:=INF;var high:float=-INF
  for surface in mesh.get_surface_count():
   for p:Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
    if p.y<.4:continue
    var value:=p.dot(axis);low=minf(low,value);high=maxf(high,value)
  require(high-low>.3,"Branches retain real crown depth from every viewing angle")
 for design in 9:
  for variant in 4:
   var tree:=TreeModel.new();tree.design_id=design;tree.variant_id=variant;root.add_child(tree)
   var visual:MeshInstance3D=tree.crown.get_child(0)
   require(visual.mesh==mesh and tree.crown.get_child_count()==1,"Every generated tree reuses the same immutable mesh")
   require(absf(visual.get_aabb().size.y*visual.scale.y-Geometry.HEIGHTS[design])<.00001,"Legacy height slots keep exactly their previous heights")
   require(not tree.is_processing(),"Settled trees have no per-frame growth/sway processing")
   var collision_count:=0
   for node in tree.get_children():
    if node is CollisionShape3D:collision_count+=1
   require(collision_count>0 and collision_count<=10,"Trunk collisions use a small, bounded capsule spine")
   require(tree.hit() and tree.is_processing(),"Only a hit wakes visual shake")
   tree._process(.3)
   require(tree.crown.transform.is_equal_approx(tree.base_transform) and not tree.is_processing(),"Shake restores the tree's orientation and suspends processing")
   require(tree.hit() and tree.hit() and tree.health==0 and not tree.hit(),"Harvesting still takes three hits and cannot repeat rewards")
   var active:=tree.collision_layer!=0
   for node in tree.get_children():
    if node is CollisionObject3D:active=active or node.collision_layer!=0
   require(not active and not tree.visible,"Felled trees remove physical, aim and camera collisions")
   tree.free()
 require(Geometry.shape_cache.size()==9,"Physics resources are shared by the nine existing height slots")
 print("%s: %d radial oak hierarchy, bend, texture, volume, height, cache and harvesting checks; %d triangles"%["PASS" if failures==0 else "FAIL",checks,triangles])
 quit(1 if failures else 0)
