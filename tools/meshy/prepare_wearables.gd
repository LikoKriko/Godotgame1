extends SceneTree
## Add deformation controls to supplied bow/armor without changing topology or UVs.
func _initialize():call_deferred("run")
func run():
 bow();armor();quit()
func bow() -> void:
 var folder:="res://assets/models/meshy/bow/"
 var source:Mesh=load(folder+"model.res");var arrays:=source.surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var image:Image=(source.surface_get_material(0) as StandardMaterial3D).albedo_texture.get_image()
 var shapes:Array[Array]=[]
 for axis in 4:
  var shape:Array=[];shape.resize(Mesh.ARRAY_MAX)
  var deltas:=PackedVector3Array();var normals:=PackedVector3Array();var tangents:=PackedFloat32Array()
  for i in points.size():
   var point:=points[i]
   var color:=image.get_pixel(clampi(int(uv[i].x*image.get_width()),0,image.get_width()-1),clampi(int(uv[i].y*image.get_height()),0,image.get_height()-1))
   var string_vertex:=point.z< -4.0 and color.g>color.r*.74 and color.b>.12
   var amount:=maxf(0,1-absf(point.y)/(11.3 if point.y>0 else 12.5)) if string_vertex else 0.0
   var delta:=Vector3.ZERO
   if axis<3:delta[axis]=amount
   else:delta.z=-1.2*smoothstep(3,14,absf(point.y))
   deltas.append(delta);normals.append(Vector3.ZERO);tangents.append_array(PackedFloat32Array([0,0,0,0]))
  shape[Mesh.ARRAY_VERTEX]=deltas;shape[Mesh.ARRAY_NORMAL]=normals;shape[Mesh.ARRAY_TANGENT]=tangents;shapes.append(shape)
 var mesh:=ArrayMesh.new();mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_RELATIVE
 for label in ["string_x","string_y","string_z","limb_flex"]:mesh.add_blend_shape(label)
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
 mesh.surface_set_material(0,source.surface_get_material(0))
 for key in source.get_meta_list():mesh.set_meta(key,source.get_meta(key))
 assert(ResourceSaver.save(mesh,folder+"deformable.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("PASS: original bow receives string pull/flex blend shapes; ",points.size()," unchanged base vertices")
func armor() -> void:
 var folder:="res://assets/models/meshy/leaf_armor/"
 var source:Mesh=load(folder+"model.res");var arrays:=source.surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
 for i in points.size():
  # Fit the garment's cavity to the slim wearer; keep the source UV/topology.
  points[i].x*=.9;points[i].z=2.2+(points[i].z-2.2)*.62
  var p:=points[i];var influence:Dictionary={}
  var chest:=smoothstep(32,42,p.y)
  influence[0]=1-chest;influence[1]=chest
  if p.y<35:
   var leg:float=.7*(1-smoothstep(30,35,p.y));var side:=smoothstep(-1.5,1.5,p.x)
   influence[0]*=1-leg;influence[1]*=1-leg
   influence[10]=leg*(1-side);influence[13]=leg*side
  var shoulder:=smoothstep(4.0,7.0,absf(p.x))*smoothstep(43,48,p.y)*.8
  if shoulder>0:
   for key in influence:influence[key]*=1-shoulder
   influence[4 if p.x<0 else 7]=shoulder
  var order:Array=influence.keys();order.sort_custom(func(a,b):return influence[a]>influence[b])
  var total:=0.0
  for j in mini(4,order.size()):total+=influence[order[j]]
  for j in 4:
   bones.append(order[j] if j<order.size() else 0)
   weights.append(influence[order[j]]/total if j<order.size() else 0.0)
 arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
 # Fit normals by the inverse transpose of the cavity adjustment.
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
 for i in normals.size():
  normals[i]=(normals[i]/Vector3(.9,1,.62)).normalized()
  var tangent:Vector3=(Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])*Vector3(.9,1,.62)).normalized()
  tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
 arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangents
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:StandardMaterial3D=source.surface_get_material(0).duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED
 mesh.surface_set_material(0,material)
 mesh.set_meta("source_zip_sha256",source.get_meta("source_zip_sha256"));mesh.set_meta("source_triangles",source.get_meta("source_triangles"))
 mesh.set_meta("wear_fit",Vector3(.9,1,.62));mesh.set_meta("wear_center_z",2.2)
 assert(ResourceSaver.save(mesh,folder+"worn.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("PASS: original armor receives wearer fit and normalized skeleton weights; ",points.size()," vertices")
