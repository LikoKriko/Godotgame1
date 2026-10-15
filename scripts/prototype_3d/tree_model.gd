extends StaticBody3D
## Stylized lobed foliage and branching trunk matching the uploaded tree palette.
var variant_id:=0
static var mesh_cache:Dictionary={}
var health := 3
var base_transform := Transform3D.IDENTITY
var impact_remaining := 0.0
var crown: Node3D
func material(color: Color) -> StandardMaterial3D:
 var result := StandardMaterial3D.new(); result.albedo_color = color; result.roughness = 1.0
 var outline := ShaderMaterial.new(); outline.shader = preload("res://shaders/prototype_3d/outline.gdshader"); outline.set_shader_parameter("thickness",0.0069); result.next_pass = outline
 return result
func branch(start: Vector3, end: Vector3, radius: float) -> void:
 var mesh := CylinderMesh.new(); mesh.height = start.distance_to(end); mesh.top_radius = radius*0.55; mesh.bottom_radius = radius; mesh.radial_segments = 7
 var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material(Color("775135")); node.position = (start+end)/2
 node.quaternion = Quaternion(Vector3.UP,(end-start).normalized()); add_child(node)
func _ready() -> void:
 add_to_group("prototype_trees")
 var collider := CollisionShape3D.new(); var shape := CylinderShape3D.new(); shape.radius = 0.22; shape.height = 2.8
 collider.shape = shape; collider.position.y = 1.4; add_child(collider)
 branch(Vector3.ZERO,Vector3(0,2.9,0),0.22)
 for i in 5:
  var angle := i*TAU/5
  branch(Vector3(cos(angle)*0.55,0.03,sin(angle)*0.55),Vector3(0,0.35,0),0.09)
 crown = Node3D.new(); add_child(crown)
 var rng := RandomNumberGenerator.new(); rng.seed = 41+variant_id*7919
 for i in 9:
  var angle := i*2.4; var end := Vector3(cos(angle)*0.85,2.2+rng.randf()*1.0,sin(angle)*0.85)
  branch(Vector3(0,1.5+i*0.09,0),end,0.10)
  var mesh := SphereMesh.new(); mesh.radius = 0.58; mesh.height = 1.02; mesh.radial_segments = 10; mesh.rings = 5
  var node := MeshInstance3D.new(); node.mesh = mesh; node.position = end
  node.scale = Vector3(1.05+rng.randf()*0.2,0.82,1.0)
  var camera_body := StaticBody3D.new(); camera_body.collision_layer = 4; camera_body.collision_mask = 0
  camera_body.position = end; add_child(camera_body)
  var camera_shape := CollisionShape3D.new(); var sphere := SphereShape3D.new(); sphere.radius = 0.56
  camera_shape.shape = sphere; camera_body.add_child(camera_shape)
  node.material_override = material([Color("667837"),Color("7e8a43"),Color("56672e")][i%3]); crown.add_child(node)
 bake_tree()
 base_transform = crown.transform
func hit() -> bool:
 if health <= 0: return false
 health -= 1; impact_remaining = 0.2
 if health == 0:
  hide(); collision_layer = 0
  for child in get_children():
   if child is CollisionObject3D: child.collision_layer = 0
 return true
func _process(delta: float) -> void:
 impact_remaining = maxf(0,impact_remaining-delta)
 if crown != null: crown.rotation.z = sin(impact_remaining*40)*0.035*impact_remaining/0.2

func bake_tree() -> void:
 var key:=posmod(variant_id,30)
 if not mesh_cache.has(key):
  var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
  var nodes:Array[Node]=get_children()
  nodes.append_array(crown.get_children())
  for child in nodes:
   if not child is MeshInstance3D:continue
   var transform_to_root:Transform3D=global_transform.affine_inverse()*child.global_transform
   var arrays:Array=child.mesh.surface_get_arrays(0);var start:=vertices.size()
   var color:Color=child.material_override.albedo_color
   var tint:=Color(0.94+0.02*(key%3),0.97+0.01*(key%3),0.94+0.02*(key%3))
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    var point:Vector3=transform_to_root*arrays[Mesh.ARRAY_VERTEX][i]
    vertices.append(point);normals.append((transform_to_root.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][i]).normalized());colors.append(color*tint);uv.append(Vector2(fposmod(point.x*0.7+point.z*0.4,1),fposmod(point.y*0.7,1)))
   for index in arrays[Mesh.ARRAY_INDEX]:indices.append(start+index)
  var result:Array=[];result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals;result[Mesh.ARRAY_COLOR]=colors;result[Mesh.ARRAY_TEX_UV]=uv;result[Mesh.ARRAY_INDEX]=indices
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result)
  var material:=ShaderMaterial.new();material.shader=load("res://shaders/prototype_3d/tree_material.gdshader");material.set_shader_parameter("bark",load("res://assets/characters/prototype_3d/pixel_materials.png"));material.set_shader_parameter("leaves",load("res://assets/enemies/prototype_3d/pixel_materials.png"))
  var outline:=ShaderMaterial.new();outline.shader=load("res://shaders/prototype_3d/outline.gdshader");outline.set_shader_parameter("thickness",0.0069);material.next_pass=outline;mesh.surface_set_material(0,material);mesh_cache[key]=mesh
 for child in get_children()+crown.get_children():
  if child is MeshInstance3D:child.hide();child.queue_free()
 var node:=MeshInstance3D.new();node.mesh=mesh_cache[key];crown.add_child(node)
func visual_height() -> float:return mesh_cache[posmod(variant_id,30)].get_aabb().end.y
