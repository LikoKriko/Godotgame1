extends RefCounted
## Shared reduced control curves. Skeleton IK keeps limb lengths after blending.
const LIBRARY=preload("res://assets/characters/prototype_3d/motion/controls.res")
static var tracks:Dictionary={}
static var last_phases:Dictionary={}
static var last_values:Dictionary={}
static func sample(clip:StringName,phase:float) -> Dictionary:
 phase=clampf(phase,0,1)
 if last_phases.get(clip,-1.0)==phase:return last_values[clip].duplicate()
 var animation:Animation=LIBRARY.get_animation(clip)
 if not tracks.has(clip):
  var names:Array[StringName]=[]
  for index in animation.get_track_count():names.append(StringName(animation.track_get_path(index)))
  tracks[clip]=names
 var result:Dictionary={}
 for index in animation.get_track_count():result[tracks[clip][index]]=animation.position_track_interpolate(index,phase)
 last_phases[clip]=phase;last_values[clip]=result
 return result.duplicate()
