extends Area3D
## A physical pickup keeps the complete item record, including wear and water.
var item:Dictionary={}
func configure(value:Dictionary) -> void:
 item=value.duplicate(true);collision_layer=16;collision_mask=0;monitoring=false;add_to_group("prototype_drops")
 var visual:=Sprite3D.new();visual.texture=preload("res://scripts/prototype_3d/item_icons.gd").for_item(item);visual.pixel_size=0.0012;visual.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;visual.position.y=0.15;visual.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS;add_child(visual)
 var collision:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=0.22;collision.shape=shape;collision.position.y=0.15;add_child(collision)
