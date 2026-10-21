extends "res://scripts/animation/authoring/aren_fall_actor.gd"
## Step 8 review. The previous fall actor remains selectable and unchanged.
const Landing=preload("res://scripts/animation/authoring/aren_landing_motion.gd")
const LandingPose=preload("res://scripts/animation/authoring/aren_kneeling_landing_pose.gd")
var landing=LandingPose.new()
var landing_contact:=Vector3.ZERO
var landing_velocity:=Vector3.ZERO
var landing_exit:Dictionary={}
func _ready() -> void:
 review_height=3.0
 super._ready()
func begin_preview(name:String) -> void:
 landing.active=false
 super.begin_preview(name)
func preview_duration(name:String="") -> float:
 return Fall.LEAD_IN+Fall.flight_duration(drop_height)+(Landing.profile(-sqrt(2*Jump.GRAVITY*drop_height)).duration if Landing.accepts(drop_height) else Fall.recovery_duration(drop_height))+Jump.SETTLE
func apply_fall_pose(source:Dictionary,neutral:Dictionary,velocity_y:float,ground_gap:float) -> void:
 super.apply_fall_pose(source,neutral,velocity_y,ground_gap)
 if Landing.accepts(drop_height):landing.prepare(self,ground_gap,-sqrt(2*Jump.GRAVITY*drop_height))
func begin_recovery() -> void:
 if not Landing.accepts(drop_height):super.begin_recovery();return
 # Feet contact at the original ballistic time; no extra airborne delay.
 landing_contact=Vector3(0,floor_y,distance_m);position=landing_contact
 landing_velocity=Vector3(0,0,jump_speed)
 landing.start(self,drop_height,-sqrt(2*Jump.GRAVITY*drop_height),landing_velocity)
 preview_stage="landing";stage_time=0;recovering=false
 jump_state.phase=4;jump_state.grounded=true;jump_state.vertical_velocity=0
 landing_exit=landing.neutral
func step_preview(dt:float) -> void:
 if preview_stage!="landing":super.step_preview(dt);return
 var step:float=minf(dt,maxf(0,landing.parameters.duration-stage_time))
 stage_time+=step
 position=landing_contact+landing_velocity*Landing.carry(stage_time,landing.parameters)
 distance_m=position.z
 landing.apply(self,stage_time,landing_exit)
 jump_state.phase=4;jump_state.grounded=true;jump_state.vertical_velocity=0
 fall_response.update(step,true,0,0)
 if stage_time>=landing.parameters.duration-.0000001:
  var at:=position;var travelled:=distance_m
  # Re-enter the existing ground clock and bridge from the final visible pose.
  landing_exit=capture_pose()
  reset_motion("idle");distance_m=travelled;position=at
  if jump_target!="idle":request_transition("idle_to_"+jump_target)
  preview_stage="settle";stage_time=0
 if dt-step>.0000001:step_preview(dt-step)

func landing_profile() -> Dictionary:return landing.review_profile(-sqrt(2*Jump.GRAVITY*drop_height))

func set_posture_reference(previous:bool) -> void:
 var at:=preview_clock
 landing.set_posture_reference(previous)
 begin_preview(preview_name)
 advance_jump_preview(at)
