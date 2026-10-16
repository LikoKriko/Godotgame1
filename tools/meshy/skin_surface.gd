extends RefCounted
## Smooth coincident skin corners only; never change positions, UVs or triangles.
static func polish(source:ArrayMesh) -> ArrayMesh:
 var arrays:=source.surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var material:StandardMaterial3D=source.surface_get_material(0)
 var image:=material.albedo_texture.get_image()
 var colors:=PackedColorArray();var groups:Dictionary={}
 for i in points.size():
  var p:=points[i];var uv:=uvs[i]
  var color:=image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1))
  var texture_skin:=color.r>.35 and color.g>.18 and color.g<color.r*.99 and color.b>.1 and color.b<color.r*.9
  var torso:=smoothstep(31,35,p.y)*(1-smoothstep(50.5,52,p.y))
  var arms:=smoothstep(5.5,7,absf(p.x))*smoothstep(24,27,p.y)*(1-smoothstep(50.5,52,p.y))
  var amount:=maxf(torso,arms) if texture_skin else 0.0
  colors.append(Color(1,1,1,amount))
  if amount<=.5:continue
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
 result.surface_set_material(0,paint)
 for key in source.get_meta_list():result.set_meta(key,source.get_meta(key))
 result.set_meta("skin_surface_profile","skin_seams_v1");result.set_meta("skin_normal_corners_smoothed",changed);result.set_meta("source_material",material)
 print("Skin polish: ",changed," coincident skin corners smoothed; original PNGs and geometry retained")
 return result
