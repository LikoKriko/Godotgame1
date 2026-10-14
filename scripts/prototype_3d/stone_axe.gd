extends Node3D
## Split wood, crossed rope and an extruded stone blade use the reference palette.
func material(color: Color) -> StandardMaterial3D:
 var result := StandardMaterial3D.new(); result.albedo_color = color; result.roughness = 0.95
 var outline := ShaderMaterial.new(); outline.shader = preload("res://shaders/prototype_3d/outline.gdshader"); result.next_pass = outline
 return result
func cylinder(point: Vector3, height: float, radius: float, color: Color, angle: float = 0.0) -> void:
 var mesh := CylinderMesh.new(); mesh.height = height; mesh.top_radius = radius*0.85; mesh.bottom_radius = radius; mesh.radial_segments = 8
 var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material(color); node.position = point; node.rotation.z = angle; add_child(node)
func _ready() -> void:
 cylinder(Vector3(-0.65,15.3,0),30.6,0.9,Color("89522f"))
 cylinder(Vector3(0.65,15.6,0),31.2,0.85,Color("b47c48"))
 var polygon := PackedVector2Array([Vector2(0,21),Vector2(1.5,29),Vector2(8.0,28),Vector2(11,24),Vector2(8.5,19.5),Vector2(2,20)])
 var triangles := Geometry2D.triangulate_polygon(polygon)
 var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1.0,1.0]:
  for i in range(0,triangles.size(),3):
   var order := [triangles[i],triangles[i+1],triangles[i+2]] if side > 0 else [triangles[i+2],triangles[i+1],triangles[i]]
   for index in order: tool.set_color(Color("999388") if side > 0 else Color("77736c")); tool.add_vertex(Vector3(polygon[index].x,polygon[index].y,side*1.4))
 for i in polygon.size():
  var a := polygon[i]; var b := polygon[(i+1)%polygon.size()]
  for vertex in [Vector3(a.x,a.y,-1.4),Vector3(b.x,b.y,-1.4),Vector3(b.x,b.y,1.4),Vector3(a.x,a.y,-1.4),Vector3(b.x,b.y,1.4),Vector3(a.x,a.y,1.4)]:
   tool.set_color(Color("c2bcb1") if i in [2,3] else Color("625e56")); tool.add_vertex(vertex)
 tool.generate_normals()
 var blade := MeshInstance3D.new(); blade.mesh = tool.commit()
 var paint := StandardMaterial3D.new(); paint.vertex_color_use_as_albedo = true; paint.roughness = 1.0; paint.cull_mode = BaseMaterial3D.CULL_DISABLED
 var outline := ShaderMaterial.new(); outline.shader = preload("res://shaders/prototype_3d/outline.gdshader"); paint.next_pass = outline
 blade.material_override = paint; add_child(blade)
 for angle in [-0.7,0.7]: cylinder(Vector3(0,25,0),10.5,0.48,Color("b4ad70"),angle)
 for y in [20.5,22.0,23.5]:
  var ring := MeshInstance3D.new(); var mesh := TorusMesh.new(); mesh.inner_radius = 1.18; mesh.outer_radius = 1.7; mesh.rings = 10; mesh.ring_segments = 6
  ring.mesh = mesh; ring.position.y = y; ring.material_override = material(Color("b4ad70")); add_child(ring)
