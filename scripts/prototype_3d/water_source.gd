extends Area3D
var radius:=1.0
func _ready() -> void:
 collision_layer=16;collision_mask=0;add_to_group("prototype_water")
 var shape:=CollisionShape3D.new();var volume:=CylinderShape3D.new();volume.radius=radius;volume.height=0.08;shape.shape=volume;shape.position.y=0.04;add_child(shape)
 var node:=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=radius;disc.bottom_radius=radius;disc.height=0.02;disc.radial_segments=32;node.mesh=disc;node.position.y=0.025;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var paint:=StandardMaterial3D.new();paint.albedo_color=Color("547782");paint.roughness=0.35;node.material_override=paint;add_child(node)
