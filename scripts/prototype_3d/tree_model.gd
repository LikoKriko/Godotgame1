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
func branch(start:Vector3,end:Vector3,radius:float) -> void:
 var middle:=start.lerp(end,0.5)+Vector3(radius*0.9,radius*0.3,-radius*0.6)
 preload("res://scripts/prototype_3d/prop_mesh.gd").polyline(self,PackedVector3Array([start,middle,end]),PackedFloat32Array([radius,radius*0.83,radius*0.46]),material(Color("775135")),7)
func foliage(point:Vector3,size:Vector3,seed_value:int,color:Color) -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var rings:Array[PackedVector3Array]=[]
 for level:Vector2 in [Vector2(-0.72,0.30),Vector2(-0.3,0.88),Vector2(0.20,1),Vector2(0.65,0.65),Vector2(0.85,0.15)]:
  var ring:=PackedVector3Array()
  for i in 7:
   var angle:=i*TAU/7;var radial:=level.y*rng.randf_range(0.88,1.12)
   ring.append(point+Vector3(cos(angle)*size.x*radial,level.x*size.y+rng.randf_range(-0.04,0.04),sin(angle)*size.z*radial))
  rings.append(ring)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in rings.size()-1:
  for i in 7:
   var next:=(i+1)%7
   for vertex:Vector3 in [rings[row][i],rings[row+1][next],rings[row+1][i],rings[row][i],rings[row][next],rings[row+1][next]]:
    surface.set_uv(Vector2(vertex.x,vertex.z));surface.add_vertex(vertex)
 surface.generate_normals()
 var node:=MeshInstance3D.new();node.mesh=surface.commit();node.material_override=material(color);crown.add_child(node)
func _ready() -> void:
 add_to_group("prototype_trees")
 var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=0.22;shape.height=2.8
 collider.shape=shape;collider.position.y=1.4;add_child(collider)
 crown=Node3D.new();add_child(crown)
 var cached:bool=mesh_cache.has(posmod(variant_id,30))
 if not cached:
  var trunk:=PackedVector3Array([Vector3.ZERO,Vector3(0.04,0.5,0),Vector3(-0.05,1.1,0.04),Vector3(0.08,1.8,-0.03),Vector3(0,2.75,0)])
  preload("res://scripts/prototype_3d/prop_mesh.gd").polyline(self,trunk,PackedFloat32Array([0.29,0.24,0.20,0.155,0.08]),material(Color("775135")),9)
  for i in 7:
   var angle:=i*TAU/7+variant_id*0.13
   branch(Vector3(cos(angle)*0.73,0.015,sin(angle)*0.73),Vector3(cos(angle)*0.07,0.45,sin(angle)*0.07),0.11)
 var rng:=RandomNumberGenerator.new();rng.seed=41+variant_id*7919
 for i in 9:
  var angle:=i*2.4+variant_id*0.07
  var end:=Vector3(cos(angle)*(0.85+rng.randf()*0.2),2.25+rng.randf()*1.0,sin(angle)*(0.85+rng.randf()*0.2))
  if not cached:
   branch(Vector3(0,1.45+i*0.1,0),end,0.105)
   for twig in 3:
    var theta:=angle+twig*TAU/3
    var tip:=end+Vector3(cos(theta)*0.35,0.07+twig*0.1,sin(theta)*0.35)
    branch(end-Vector3.UP*0.15,tip,0.043)
    foliage(tip,Vector3(0.44,0.42,0.47),variant_id*997+i*41+twig,[Color("647638"),Color("74833e"),Color("586b32")][(twig+i)%3])
  var camera_body:=StaticBody3D.new();camera_body.collision_layer=4;camera_body.collision_mask=0;camera_body.position=end;add_child(camera_body)
  var camera_shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=0.78;camera_shape.shape=sphere;camera_body.add_child(camera_shape)
 bake_tree();base_transform=crown.transform
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
   if arrays[Mesh.ARRAY_INDEX]==null:
    for index in arrays[Mesh.ARRAY_VERTEX].size():indices.append(start+index)
   else:
    for index in arrays[Mesh.ARRAY_INDEX]:indices.append(start+index)
  var result:Array=[];result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals;result[Mesh.ARRAY_COLOR]=colors;result[Mesh.ARRAY_TEX_UV]=uv;result[Mesh.ARRAY_INDEX]=indices
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result)
  var material:=ShaderMaterial.new();material.shader=load("res://shaders/prototype_3d/tree_material.gdshader");material.set_shader_parameter("bark",load("res://assets/characters/prototype_3d/pixel_materials.png"));material.set_shader_parameter("leaves",load("res://assets/enemies/prototype_3d/pixel_materials.png"))
  var outline:=ShaderMaterial.new();outline.shader=load("res://shaders/prototype_3d/outline.gdshader");outline.set_shader_parameter("thickness",0.0069);material.next_pass=outline;mesh.surface_set_material(0,material);mesh_cache[key]=mesh
 for child in get_children()+crown.get_children():
  if child is MeshInstance3D:child.hide();child.queue_free()
 var node:=MeshInstance3D.new();node.mesh=mesh_cache[key];crown.add_child(node)
func visual_height() -> float:return mesh_cache[posmod(variant_id,30)].get_aabb().end.y
