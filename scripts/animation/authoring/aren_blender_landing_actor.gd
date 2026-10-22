extends "res://scripts/animation/authoring/aren_fall_actor.gd"
## Review-only whole-pose family. Approved gameplay and clips stay intact.
const PilotClip=preload("res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/landing_3m.res")
const HeavyClip=preload("res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/landing_heavy.res")
const PreviousClip=preload("res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/landing_3m_previous.res")
const PreviousHeavyClip=preload("res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/landing_heavy_previous.res")
const Family=preload("res://scripts/animation/authoring/aren_blender_landing_motion.gd")
const CycleSampler=preload("res://scripts/animation/authoring/aren_cycle_sampler.gd")
const PilotContacts=preload("res://scripts/animation/authoring/aren_blender_landing_contacts.gd")
const IMPACT=47.0/60
var landing=PilotContacts.new()
var pilot_sampler=CycleSampler.new()
var clip_start:=Vector3.ZERO
@export var previous_clip:=false
func _ready() -> void:
 review_height=3
 super._ready()
 pilot_sampler.configure(library,native.skeleton)
 for key in ["pilot","heavy","previous","previous_heavy"]:
  var clip:Animation={"pilot":PilotClip,"heavy":HeavyClip,"previous":PreviousClip,"previous_heavy":PreviousHeavyClip}[key]
  pilot_sampler.clips[key]=clip
  var bindings:Array=[]
  for track in clip.get_track_count():bindings.append(native.skeleton.find_bone(str(clip.track_get_path(track).get_subname(0))))
  pilot_sampler.tracks[key]=bindings
 landing.configure(self);landing.parameters=landing_profile()
func begin_preview(_name:String) -> void:
 # The review family must never substitute the approved low landings or collapse.
 assert(Family.accepts(review_height),"Blender review supports 3 <= height < 8 m only")
 super.begin_preview("idle_to_fall")
 landing.parameters=landing_profile()
func landing_profile() -> Dictionary:
 return Family.profile(-Jump.GRAVITY*Fall.flight_duration(drop_height))
func preview_duration(_name:String="") -> float:return Fall.LEAD_IN+Fall.flight_duration(drop_height)+landing_profile().duration+Jump.SETTLE
func apply_clip(seconds:float,entry_weight:float=1.0) -> void:
 var sample_time:=clampf(seconds,0,PilotClip.length-.000001)
 var pose:Dictionary=pilot_sampler.sample("previous" if previous_clip else "pilot",sample_time)
 var heavy:Dictionary=pilot_sampler.sample("previous_heavy" if previous_clip else "heavy",sample_time)
 var weight:float=landing_profile().intensity
 for bone in native.parents.size():pose.poses[bone]=pose.poses[bone].interpolate_with(heavy.poses[bone],weight)
 if entry_weight<1:
  for bone in native.parents.size():pose.poses[bone]=airborne_source.poses[bone].interpolate_with(pose.poses[bone],entry_weight)
 var finish:=Jump.smooth5((seconds-IMPACT-1.55)/.25)
 if finish>0:
  var neutral:Dictionary=sampler.sample("idle",0)
  for bone in native.parents.size():pose.poses[bone]=pose.poses[bone].interpolate_with(neutral.poses[bone],finish)
 landing.restore(self,pose.poses);landing.write(self)
func apply_fall_pose(_source:Dictionary,_neutral:Dictionary,_vy:float,_gap:float) -> void:
 apply_clip(IMPACT*fall_time/Fall.flight_duration(drop_height),Jump.smooth5(fall_time/.16))
 landing.palm_planted=false;landing.support_loaded=false
func begin_recovery() -> void:
 position=Vector3(0,floor_y,distance_m);clip_start=position
 apply_clip(IMPACT);landing.begin_contacts(self)
 preview_stage="landing";stage_time=0;recovering=false
 jump_state.phase=4;jump_state.grounded=true;jump_state.vertical_velocity=0
func step_preview(dt:float) -> void:
 if preview_stage!="landing":super.step_preview(dt);return
 var p:=landing_profile()
 var step:=minf(dt,p.duration-stage_time);stage_time+=step;position=clip_start
 var clip_time:float=stage_time/p.scale
 apply_clip(IMPACT+clip_time);landing.apply_contacts(self,clip_time)
 fall_response.update(step,true,0,0)
 jump_state.phase=4;jump_state.grounded=true;jump_state.vertical_velocity=0
 if stage_time>=p.duration-.0000001:
  var at:=position;var travelled:=distance_m
  reset_motion("idle");distance_m=travelled;position=at
  for contact in contacts:contact.anchor.z+=travelled;contact.nominal.z+=travelled
  preview_stage="settle";stage_time=0
 if dt-step>.0000001:step_preview(dt-step)
