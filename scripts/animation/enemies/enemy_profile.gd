extends "res://scripts/animation/shared/rig_profile.gd"
## Each enemy defines its own appendages, support order and locomotion family.
@export var phase_offsets:Dictionary={}
@export var run_phase_offsets:Dictionary={}
func _init() -> void:category=&"enemy"
func resolve(skeleton:Skeleton3D) -> Dictionary:
 var result:=super.resolve(skeleton)
 if category!=&"enemy" or locomotion_family.is_empty():result.errors.append("An enemy needs its own locomotion family")
 for offsets in [phase_offsets,run_phase_offsets]:
  for label in offsets:
   var value=offsets[label]
   if not chains.has(label) or not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>=1:result.errors.append("Invalid support phase: "+String(label))
 result.ok=result.errors.is_empty();return result
func phase_offset(chain:StringName,running:bool=false) -> float:
 return float(run_phase_offsets.get(chain,phase_offsets.get(chain,0.0)) if running else phase_offsets.get(chain,0.0))
