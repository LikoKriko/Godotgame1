extends "res://scripts/animation/authoring/aren_fall_actor.gd"
## Isolated 3 m / normal / idle pilot. Approved gameplay and clips stay intact.
const PilotClip=preload("res://assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/landing_3m.res")
const CycleSampler=preload("res://scripts/animation/authoring/aren_cycle_sampler.gd")
const PilotContacts=preload("res://scripts/animation/authoring/aren_blender_landing_contacts.gd")
const IMPACT=47.0/60
var landing=PilotContacts.new()
var pilot_sampler=CycleSampler.new()
var clip_start:=Vector3.ZERO
func _ready() -> void:
 review_height=3
 super._ready()
 pilot_sampler.configure(library,native.skeleton)
 pilot_sampler.clips["pilot"]=PilotClip
 var bindings:Array=[]
 for track in PilotClip.get_track_count():bindings.append(native.skeleton.find_bone(str(PilotClip.track_get_path(track).get_subname(0))))
 pilot_sampler.tracks["pilot"]=bindings
 landing.configure(self);landing.parameters=landing_profile()
func begin_preview(_name:String) -> void:
 review_height=3
 super.begin_preview("idle_to_fall")
func landing_profile() -> Dictionary:
 return {"duration":1.8,"absorb":.20,"release":23.0/60,"release_end":.65,"hold":.42,"rise_end":1.50,"intensity":0.0}
func preview_duration(_name:String="") -> float:return Fall.LEAD_IN+Fall.flight_duration(3)+1.8+Jump.SETTLE
func apply_clip(seconds:float,entry_weight:float=1.0) -> void:
 var pose:Dictionary=pilot_sampler.sample("pilot",clampf(seconds,0,PilotClip.length-.000001))
 if entry_weight<1:
  for bone in native.parents.size():pose.poses[bone]=airborne_source.poses[bone].interpolate_with(pose.poses[bone],entry_weight)
 var finish:=Jump.smooth5((seconds-IMPACT-1.55)/.25)
 if finish>0:
  var neutral:Dictionary=sampler.sample("idle",0)
  for bone in native.parents.size():pose.poses[bone]=pose.poses[bone].interpolate_with(neutral.poses[bone],finish)
 landing.restore(self,pose.poses);landing.write(self)
func apply_fall_pose(_source:Dictionary,_neutral:Dictionary,_vy:float,_gap:float) -> void:
 apply_clip(IMPACT*fall_time/Fall.flight_duration(3),Jump.smooth5(fall_time/.16))
 landing.palm_planted=false;landing.support_loaded=false
func begin_recovery() -> void:
 position=Vector3(0,floor_y,distance_m);clip_start=position
 apply_clip(IMPACT);landing.begin_contacts(self)
 preview_stage="landing";stage_time=0;recovering=false
 jump_state.phase=4;jump_state.grounded=true;jump_state.vertical_velocity=0
func step_preview(dt:float) -> void:
 if preview_stage!="landing":super.step_preview(dt);return
 var step:=minf(dt,1.8-stage_time);stage_time+=step;position=clip_start
 apply_clip(IMPACT+stage_time);landing.apply_contacts(self,stage_time)
 fall_response.update(step,true,0,0)
 jump_state.phase=4;jump_state.grounded=true;jump_state.vertical_velocity=0
 if stage_time>=1.8-.0000001:
  var at:=position;var travelled:=distance_m
  reset_motion("idle");distance_m=travelled;position=at
  for contact in contacts:contact.anchor.z+=travelled;contact.nominal.z+=travelled
  preview_stage="settle";stage_time=0
 if dt-step>.0000001:step_preview(dt-step)
