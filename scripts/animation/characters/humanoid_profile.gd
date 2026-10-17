extends "res://scripts/animation/shared/rig_profile.gd"
## Characters share a humanoid topology; target rigs retain their own proportions.
@export var reference_width:=1.0
@export var reference_depth:=1.0
func _init() -> void:
 category=&"character";locomotion_family=&"humanoid"
func resolve(skeleton:Skeleton3D) -> Dictionary:
 var result:=super.resolve(skeleton)
 for role in [&"root",&"spine",&"head",&"arm_root_l",&"arm_mid_l",&"arm_end_l",&"arm_root_r",&"arm_mid_r",&"arm_end_r",&"leg_root_l",&"leg_mid_l",&"leg_end_l",&"leg_root_r",&"leg_mid_r",&"leg_end_r"]:
  if not bones.has(role):result.errors.append("Missing humanoid role: "+String(role))
 if not is_finite(reference_width) or reference_width<=0 or not is_finite(reference_depth) or reference_depth<=0:result.errors.append("Humanoid reference proportions must be positive")
 if category!=&"character" or locomotion_family!=&"humanoid":result.errors.append("Characters require the humanoid family")
 result.ok=result.errors.is_empty();return result
func adapt_contact(point:Vector3,target_profile:Resource) -> Vector3:
 # Contact offsets around an agreed body anchor, in each rig's authoring units.
 return point*Vector3(target_profile.reference_width/reference_width,target_profile.reference_height/reference_height,target_profile.reference_depth/reference_depth)
