extends StaticBody3D
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
var required_hits:=4
var health:=4
var yield_count:=4
var hand_collectable:=false
var height:=0.7
var visual:Node3D
var shake:=0.0
func configure(size_index:int) -> void:
 height=[0.28,0.7,1.4,2.4][size_index];required_hits=[1,4,8,12][size_index];health=required_hits;yield_count=[2,4,10,15][size_index];hand_collectable=size_index==0
 add_to_group("prototype_rocks");collision_layer=1;collision_mask=0
 var collision:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=height*0.52;collision.shape=shape;collision.position.y=height*0.42;add_child(collision)
 if hand_collectable:collision.disabled=true
 # Expanded impact/selection volume never changes walking collisions.
 var area:=Area3D.new();area.collision_layer=16;area.collision_mask=0;area.set_meta("resource",self);add_child(area)
 var aim:=CollisionShape3D.new();var aim_shape:=SphereShape3D.new();aim_shape.radius=shape.radius+0.15;aim.shape=aim_shape;aim.position.y=height*0.42;area.add_child(aim)
 visual=Node3D.new();add_child(visual)
 for i in 4:
  var node:=Meshes.sphere(visual,Vector3(sin(i*2.4)*height*0.22,height*(0.32+0.07*(i%2)),cos(i*2.4)*height*0.22),Vector3(height*0.43,height*(0.36 if i%2 else 0.48),height*0.4),Meshes.material(&"stone",Color("a4a394")))
  # Mesh geometry uses world metres: keep its contour the same world thickness.
  var material:Material=node.material_override.duplicate();material.next_pass=material.next_pass.duplicate();material.next_pass.set_shader_parameter("thickness",0.004);node.material_override=material
func hit() -> bool:
 if health<=0:return false
 health-=1;shake=0.2
 if health==0:
  hide();collision_layer=0
  for child in get_children():
   if child is CollisionObject3D:child.collision_layer=0
 return true
func _process(delta:float) -> void:
 shake=maxf(0,shake-delta)
 if visual!=null:visual.rotation.z=sin(shake*50)*0.02*shake/0.2
