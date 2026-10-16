extends RefCounted
## Local soft jaw/cheek deformation. Rest geometry, UVs, weights and neck stay fixed.
const PIVOT:=Vector3(0,14.5,13.5)
const MOUTH_CENTER:=Vector3(0,13.35,18.35)
static var cached:ArrayMesh
static func amount(state:StringName,phase:float) -> float:
 if state not in [&"attack",&"hook"]:return 0.0
 return smoothstep(.10,.40,phase)*(1-smoothstep(.60,.95,phase))
static func muscle(point:Vector3) -> Vector2:
 var front:=smoothstep(12.8,16.0,point.z)
 var jaw:=front*(1-smoothstep(17.5,20.0,point.z))*(1-smoothstep(13.2,15.5,point.y))*smoothstep(10.5,12.8,point.y)*(1-smoothstep(3.2,6.0,absf(point.x)))
 var cheek:=front*smoothstep(1.5,3.0,absf(point.x))*(1-smoothstep(4.5,6.5,absf(point.x)))*smoothstep(12.5,14.5,point.y)*(1-smoothstep(16.0,18.0,point.y))
 return Vector2(jaw,cheek)
static func offset(point:Vector3) -> Vector3:
 var mask:=muscle(point)
 var rotated:=Basis(Vector3.RIGHT,.07)*(point-PIVOT)+PIVOT
 return (rotated-point+Vector3(0,-.30,-.05))*mask.x*.75+Vector3(signf(point.x)*.07,.035,0)*mask.y
static func mesh(source:Mesh) -> ArrayMesh:
 if cached!=null:return cached
 var arrays:=source.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
 var delta:Array=[];delta.resize(Mesh.ARRAY_MAX)
 var positions:=PackedVector3Array();positions.resize(vertices.size())
 var normal_delta:=PackedVector3Array();normal_delta.resize(normals.size())
 var tangent_delta:=PackedFloat32Array();tangent_delta.resize(tangents.size())
 for i in vertices.size():
  positions[i]=offset(vertices[i])
  var rotation:=Basis(Vector3.RIGHT,.0525*muscle(vertices[i]).x)
  normal_delta[i]=rotation*normals[i]-normals[i]
  var tangent:=Vector3(tangents[4*i],tangents[4*i+1],tangents[4*i+2])
  var changed:=rotation*tangent-tangent
  tangent_delta[4*i]=changed.x;tangent_delta[4*i+1]=changed.y;tangent_delta[4*i+2]=changed.z;tangent_delta[4*i+3]=0
 delta[Mesh.ARRAY_VERTEX]=positions;delta[Mesh.ARRAY_NORMAL]=normal_delta;delta[Mesh.ARRAY_TANGENT]=tangent_delta
 var encoded:=ArrayMesh.new();encoded.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_RELATIVE;encoded.add_blend_shape("jaw_and_cheeks")
 encoded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[delta],{},source.surface_get_format(0))
 var surfaces:Array=encoded.get("_surfaces")
 var original:Array=source.get("_surfaces")
 for buffer in ["vertex_data","attribute_data","skin_data","index_data"]:
  if original[0].has(buffer):surfaces[0][buffer]=original[0][buffer]
 surfaces[0].aabb=original[0].aabb
 cached=ArrayMesh.new();cached.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_RELATIVE;cached.add_blend_shape("jaw_and_cheeks");cached.set("_surfaces",surfaces)
 cached.custom_aabb=source.get_aabb()
 cached.surface_set_material(0,source.surface_get_material(0))
 for key in source.get_meta_list():cached.set_meta(key,source.get_meta(key))
 return cached
static func mouth() -> MeshInstance3D:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # A recessed cup, rather than a black plane or a second floating jaw.
 for segment in 24:
  var a:=segment*TAU/24.0;var b:=(segment+1)*TAU/24.0
  for point in [Vector3(0,0,-.45),Vector3(cos(a)*1.9,sin(a)*.50,0),Vector3(cos(b)*1.9,sin(b)*.50,0)]:
   surface.set_color(Color(.70,.42,.39) if point.z==0 else Color(.45,.23,.22))
   surface.add_vertex(point)
 surface.generate_normals()
 var node:=MeshInstance3D.new();node.name="MouthInterior";node.mesh=surface.commit();node.position=MOUTH_CENTER
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.55,.34,.32);material.vertex_color_use_as_albedo=true;material.roughness=1;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 node.material_override=material;node.visible=false
 return node
static func apply(node:MeshInstance3D,opening:float,head:Transform3D) -> void:
 node.visible=opening>.001
 node.transform=head*Transform3D(Basis.from_scale(Vector3(1,maxf(.001,opening),1)),MOUTH_CENTER)
