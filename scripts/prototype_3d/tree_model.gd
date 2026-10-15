extends StaticBody3D
## Reference species: nine shapes, four subtle variations; one cached draw surface.
const Geometry=preload("res://scripts/prototype_3d/tree_geometry.gd")
var variant_id:=0
var design_id:=0
static var mesh_cache:Dictionary={}
static var crown_cache:Dictionary={}
static var trunk_cache:Dictionary={}
static var shared_material:ShaderMaterial
var health:=3
var base_transform:=Transform3D.IDENTITY
var impact_remaining:=0.0
var crown:Node3D
func cache_key() -> int:return posmod(design_id,9)*4+posmod(variant_id,4)
static func material() -> ShaderMaterial:
 if shared_material==null:
  shared_material=ShaderMaterial.new();shared_material.shader=preload("res://shaders/prototype_3d/tree_material.gdshader")
  shared_material.set_shader_parameter("bark",load("res://assets/environment/prototype_3d/tree_bark.png"))
  shared_material.set_shader_parameter("leaves",load("res://assets/environment/prototype_3d/tree_leaf.png"))
  var outline:=ShaderMaterial.new();outline.shader=preload("res://shaders/prototype_3d/outline.gdshader");outline.set_shader_parameter("thickness",0.0025);shared_material.next_pass=outline
 return shared_material
func _ready() -> void:
 add_to_group("prototype_trees")
 var key:=cache_key()
 if not mesh_cache.has(key):
  var builder:=Geometry.new();var mesh:=builder.build(design_id,variant_id)
  mesh.surface_set_material(0,material());mesh_cache[key]=mesh
  crown_cache[key]=builder.crowns.duplicate(true);trunk_cache[key]=builder.trunk_points
 crown=Node3D.new();crown.name="TreeVisual";add_child(crown)
 var visual:=MeshInstance3D.new();visual.mesh=mesh_cache[key];visual.name="BarkRootsBranchesLeaves";crown.add_child(visual)
 var points:PackedVector3Array=trunk_cache[key]
 var hit_area:=Area3D.new();hit_area.collision_layer=16;hit_area.collision_mask=0;hit_area.monitoring=false;hit_area.set_meta("resource",self);add_child(hit_area)
 # Collisions follow the visible lower trunk. Roots and foliage remain walkable.
 for i in range(0,points.size()-3,4):
  var a:Vector3=points[i];var b:Vector3=points[mini(i+4,points.size()-1)]
  var collision:=CollisionShape3D.new();var shape:=CapsuleShape3D.new()
  shape.radius=Geometry.HEIGHTS[posmod(design_id,9)]*lerpf(.082,.030,clampf(a.y/visual_height(),0,1))
  shape.height=maxf(shape.radius*2,a.distance_to(b)+shape.radius*2)
  collision.shape=shape;collision.position=(a+b)*.5;collision.basis=Basis(Quaternion(Vector3.UP,a.direction_to(b)));add_child(collision)
  var aim:=CollisionShape3D.new();var aim_shape:=CapsuleShape3D.new()
  aim_shape.radius=shape.radius+0.15;aim_shape.height=shape.height+0.30
  aim.shape=aim_shape;aim.transform=collision.transform;hit_area.add_child(aim)
 # Camera blockers use the real crown groups, separate from harvesting/walking.
 for group:Dictionary in crown_cache[key]:
  var blocker:=StaticBody3D.new();blocker.collision_layer=4;blocker.collision_mask=0;blocker.position=group.position;add_child(blocker)
  var collision:=CollisionShape3D.new();var shape:=SphereShape3D.new()
  shape.radius=maxf(group.radius.x,maxf(group.radius.y,group.radius.z))*.80
  collision.shape=shape;blocker.add_child(collision)
 base_transform=crown.transform;set_process(false)
func hit() -> bool:
 if health<=0:return false
 health-=1;impact_remaining=.2;set_process(true)
 if health==0:
  hide();collision_layer=0
  for child in get_children():
   if child is CollisionObject3D:child.collision_layer=0
 return true
func _process(delta:float) -> void:
 impact_remaining=maxf(0,impact_remaining-delta)
 if crown!=null:crown.rotation.z=sin(impact_remaining*40)*.035*impact_remaining/.2
 if impact_remaining<=0:set_process(false)
func visual_height() -> float:return mesh_cache[cache_key()].get_aabb().end.y
