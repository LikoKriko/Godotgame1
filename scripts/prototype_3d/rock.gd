extends StaticBody3D
const IMPORTED=preload("res://assets/models/meshy/rock1/model.res")
var required_hits:=4
var health:=4
var yield_count:=4
var hand_collectable:=false
const HEIGHT:=1.0
var height:=HEIGHT
var visual:Node3D
var shake:=0.0
func configure() -> void:
 add_to_group("prototype_rocks");collision_layer=1;collision_mask=0
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=IMPORTED.get_aabb().size*height*Vector3(.86,.94,.86);collision.shape=shape;collision.position=IMPORTED.get_aabb().get_center()*height;add_child(collision)
 if hand_collectable:collision.disabled=true
 # The other department's 15 cm impact tolerance follows the imported bounds.
 # This area selects resources; only the inner volume blocks movement.
 var area:=Area3D.new();area.collision_layer=16;area.collision_mask=0;area.set_meta("resource",self);add_child(area)
 var aim:=CollisionShape3D.new();var aim_shape:=BoxShape3D.new();aim_shape.size=shape.size+Vector3.ONE*.3;aim.shape=aim_shape;aim.position=collision.position;area.add_child(aim)
 visual=Node3D.new();add_child(visual)
 var model:=MeshInstance3D.new();model.mesh=IMPORTED;model.scale=Vector3.ONE*height;visual.add_child(model);set_process(false)
func hit() -> bool:
 if health<=0:return false
 health-=1;shake=0.2;set_process(true)
 if health==0:
  hide();collision_layer=0
  for child in get_children():
   if child is CollisionObject3D:child.collision_layer=0
 return true
func _process(delta:float) -> void:
 shake=maxf(0,shake-delta)
 if visual!=null:visual.rotation.z=sin(shake*50)*0.02*shake/0.2
 if shake<=0:set_process(false)
