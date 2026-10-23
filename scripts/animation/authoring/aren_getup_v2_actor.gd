extends "res://scripts/animation/authoring/aren_extreme_actor.gd"
## Review-only new getup; all preceding phases and death use the original actor.
const GetupClip=preload("res://assets/characters/prototype_3d/generated/aren_getup_blender_v2/getup_v2.res")
const NewTiming="res://assets/characters/prototype_3d/generated/aren_getup_blender_v2/timing.json"
var getup_sampler=Sample.new()
var previous_contacts:Dictionary
var new_contacts:Dictionary
var new_getup:=true
func _ready() -> void:
 super._ready()
 previous_contacts=getup_contacts.duplicate(true)
 new_contacts=JSON.parse_string(FileAccess.get_file_as_string(NewTiming)).contacts
 getup_sampler.configure(library,native.skeleton)
 getup_sampler.clips.getup=GetupClip
 var bindings:Array=[]
 for track in GetupClip.get_track_count():bindings.append(native.skeleton.find_bone(str(GetupClip.track_get_path(track).get_subname(0))))
 getup_sampler.tracks.getup=bindings
 set_getup_variant(true)
func set_getup_variant(use_new:bool) -> void:
 new_getup=use_new
 END=GETUP+GetupClip.length if new_getup else ExtremeClip.length
 getup_contacts=new_contacts if new_getup else previous_contacts
 palm_locks.clear();foot_locks.clear()
func apply_extreme(seconds:float) -> void:
 if not new_getup or seconds<=GETUP:
  super.apply_extreme(seconds);return
 clip_time=seconds
 if seconds>=END-.000001:
  clip_time=END;ground_lift=0
  contact_writer.restore(self,sampler.sample("idle",0).poses)
  for side in 2:contact_writer.correct_knee(self,side)
  contact_writer.write(self);return
 var elapsed:=clampf(seconds-GETUP,0,GetupClip.length)
 var pose:Dictionary=getup_sampler.sample("getup",minf(elapsed,GetupClip.length-.000001))
 contact_writer.restore(self,pose.poses)
 var authored_hands:Array[Vector3]=[]
 for arm in native.arms:authored_hands.append(global_transform*native.posed[arm.ids[3]].origin)
 var settle:Array=getup_contacts.final_settle
 var finish:=Jump.smooth5((elapsed-float(settle[0]))/(float(settle[1])-float(settle[0])))
 ground_lift=maxf(0,.008-(skin_minimum()-global_position.y))*(1-finish)
 for bone in native.posed.size():native.posed[bone].origin.y+=ground_lift/SCALE
 if elapsed<float(settle[0]):fit_supports(seconds,authored_hands)
 for side in 2:contact_writer.correct_knee(self,side)
 contact_writer.write(self)
