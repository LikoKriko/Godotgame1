extends SceneTree
## Convert the original glTF geometry to a shared Godot resource, without remeshing.
const PATH="res://assets/items/prototype_3d/bottle_meshy/"
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args()
 assert(args.size()==1,"Pass -- /absolute/path/to/source.glb")
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 assert(doc.append_from_file(args[0],state)==OK)
 var scene:=doc.generate_scene(state);root.add_child(scene)
 var nodes:=scene.find_children("*","MeshInstance3D",true,false)
 assert(nodes.size()==1)
 var source:Mesh=nodes[0].mesh
 var surface:=SurfaceTool.new();surface.create_from(source,0);surface.generate_tangents()
 var arrays:=surface.commit().surface_get_arrays(0)
 var bounds:=source.get_aabb();var factor:=10.4/bounds.size.y
 # The palm holds the narrow neck. +Y points to the stopper/mouth.
 var cap:=AABB();var first:=true
 for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
  if point.y<bounds.end.y-bounds.size.y*0.04:continue
  cap=AABB(point,Vector3.ZERO) if first else cap.expand(point);first=false
 var offset:=Vector3(-cap.get_center().x,-bounds.position.y,-cap.get_center().z)*factor-Vector3.UP*7.6
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 for i in vertices.size():vertices[i]=vertices[i]*factor+offset
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new();material.albedo_texture=load(PATH+"albedo.png")
 material.normal_enabled=true;material.normal_texture=load(PATH+"normal.png")
 material.roughness_texture=load(PATH+"roughness.png");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic_texture=load(PATH+"metallic.png");material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic=1;material.roughness=1;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 mesh.surface_set_material(0,material)
 assert((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3==883250)
 mesh.set_meta("source_triangles",883250);mesh.set_meta("source_zip_sha256","195b63561de1f06c49eec428686e488d41096329b8570e42655e7de88f483127")
 mesh.set_meta("mouth",Vector3(0,2.8,0));mesh.set_meta("uniform_scale",factor);mesh.set_meta("translation",offset)
 assert(ResourceSaver.save(mesh,PATH+"bottle.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("PASS: original bottle baked: ",vertices.size()," vertices, 883250 triangles; ",mesh.get_aabb())
 scene.free();quit()
