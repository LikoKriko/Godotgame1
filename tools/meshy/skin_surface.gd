extends RefCounted
## Smooth coincident skin corners only; never change positions, UVs or triangles.
static func polish(source:ArrayMesh) -> ArrayMesh:
 var arrays:=source.surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var material:StandardMaterial3D=source.surface_get_material(0)
 var image:=material.albedo_texture.get_image()
 var hair:=hair_membership(arrays,image)
 var colors:=PackedColorArray();var groups:Dictionary={}
 for i in points.size():
  var p:=points[i];var uv:=uvs[i]
  var color:=image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1))
  var texture_skin:=color.r>.35 and color.g>.18 and color.g<color.r*.99 and color.b>.1 and color.b<color.r*.9
  var torso:=smoothstep(31,35,p.y)*(1-smoothstep(50.5,52,p.y))
  var arms:=smoothstep(5.5,7,absf(p.x))*smoothstep(24,27,p.y)*(1-smoothstep(50.5,52,p.y))
  var amount:=maxf(torso,arms) if texture_skin else 0.0
  var face:=smoothstep(52.8,54,p.y)*(1-smoothstep(60,61,p.y))*smoothstep(1.4,2.8,p.z)*(1-hair[i]) if texture_skin else 0.0
  colors.append(Color(hair[i],face,0,amount))
  if maxf(amount,face)<=.5:continue
  var key:=Vector3i(roundi(p.x*1000),roundi(p.y*1000),roundi(p.z*1000))
  if not groups.has(key):groups[key]=[]
  groups[key].append(i)
 var changed:=0
 for indices:Array in groups.values():
  if indices.size()<2:continue
  var mean:=Vector3.ZERO
  for index:int in indices:mean+=normals[index]
  if mean.length()<.1:continue
  mean=mean.normalized()
  for index:int in indices:
   if normals[index].dot(mean)<.65:continue
   if normals[index].distance_to(mean)>.0001:changed+=1
   normals[index]=mean
 arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
 var intermediate:=ArrayMesh.new();intermediate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var surface:=SurfaceTool.new();surface.create_from(intermediate,0);surface.generate_tangents()
 var result:ArrayMesh=surface.commit()
 var paint:=ShaderMaterial.new();paint.shader=preload("res://shaders/prototype_3d/survivor_skin.gdshader")
 for pair in [["albedo_map",material.albedo_texture],["normal_map",material.normal_texture],["roughness_map",material.roughness_texture],["metallic_map",material.metallic_texture]]:paint.set_shader_parameter(pair[0],pair[1])
 paint.set_shader_parameter("skin_normal_strength",.15)
 paint.set_shader_parameter("face_normal_strength",.4)
 paint.set_shader_parameter("face_detail_strength",.055)
 paint.set_shader_parameter("face_detail_map",load("res://assets/characters/prototype_3d/meshy/face_detail_normal.png"))
 result.surface_set_material(0,paint)
 for key in source.get_meta_list():result.set_meta(key,source.get_meta(key))
 result.set_meta("skin_surface_profile","skin_seams_v1");result.set_meta("skin_normal_corners_smoothed",changed);result.set_meta("source_material",material)
 result.set_meta("face_surface_profile","face_materials_v1")
 print("Skin polish: ",changed," coincident skin corners smoothed; original PNGs and geometry retained")
 return result

static func hair_membership(arrays:Array,image:Image) -> PackedFloat32Array:
 # UV seams duplicate vertices. Vote per spatial point, then close tiny holes
 # inside hair; skin at the hairline, ears, eyes and lips remains unpainted.
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var keys:Array[Vector3i]=[];var records:Dictionary={}
 for point in points:
  var key:=Vector3i((point*10000).round());keys.append(key)
  if not records.has(key):records[key]={"brown":0.0,"total":0.0,"neighbors":{},"allowed":point.y>56.4 or (point.y>53.0 and point.z>3.4),"scalp":point.y>60.5 or (point.y>56.4 and point.z<1.2 and absf(point.x)<3.4)}
 for triangle in range(0,indices.size(),3):
  var ids:=[indices[triangle],indices[triangle+1],indices[triangle+2]]
  var center:Vector2=(uv[ids[0]]+uv[ids[1]]+uv[ids[2]])/3
  var color:=image.get_pixel(clampi(int(center.x*image.get_width()),0,image.get_width()-1),clampi(int(center.y*image.get_height()),0,image.get_height()-1))
  var brown:=color.r<.4 and color.r>color.g*1.45 and color.g>color.b*1.1
  for index:int in ids:
   var record:Dictionary=records[keys[index]];record.total+=1;record.brown+=1 if brown else 0
   for neighbor:int in ids:
    if keys[neighbor]!=keys[index]:record.neighbors[keys[neighbor]]=true
 var mask:Dictionary={}
 for key:Vector3i in records:
  var record:Dictionary=records[key];mask[key]=1.0 if record.scalp or (record.allowed and record.brown/maxf(1,record.total)>.75) else 0.0
 for step in 2:
  var next:=mask.duplicate()
  for key:Vector3i in records:
   var record:Dictionary=records[key]
   if not record.allowed or mask[key]>.5 or record.neighbors.size()<3:continue
   var sum:=0.0
   for neighbor:Vector3i in record.neighbors:sum+=mask[neighbor]
   if sum/record.neighbors.size()>=.99:next[key]=1.0
  mask=next
 var result:=PackedFloat32Array()
 for key:Vector3i in keys:result.append(mask[key])
 return result
