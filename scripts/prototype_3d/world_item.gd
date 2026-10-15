extends Area3D
## Pickups keep their complete record; immutable model resources are shared.
const Models=preload("res://scripts/prototype_3d/item_models.gd")
var item:Dictionary={}
var visual:Node3D
var visual_bounds:=AABB()
func configure(value:Dictionary) -> void:
 item=value.duplicate(true);collision_layer=16;collision_mask=0;monitoring=false;add_to_group("prototype_drops")
 visual=Models.create(item)
 if visual==null:
  # Explicitly provisional until the user provides/approves a model design.
  var marker:=Sprite3D.new();marker.texture=preload("res://scripts/prototype_3d/item_icons.gd").for_item(item);marker.pixel_size=0.0012;marker.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;marker.position.y=0.15;marker.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS;visual=marker
  visual_bounds=AABB(Vector3(-0.15,0,-0.15),Vector3(0.3,0.3,0.3))
 else:visual_bounds=Models.bounds(visual)
 add_child(visual)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=(visual_bounds.size+Vector3.ONE*0.05).max(Vector3(0.20,0.24,0.20));collision.shape=shape
 collision.position=visual_bounds.get_center();collision.position.y=maxf(collision.position.y,shape.size.y*0.5);add_child(collision)
func settle_on_ground() -> void:
 var from:=global_position+Vector3.UP*0.25
 var query:=PhysicsRayQueryParameters3D.create(from,from+Vector3.DOWN*8,1)
 var result:=get_world_3d().direct_space_state.intersect_ray(query)
 if not result.is_empty():global_position.y=result.position.y
