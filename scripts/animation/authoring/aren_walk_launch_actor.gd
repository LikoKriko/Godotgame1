extends "res://scripts/animation/authoring/aren_short_run_actor.gd"
const ArmPreparation=preload("res://scripts/animation/authoring/aren_arm_preparation.gd")
var arm_session:=false
var arm_charge:=0.0
var arm_start_phase:=0.0
var arm_progress:=0.0
var arm_lead:=0
var arm_strength:=1.0
var arm_amounts:Array[float]=[0.0,0.0]
var arm_forward:Array[float]=[0.0,0.0]
var arm_fold:Array[float]=[0.0,0.0]
var arm_forward_velocity:Array[float]=[0.0,0.0]
var arm_fold_velocity:Array[float]=[0.0,0.0]
func reset_motion(gait:String="idle",at_phase:float=0.0) -> void:
 arm_session=false;arm_charge=0;arm_start_phase=at_phase;arm_progress=0
 arm_amounts=[0.0,0.0];arm_forward=[0.0,0.0];arm_fold=[0.0,0.0]
 arm_forward_velocity=[0.0,0.0];arm_fold_velocity=[0.0,0.0]
 super.reset_motion(gait,at_phase)
func request_transition(name:String) -> void:
 arm_session=name in ["idle_to_run","walk_to_run"]
 if arm_session:
  arm_charge=0;arm_start_phase=phase;arm_progress=0
  arm_lead=0 if fposmod(phase,1)<.5 else 1
  arm_strength=1.0 if name=="idle_to_run" else profile.arm_prepare.walk_gain
 super.request_transition(name)
func render_pose(prepare:float) -> void:
 super.render_pose(prepare)
 if correction_tick>0:
  var p:Dictionary=profile.arm_prepare
  if arm_session:
   arm_charge=maxf(arm_charge,prepare)
   var steps:float=clampf((phase-arm_start_phase)*2/p.recovery_steps,0,1)
   var velocity:float=clampf((current_speed-start_speed)/maxf(speed_for("run")-start_speed,.001),0,1)
   arm_progress=maxf(arm_progress,maxf(steps,velocity))
  for side in 2:
   var delayed:bool=side!=arm_lead
   var onset:float=p.lag_onset if delayed else p.lead_onset
   var activation:float=smooth5(clampf((arm_charge-onset)/maxf(1-onset,.001),0,1))
   var target:float=activation*(1-smooth5(arm_progress))*arm_strength if arm_session else 0.0
   # Filter the actual angles so changing the leading side cannot swap poses.
   var forward_target:float=target*(p.lag_forward_deg if delayed else p.lead_forward_deg)
   var fold_target:float=target*(p.lag_fold_deg if delayed else p.lead_fold_deg)
   var forward:=spring(arm_forward[side],arm_forward_velocity[side],forward_target,correction_tick,p.response)
   var folded:=spring(arm_fold[side],arm_fold_velocity[side],fold_target,correction_tick,p.response)
   arm_forward[side]=forward.x;arm_forward_velocity[side]=forward.y
   arm_fold[side]=folded.x;arm_fold_velocity[side]=folded.y
   arm_amounts[side]=maxf(absf(forward.x)/p.lead_forward_deg,absf(folded.x)/p.lead_fold_deg)
  if arm_progress>=1 and arm_amounts[0]+arm_amounts[1]<.00001:arm_session=false
 if arm_amounts[0]+arm_amounts[1]>.000001:
  var p:Dictionary=profile.arm_prepare
  var gain:float=p.states[style]
  for side in 2:
   ArmPreparation.apply(native,side,1.0,arm_forward[side]*gain,arm_fold[side]*gain)
  for bone in native.parents.size():native.local_globals[bone]=native.inverse_frame*native.posed[bone]
  native.writer.apply(native.skeleton,native.local_globals)
