extends StaticBody3D
## Edited Meshy oak; one immutable mesh shared by every tree in the world.
const Geometry=preload("res://scripts/prototype_3d/tree_geometry.gd")
var variant_id:=0
var design_id:=0
var health:=3
var base_transform:=Transform3D.IDENTITY
var impact_remaining:=0.0
var crown:Node3D
func _ready() -> void:
 add_to_group("prototype_trees")
 var rotation:=Geometry.orientation(variant_id)
 crown=Node3D.new();crown.name="TreeVisual";crown.basis=rotation;add_child(crown)
 var visual:=MeshInstance3D.new();visual.mesh=Geometry.SOURCE;visual.scale=Vector3.ONE*visual_height()
 visual.name="RootsTrunkRadialBranches";crown.add_child(visual)
 var data:=Geometry.colliders(design_id)
 var hit_area:=Area3D.new();hit_area.collision_layer=16;hit_area.collision_mask=0;hit_area.monitoring=false;hit_area.set_meta("resource",self);add_child(hit_area)
 var camera_body:=StaticBody3D.new();camera_body.name="BranchCameraBlockers";camera_body.collision_layer=4;camera_body.collision_mask=0;add_child(camera_body)
 for key in ["physical","aim","camera"]:
  var parent:Node3D=self if key=="physical" else (hit_area if key=="aim" else camera_body)
  for item:Dictionary in data[key]:
   var collision:=CollisionShape3D.new();collision.shape=item.shape
   collision.transform=Transform3D(rotation,Vector3.ZERO)*item.transform;parent.add_child(collision)
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
 if crown!=null:
  crown.transform=Transform3D(Basis(Vector3.BACK,sin(impact_remaining*40)*.035*impact_remaining/.2),Vector3.ZERO)*base_transform
 if impact_remaining<=0:set_process(false)
func visual_height() -> float:return Geometry.height_for(design_id)
