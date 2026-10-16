extends SceneTree
## Preserve supplied geometry/UVs; author only uniform scale, orientation and anchors.
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args();assert(args.size()==1,"Pass a JSON import manifest")
 var definitions:Array=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 for definition:Dictionary in definitions:bake_one(definition)
 quit()
func bake_one(definition:Dictionary) -> void:
 var provenance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(definition.folder+"source.json"))
 definition["triangles"]=provenance.triangles;definition["zip_sha256"]=provenance.zip_sha256
 var document:=GLTFDocument.new();var state:=GLTFState.new();assert(document.append_from_file(definition.input,state)==OK)
 var scene:=document.generate_scene(state);root.add_child(scene)
 var nodes:=scene.find_children("*","MeshInstance3D",true,false);assert(nodes.size()==1)
 var surface:=SurfaceTool.new();surface.create_from(nodes[0].mesh,0);surface.generate_tangents()
 var arrays:=surface.commit().surface_get_arrays(0)
 var bounds:AABB=nodes[0].mesh.get_aabb();var factor:float=definition.height/bounds.size.y
 var rotation:=Basis(Vector3.UP,PI/2 if definition.id=="bow" else (PI if definition.id=="axe" else 0.0))
 if definition.id=="axe":
  var centers:Array[Vector3]=[]
  for fraction in [.06,.35]:
   var section:=AABB();var first:=true
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    if absf(p.y-(bounds.position.y+bounds.size.y*fraction))>bounds.size.y*.015:continue
    var rotated:=rotation*p
    section=AABB(rotated,Vector3.ZERO) if first else section.expand(rotated);first=false
   centers.append(section.get_center())
  var shaft:=centers[1]-centers[0]
  rotation=Basis(Vector3.BACK,atan2(shaft.x,shaft.y))*rotation
  var rotated_bounds:=AABB();var first:=true
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   var rotated:=rotation*p
   rotated_bounds=AABB(rotated,Vector3.ZERO) if first else rotated_bounds.expand(rotated);first=false
  factor=definition.height/rotated_bounds.size.y
  var section:=AABB();first=true
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   var rotated:=rotation*p
   if absf(rotated.y-(rotated_bounds.position.y+4.0/factor))>rotated_bounds.size.y*.02:continue
   section=AABB(rotated,Vector3.ZERO) if first else section.expand(rotated);first=false
  definition["axe_offset"]=Vector3(-section.get_center().x,-rotated_bounds.position.y,-section.get_center().z)*factor+Vector3.UP*float(definition.bottom)
 var offset:=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor+Vector3.UP*float(definition.bottom)
 if definition.id=="bow":
  # The wooden grip is the centre of the stave, not the string/overall AABB.
  var middle:=AABB();var first:=true
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   if absf(p.y-bounds.get_center().y)>bounds.size.y*.025 or p.x>bounds.get_center().x:continue
   middle=AABB(p,Vector3.ZERO) if first else middle.expand(p);first=false
  offset=-(rotation*middle.get_center())*factor
 if definition.id=="pickaxe":
  var section:=AABB();var first:=true
  var grip_y:float=bounds.position.y+4.0/factor
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   if absf(p.y-grip_y)>bounds.size.y*.02:continue
   section=AABB(p,Vector3.ZERO) if first else section.expand(p);first=false
  var center:=rotation*section.get_center()
  offset.x=-center.x*factor;offset.z=-center.z*factor
 if definition.id=="leaf_armor":offset.z+=2.2
 if definition.id=="axe":offset=definition.axe_offset
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
 for i in points.size():
  points[i]=rotation*points[i]*factor+offset;normals[i]=rotation*normals[i]
  var tangent:=rotation*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
  tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
 arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangents
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var folder:String=definition.folder
 var material:=StandardMaterial3D.new();material.albedo_texture=load(folder+"albedo.png")
 material.normal_enabled=true;material.normal_texture=load(folder+"normal.png")
 material.roughness_texture=load(folder+"roughness.png");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic_texture=load(folder+"metallic.png");material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic=1;material.roughness=1;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 mesh.surface_set_material(0,material)
 assert((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3==int(definition.triangles))
 mesh.set_meta("source_triangles",int(definition.triangles));mesh.set_meta("source_zip_sha256",definition.zip_sha256)
 mesh.set_meta("uniform_scale",factor);mesh.set_meta("translation",offset);mesh.set_meta("rotation",rotation)
 if definition.id in ["pickaxe","axe"]:
  var tip:=Vector3(-INF,0,0)
  for point in points:
   if point.x>tip.x:tip=point
  mesh.set_meta("tip",tip)
  var anchors:=FileAccess.open(folder+"anchors.gd",FileAccess.WRITE)
  anchors.store_string("extends RefCounted\n# Measured from the real source mesh; regenerate with bake_props.gd.\nconst TIP:=Vector3(%.9f,%.9f,%.9f)\n"%[tip.x,tip.y,tip.z]);anchors.close()
 if definition.id=="bow":
  var string_tip:=Vector3.ZERO;var found:=false
  for point in points:
   if absf(point.y)>1:continue
   if not found or point.z<string_tip.z:string_tip=point;found=true
  mesh.set_meta("rest_nock",Vector3(0,0,string_tip.z))
 assert(ResourceSaver.save(mesh,folder+"model.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("PASS: imported ",definition.id," vertices=",points.size()," triangles=",definition.triangles," bounds=",mesh.get_aabb()," tip=",mesh.get_meta("tip",Vector3.ZERO)," string=",mesh.get_meta("rest_nock",Vector3.ZERO))
 scene.free()
