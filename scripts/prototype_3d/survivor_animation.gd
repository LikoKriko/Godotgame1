extends RefCounted
## Reuses the game's gesture/stance timing with the 3D survivor's shared anatomy.
const Pose = preload("res://scripts/continuous_body_pose.gd")
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Aim = preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles = preload("res://scripts/prototype_3d/held_profiles.gd")
const Weapons=preload("res://scripts/prototype_3d/weapon_motion.gd")
const Fall=preload("res://scripts/prototype_3d/fall_motion.gd")
const Slide=preload("res://scripts/prototype_3d/slide_pose.gd")
const Controls=preload("res://scripts/animation/characters/survivor_controls.gd")
const STRIDE_SCALE:=1.3
# Independent visual adjustments; they never change CharacterBody velocity.
const GAIT_STRIDE_LENGTH:=1.10
const GAIT_PLAYBACK_RATE:=.90
const RUN_PLAYBACK_RATE:=.60
const ARM_SWING_SCALE:=0.9
const SLIDE_STATES:Array[StringName]=[&"slide",&"slide_back",&"slide_back_left",&"slide_back_right",&"slide_left",&"slide_right",&"slide_forward_left",&"slide_forward_right"]
const RUN_HIP_SCALE:=.7
const LATERAL_STEP_SCALE:=.45
const LATERAL_LIFT_SCALE:=.40
const GAIT_HIP_REDUCTION:=.40
const GAIT_HIP_MOTION:=.45
const GAIT_LOWERING:=.15
const WALK_ARM_LAG_SECONDS:=.025
const SWORD_BALANCE_MOTION:=.80
const FAMILIES: Array[StringName] = [&"",&"axe",&"pickaxe",&"sword",&"bow",&"bottle",&"food",&"carried"]
const STATES: Array[StringName] = [&"idle",&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch",&"crouch_walk",&"slide",&"slide_back",&"slide_back_left",&"slide_back_right",&"slide_left",&"slide_right",&"slide_forward_left",&"slide_forward_right",&"jump",&"slide_jump",&"equip",&"equip_walk",&"equip_run",&"equip_crouch",&"equip_crouch_walk",&"unequip",&"action",&"draw",&"bow_release",&"pickup",&"pickup_walk",&"eat",&"eat_walk",&"drink",&"drink_walk",&"parry",&"hurt",&"death"]

static func duration(state: StringName,family: StringName = &"") -> float:
 if state==&"death": return 3.0
 if state in [&"eat",&"eat_walk",&"drink",&"drink_walk"]: return 1.2
 if state in [&"pickup",&"pickup_walk"]: return 0.72
 if state in SLIDE_STATES: return 0.46
 if state in [&"jump",&"slide_jump"]: return 0.66
 if state==&"crouch_walk":return 1.25*STRIDE_SCALE
 if state==&"bow_release":return .24
 if state==&"draw": return 0.5
 if state==&"action": return 1.0125 if family==&"sword" else 0.75
 if String(state).begins_with("equip") or state==&"unequip": return 0.5 if family==&"pickaxe" else 0.42
 if state==&"start_run":return .16
 if state==&"stop_run":return .24
 if state==&"start": return 0.14
 if state==&"stop": return 0.18
 if state in [&"walk",&"run"]:return (0.45 if state==&"run" else 0.60)*STRIDE_SCALE
 return 0.60

# Reference distance of one left/right cycle, before visual tuning.
static func directional_stride(direction:Vector3) -> float:
 return lerpf(1.0,.44,absf(direction.normalized().x))

static func cycle_distance(sprint_weight:float,crouch:float=0.0,direction:Vector3=Vector3.BACK) -> float:
 return lerpf(duration(&"walk")*2.0,duration(&"run")*3.2,clampf(sprint_weight,0,1))*lerpf(1.0,.68,crouch)*directional_stride(direction)

static func gait_playback_rate(sprint_weight:float) -> float:
 return GAIT_PLAYBACK_RATE*lerpf(1.0,RUN_PLAYBACK_RATE,clampf(sprint_weight,0,1))

static func sample(family: StringName,state: StringName,phase: float,movement_phase: float = 0.0,movement: Vector3 = Vector3.ZERO,contact: Vector3 = Vector3.INF,slide_launch:Dictionary={},crouch_amount:float=0.0,punch_side:int=1) -> Dictionary:
 if String(state).begins_with("equip") or state==&"unequip":
  return equipment_pose(family,state,phase,movement_phase,movement,contact)
 if state==&"death":
  var dying:=sample(&"",&"idle",0)
  dying.family=family;dying.clip_state=&"death";dying.state=&"death";dying.phase=clampf(phase,0,1)
  return solve_legs(Fall.human(dying,phase))
 var source_state := &"run" if state in SLIDE_STATES else state
 if family==&"" and state==&"action":source_state=&"idle"
 if state in [&"pickup",&"pickup_walk"]:source_state=&"walk" if state==&"pickup_walk" else &"idle"
 if state==&"draw" or (family==&"bow" and state==&"action"):source_state=&"idle"
 if state==&"bow_release":source_state=&"walk" if not movement.is_zero_approx() else &"idle"
 if state in [&"drink",&"drink_walk"]: source_state=&"eat_walk" if state==&"drink_walk" else &"eat"
 if state in [&"parry",&"hurt"]: source_state=&"idle"
 var pose := Pose.sample(&"food" if state in [&"drink",&"drink_walk"] else family,source_state,movement_phase if state in SLIDE_STATES or state==&"bow_release" else phase,1.0 if source_state==&"equip_crouch" else movement_phase,1.0,-1)
 pose.leg_poles=[Vector3.BACK,Vector3.BACK]
 pose.leg_frame=Basis.IDENTITY
 pose.family=family;pose.clip_state=state;pose.gait_phase=phase if state in [&"walk",&"run",&"crouch_walk"] else movement_phase
 pose.look_contact=contact
 pose.upright_attack=state==&"action" and family!=&"bow" and crouch_amount<1.0
 pose.attack_stance_weight=1-clampf(crouch_amount,0,1)
 if family==&"" and state==&"action":pose.active=clampi(punch_side,0,1)
 var original_body: Transform3D = pose.body
 var body: Transform3D = original_body
 # An archer opens the chest obliquely: bow arm forward, drawing shoulder back.
 if family==&"bow" and state not in [&"death",&"pickup",&"eat",&"drink"]:
  body.basis=body.basis*Basis(Vector3.UP,0.40)
 if state==&"action" or state==&"draw":
  # Keep the pelvis near standing height; aim with shoulder/arm IK first.
  var standing_y:=Anatomy.HIP.y
  var pelvis:Vector3=body*Vector3(0,standing_y,0)
  body.origin.y+=maxf(0,standing_y-1.2-pelvis.y)
 # Crouching is a stance layer on the gesture, applied before tool/contact IK.
 # Lowering a finished standing animation would move its tip off the aim point.
 if state in [&"action",&"draw",&"bow_release"] and crouch_amount>0:
  var amount:=clampf(crouch_amount,0,1)
  var hinge:=Basis(Vector3.RIGHT,0.08*amount)
  var pivot:=Vector3(0,Anatomy.HIP.y,0)
  body=Transform3D(hinge,pivot-hinge*pivot+Vector3(0,-6.0*amount,-0.45*amount))*body
 # An impact transfers weight through the chest and pelvis before settling.
 var recoil := 0.0
 if state==&"action" and family!=&"bow": recoil=sin(clampf((phase-0.5)/0.16,0,1)*PI)*exp(-maxf(0,phase-0.5)*4)
 if state==&"hurt": recoil=sin(phase*PI)
 var guard_amount:=smoothstep(0,0.2,phase)*(1-smoothstep(0.65,1,phase)) if state==&"parry" else 0.0
 var low_guard:=clampf(32-contact.y,0,12)*guard_amount if state==&"parry" and contact.is_finite() else 0.0
 body.origin.y-=low_guard
 if state==&"action" and family in [&"axe",&"pickaxe",&"sword"] and contact.is_finite():
  var bend:=clampf(30-contact.y,0,2.5)*smoothstep(0.15,0.5,phase)*(1-smoothstep(0.65,1,phase))
  body.origin.y-=bend
  body.basis=body.basis*Basis(Vector3.RIGHT,bend*0.008)
 body.origin.z-=recoil*0.65
 body.basis=body.basis*Basis(Vector3.RIGHT,-recoil*0.045)
 if state==&"idle": body.origin.y+=sin(phase*TAU)*0.12
 pose.body=body
 for side in 2:
  pose.shoulders[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.hips[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.hands[side]=body*Anatomy.limb(original_body.affine_inverse()*pose.hands[side])
  pose.legs[side].end.x*=Anatomy.BODY_WIDTH
 pose.grip=body*(Anatomy.limb(original_body.affine_inverse()*pose.grip)+(Vector3(0,2,5.1) if family in [&"axe",&"pickaxe"] else Vector3(0,0,2.6)))
 if state==&"parry":
  var raised := guard_amount
  var guard_height:=31.0 if low_guard>0 else 42.0
  for side in 2: pose.hands[side]=pose.hands[side].lerp(body*Vector3(-5 if side==0 else 5,guard_height+1,9),raised)
  pose.grip=pose.grip.lerp(body*Vector3(-3 if pose.active==0 else 3,guard_height,9),raised)
  pose.shaft=pose.shaft.lerp((body.basis*Vector3(0.55,0.7,0.45)).normalized(),raised).normalized()
 if family==&"carried":
  for side in 2: pose.hands[side]=body*Vector3(-5 if side==0 else 5,33,10)
  pose.grip=pose.hands[1];pose.shaft=body.basis*Vector3.LEFT
 if state in [&"walk",&"run"]:keyed_locomotion(pose,state,phase)
 if not movement.is_zero_approx() and state not in [&"slide",&"slide_back",&"slide_back_left",&"slide_back_right",&"slide_left",&"slide_right",&"slide_forward_left",&"slide_forward_right",&"jump",&"slide_jump",&"death"]:
  var travel:=Vector3(movement.x,0,movement.z).normalized()
  # Rotate the stance lanes and knee/foot frames together. Keeping the old
  # frontal lanes clips the inward half of a diagonal step into a sideways fan.
  var forward_travel:=travel if travel.z>=0 else -travel
  var yaw:=clampf(atan2(forward_travel.x,forward_travel.z),-PI/4,PI/4)*smoothstep(0,0.35,absf(travel.z))
  if state!=&"pickup_walk":
   pose.leg_frame=Basis(Vector3.UP,yaw)
   pose.leg_poles=[pose.leg_frame*Vector3.BACK,pose.leg_frame*Vector3.BACK]
  var gait_state:StringName=&"run" if state in [&"run",&"start_run",&"stop_run"] else &"walk"
  var gait_phase:float=phase if state in [&"walk",&"run",&"crouch_walk"] else movement_phase
  var keys:=Controls.sample(gait_state,gait_phase)
  var crouched:=state==&"crouch_walk"
  # A side shuffle stays under the hips. Blend from diagonal travel instead
  # of reserving a wide, symmetric opening on every support transfer.
  var lateral:=smoothstep(sqrt(.5),1,absf(travel.x))
  var stride:=directional_stride(travel)*(.68 if crouched else 1.0)*lerpf(1,LATERAL_STEP_SCALE,lateral)
  # A lateral step needs room to open and close. Reserve the complete path
  # before IK, rather than clipping the inward half against the other foot.
  var support:=.40 if gait_state==&"run" else lerpf(.60,.45,absf(travel.x))
  var reach:=cycle_distance(1.0 if gait_state==&"run" else 0.0)*support*.5/(Anatomy.HEIGHT_METRES/64)*stride*GAIT_STRIDE_LENGTH
  var lane:=maxf(Anatomy.HIP.x,Anatomy.FOOT_HALF_WIDTH+Anatomy.FOOT_GAP*.5+absf(travel.dot(pose.leg_frame.x))*reach*1.04)
  pose.stance_lane=lane
  # The run return arc briefly extends beyond the stance endpoints.
  pose.gait_extent=reach*(1.18 if gait_state==&"run" else 1.05)
  pose.gait_travel=travel
  for side in 2:
   var foot:Vector3=keys.foot_l if side==0 else keys.foot_r
   if gait_state==&"walk" and absf(travel.x)>.001:
    # Shorter lateral contact gives a quicker, less spread side step while
    # preserving planted speed. Resample the same reduced control curve.
    var p:=fposmod(gait_phase+side*.5,1.0)
    var mapped:=p/support*.60 if p<support else .60+(p-support)/(1-support)*.40
    foot=Controls.sample(&"walk",mapped).foot_l
    foot.x*=support/.60
   var step:=foot.x*stride/STRIDE_SCALE
   pose.legs[side].end=pose.leg_frame*Vector3((-1 if side==0 else 1)*lane,2.1+foot.y*(.70 if crouched else 1.0)*lerpf(1,LATERAL_LIFT_SCALE,lateral),0)+travel*step
   pose.legs[side].pitch=foot.z*travel.z

 var striding:=state in [&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch_walk",&"equip_walk",&"equip_run",&"equip_crouch_walk",&"pickup_walk",&"eat_walk",&"drink_walk"] or (not movement.is_zero_approx() and state in [&"action",&"unequip",&"bow_release"])
 if striding:
  lengthen_stride(pose,STRIDE_SCALE*GAIT_STRIDE_LENGTH);body=pose.body
  # Free walking arms retain their resting depth and share the slower gait.
  if state not in [&"run",&"start_run",&"equip_run"]:
   for side in 2:
    if not arm_is_free(pose,side):continue
    var local:Vector3=body.affine_inverse()*pose.hands[side]
    local.z=lerpf(3.5*Anatomy.BODY_DEPTH,local.z,ARM_SWING_SCALE)
    pose.hands[side]=body*local
 natural_motion(pose,state,phase,movement_phase,movement,contact,striding)
 if state in [&"action",&"draw"] and family in [&"axe",&"pickaxe",&"sword",&"bow"]:reduce_weapon_pitch(pose,crouch_amount)
 if state==&"action" and family!=&"bow":reduce_attack_knees(pose,phase,movement_phase,movement,crouch_amount)
 if upright_gait(pose):
  raise_gait(pose)
  if not pose.upright_attack:calm_gait(pose)
 body=pose.body
 if state in SLIDE_STATES:
  lengthen_stride(pose)
  for side in 2:
   var arm:=running_arm(pose,side,movement_phase)
   if not arm.is_empty():pose.hands[side]=arm.end
  Slide.apply(pose,phase,state);body=pose.body
 if family==&"" and state==&"action":
  punch(pose,phase)
 if family==&"axe":
  var shaft:Vector3=pose.shaft.normalized()
  var edge:Vector3=body.basis*Vector3.BACK;edge-=shaft*edge.dot(shaft)
  if edge.length_squared()<0.01:edge=body.basis*Vector3.RIGHT
  edge=edge.normalized();pose.tool_basis=Basis(edge,shaft,edge.cross(shaft).normalized())
 Weapons.carry(pose,state,phase,movement_phase)
 if family in Weapons.MELEE and state==&"action":
  var impact_pose:Dictionary={}
  if contact.is_finite() and not is_equal_approx(phase,.5):impact_pose=sample(family,&"action",.5,movement_phase,movement,contact,slide_launch,crouch_amount)
  Weapons.melee(pose,phase,contact,impact_pose);body=pose.body
 if family==&"sword" and state==&"action":
  # The empty arm opens away from the strike as a counterweight. Keep a soft
  # elbow instead of locking the joint, then return smoothly after the effort.
  var free_side:int=1-pose.active
  var opening:float=Controls.sample(&"sword",phase).effort.z
  var outward:Vector3=Vector3(-0.86 if free_side==0 else 0.86,-0.38,-0.34).normalized()
  var rest_offset:Vector3=body.basis.inverse()*(relaxed_arm(pose,free_side).end-pose.shoulders[free_side])
  var lower_y:=lerpf(rest_offset.y,outward.y*18.3,.3)
  var horizontal:=Vector2(outward.x,outward.z).normalized()*sqrt(maxf(0,18.3*18.3-lower_y*lower_y))
  var counterweight:Vector3=pose.shoulders[free_side]+body.basis*Vector3(horizontal.x,lower_y,horizontal.y)
  var relaxed:Dictionary=relaxed_arm(pose,free_side)
  pose.hands[free_side]=relaxed.end.lerp(counterweight,opening*SWORD_BALANCE_MOTION)
 if family==&"bow":Weapons.bow(pose,state,phase,contact)
 if family==&"bottle" and state in [&"idle",&"walk",&"run",&"crouch",&"crouch_walk"]:
  pose.grip=body*Vector3(-10 if pose.active==0 else 10,32,8)
 if state in [&"drink",&"drink_walk"]:
  var amount:=smoothstep(0,0.25,phase)*(1-smoothstep(0.75,1,phase))
  var local_axis:=Vector3.UP.lerp(Vector3(0,0.65,-0.75),amount).normalized()
  var lip_grip:Vector3=Anatomy.MOUTH-local_axis*Profiles.profile(&"bottle").tip.y
  pose.grip=body*Vector3(-10 if pose.active==0 else 10,32,8).lerp(lip_grip,amount)
  pose.shaft=body.basis*local_axis
 if state in [&"eat",&"eat_walk"] and family==&"food":
  var amount:=smoothstep(0,0.25,phase)*(1-smoothstep(0.75,1,phase))
  pose.grip=pose.grip.lerp(body*(Anatomy.MOUTH-Vector3(0,1.0,-0.2)),amount)
 for side in 2:
  if pose.hands[side].y>30 and pose.hands[side].y<55 and absf(pose.hands[side].x)<7 and family!=&"bow":
   pose.hands[side].z=maxf(pose.hands[side].z,4.8)
 if state in [&"pickup",&"pickup_walk"] and contact.is_finite():
  var reach:=pickup_weight(phase)
  pose.hands[0].y=maxf(pose.hands[0].y,5.0*reach)
  pose.hands[1]=pose.hands[1].lerp(contact,reach)
  pose.contact_reachable=pose.shoulders[1].distance_to(contact)>=8.15 and pose.shoulders[1].distance_to(contact)<=Pose.UPPER_ARM+Pose.FOREARM-0.04 and contact.z>=4.8
 clear_soles(pose)
 if state in [&"jump",&"slide_jump"]:
  keyed_jump(pose,phase)
  jump_arms(pose,phase)
 if state==&"slide_jump":
  var launch:Dictionary=slide_launch if not slide_launch.is_empty() else sample(family,&"slide",0.55,movement_phase)
  Slide.jump_from(pose,launch,phase)
 return solve_legs(pose)

static func equipment_pose(family:StringName,state:StringName,phase:float,gait:float,movement:Vector3,contact:Vector3) -> Dictionary:
 var locomotion:=StringName(String(state).trim_prefix("equip_")) if String(state).begins_with("equip_") else &"idle"
 if state==&"unequip":locomotion=&"walk" if not movement.is_zero_approx() else &"idle"
 var cycle:=1.0 if locomotion==&"crouch" else (0.0 if locomotion==&"idle" else gait)
 var empty:=sample(&"",locomotion,cycle,gait,movement)
 var ready:=sample(family,locomotion,cycle,gait,movement,contact)
 var t:=clampf(1-phase if state==&"unequip" else phase,0,1)
 var weight:=smoothstep(0,1,t)
 var pose:=ready.duplicate(true)
 pose.body=empty.body.interpolate_with(ready.body,weight)
 pose.pelvis=empty.pelvis.interpolate_with(ready.pelvis,weight)
 pose.clip_state=state;pose.state=state;pose.phase=phase;pose.equipment_weight=weight
 pose.support_weight=smoothstep(.25,.85,t)
 pose.equipment_poles=[];pose.equipment_palms=[];pose.equipment_axes=[]
 for side in 2:
  pose.shoulders[side]=pose.body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.hips[side]=pose.pelvis*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  var ready_arm:=relaxed_arm(ready,side) if locomotion==&"idle" else {}
  if not ready_arm.is_empty():ready.hands[side]=ready_arm.end
  # Match the actual relaxed limb used at idle, not the old generic hand keys.
  var arm:=relaxed_arm(empty,side) if locomotion==&"idle" else {}
  if arm.is_empty():arm=preload("res://scripts/prototype_3d/human_kinematics.gd").arm(empty.shoulders[side],empty.hands[side],empty.body.basis,side,true)
  empty.hands[side]=arm.end
  pose.equipment_poles.append(arm.joint-arm.root)
  pose.equipment_axes.append((arm.end-arm.root).normalized())
  pose.equipment_palms.append(preload("res://scripts/prototype_3d/human_kinematics.gd").hand_frame(arm,empty.body.basis,side))
  pose.hands[side]=(empty.hands[side] as Vector3).lerp(ready.hands[side],weight)
 var start:Vector3=empty.hands[pose.active]
 var sign_side:float=-1 if pose.active==0 else 1
 var arc:=sin(t*PI)
 pose.grip=start.lerp(ready.grip,weight)+pose.body.basis*Vector3(sign_side*arc,arc*1.4,arc*4.0)
 var initial:=Weapons.frame(empty.body.basis,Vector3(sign_side*.25,.96,.12),family)
 var ending:Basis=ready.get("tool_basis",Aim.frame(ready.shaft))
 pose.tool_basis=initial.slerp(ending,weight);pose.shaft=pose.tool_basis.y
 if Profiles.profile(family).two_hands:
  pose.hands[1-pose.active]=(empty.hands[1-pose.active] as Vector3).lerp(pose.grip+pose.shaft*Profiles.profile(family).support,pose.support_weight)
 pose.hands[pose.active]=pose.grip
 return solve_legs(pose)

static func reduce_attack_knees(pose:Dictionary,phase:float,gait:float,movement:Vector3,crouch:float) -> void:
 # Reduce the additional flexion angle to 40%, retaining the crouched/walking
 # stance beneath the attack. Fixed bone lengths determine the new hip height.
 var state:StringName=(&"crouch_walk" if crouch>0 else &"walk") if not movement.is_zero_approx() else (&"crouch" if crouch>0 else &"idle")
 var base:=sample(&"",state,crouch if state==&"crouch" else gait,gait,movement)
 var rise:=INF
 var a:=Anatomy.THIGH;var b:=Anatomy.SHIN
 for side in 2:
  var hip:Vector3=pose.hips[side];var ankle:Vector3=pose.legs[side].end
  var old_distance:=clampf(hip.distance_to(ankle),absf(a-b)+.01,a+b-.04)
  var base_distance:=clampf((base.hips[side] as Vector3).distance_to(base.legs[side].end),absf(a-b)+.01,a+b-.04)
  var old_angle:=acos(clampf((old_distance*old_distance-a*a-b*b)/(2*a*b),-1,1))
  var base_angle:=acos(clampf((base_distance*base_distance-a*a-b*b)/(2*a*b),-1,1))
  var angle:=base_angle+maxf(0,old_angle-base_angle)*.4
  angle=minf(angle,old_angle)
  var distance:=sqrt(a*a+b*b+2*a*b*cos(angle))
  var horizontal:=Vector2(hip.x-ankle.x,hip.z-ankle.z).length_squared()
  rise=minf(rise,maxf(0,ankle.y+sqrt(maxf(0,distance*distance-horizontal))-hip.y))
 if not is_finite(rise) or rise<.00001:return
 pose.body.origin.y+=rise;pose.pelvis.origin.y+=rise
 for side in 2:
  pose.shoulders[side].y+=rise;pose.hips[side].y+=rise;pose.hands[side].y+=rise
 pose.grip.y+=rise

static func pickup_weight(phase:float) -> float:
 return smoothstep(0,0.5,phase)*(1-smoothstep(0.58,1,phase))

static func natural_motion(pose:Dictionary,state:StringName,phase:float,gait:float,movement:Vector3,contact:Vector3,striding:bool) -> void:
 var original:Transform3D=pose.body
 var chest:=original
 var pelvis:=original
 var pivot:=Vector3(0,Anatomy.HIP.y,0)
 var chest_rotation:=Vector3.ZERO
 var pelvis_rotation:=Vector3.ZERO
 var offset:=Vector3.ZERO
 if striding:
  var cycle:=phase if state in [&"walk",&"run",&"crouch_walk"] else gait
  var amount:=1.0
  if state in [&"start",&"start_run"]:amount=smoothstep(0,1,phase)
  if state in [&"stop",&"stop_run"]:amount=1-smoothstep(0,1,phase)
  var wave:=sin(cycle*TAU)*amount
  # Weight passes onto the support leg. Pelvis and rib cage counter-rotate;
  # occupied hands travel with the rib cage instead of an independent bob.
  var hip_scale:=RUN_HIP_SCALE if state in [&"run",&"start_run",&"stop_run",&"equip_run"] else 1.0
  offset.x=-wave*0.32*hip_scale
  pelvis_rotation=Vector3(0,wave*0.035*hip_scale+pose.leg_frame.get_euler().y*0.5,wave*0.012*hip_scale)
  chest_rotation=Vector3(0,-wave*0.025,-wave*0.014)
  if state in [&"walk",&"run"]:
   var keyed:=Controls.sample(state,cycle)
   offset=Vector3.ZERO
   pelvis_rotation=keyed.pelvis
   chest_rotation=Vector3.ZERO
 elif state==&"idle":
  var breath:=sin(phase*TAU)
  chest_rotation.x=breath*0.004
 if state in [&"crouch",&"crouch_walk",&"equip_crouch",&"equip_crouch_walk"]:
  var low:=phase if state==&"crouch" else 1.0
  chest_rotation.x+=low*0.08
  pelvis_rotation.x+=low*0.025
  offset.z-=low*0.45
 if state==&"action" and pose.family!=&"bow":
  var keyed:Dictionary=Controls.sample(pose.family,phase) if pose.family in Weapons.MELEE else {}
  var load:float=keyed.effort.x if not keyed.is_empty() else smoothstep(0,0.28,phase)*(1-smoothstep(0.52,0.9,phase))
  var drive:float=keyed.effort.y if not keyed.is_empty() else smoothstep(0.28,0.5,phase)*(1-smoothstep(0.62,1,phase))
  var sign_side:float=-1 if pose.active==0 else 1
  chest_rotation.y+=sign_side*(load*0.055-drive*0.095)
  pelvis_rotation.y+=sign_side*(load*0.025-drive*0.045)
  offset.z+=drive*0.55-load*0.3
  if pose.family==&"":
   chest_rotation.y+=sign_side*(load*.10-drive*.15)
   pelvis_rotation.y+=sign_side*(load*.045-drive*.075)
  if pose.family==&"axe":
   chest_rotation.y+=-(load*.08-drive*.10);chest_rotation.x+=-load*.035+drive*.07
   pelvis_rotation.y+=-(load*.025-drive*.035)
  elif pose.family==&"pickaxe":
   chest_rotation.x+=-load*.045+drive*.11;pelvis_rotation.x+=drive*.025
  elif pose.family==&"sword":
   chest_rotation.y+=load*.10-drive*.14;pelvis_rotation.y+=load*.04-drive*.055
  if contact.is_finite() and pose.family in [&"axe",&"pickaxe",&"sword"]:
   var low:=1-smoothstep(10,35,contact.y)
   offset.y-=low*7.0*drive
   chest_rotation.x+=low*0.48*drive
   pelvis_rotation.x+=low*0.06*drive
   offset.z+=low*0.7*drive
 if String(state).begins_with("equip") or state==&"unequip":
  var arc:=sin(phase*PI)
  var sign_side:float=-1 if pose.active==0 else 1
  chest_rotation.y+=sign_side*arc*0.045
  pose.grip+=original.basis*Vector3(sign_side*arc*1.1,arc*1.0,arc*1.5)
 if state in [&"eat",&"eat_walk",&"drink",&"drink_walk"]:
  chest_rotation.x+=sin(phase*TAU*2)*0.008*pickup_weight(phase)
 if pose.family==&"bow" and state in [&"draw",&"action",&"bow_release"]:
  var opening:=smoothstep(.08,.85,phase) if state!=&"bow_release" else 1-smoothstep(.45,1,phase)
  chest_rotation.y+=opening*.38;pelvis_rotation.y+=opening*.12
 if state==&"jump":
  var airborne:=sin(clampf(phase,0,1)*PI)
  chest_rotation.x-=airborne*0.045
 if state==&"parry":
  offset.z-=pickup_weight(phase)*0.45
 if state==&"hurt":
  chest_rotation.z+=sin(phase*PI)*0.045
 if state in [&"pickup",&"pickup_walk"]:
  var reach:=pickup_weight(phase)
  var point:=contact if contact.is_finite() else Vector3(5,4,19)
  # A hip hinge and knee bend bring the shoulder within arm reach. Keep feet
  # planted; never reach ground objects by lengthening an arm or floating a foot.
  var low:=1-smoothstep(5,45,point.y)
  chest_rotation.x+=lerpf(0.08,0.86,low)*reach
  pelvis_rotation.x+=lerpf(0.04,0.32,low)*reach
  offset.y-=lerpf(0,22.2,low)*reach
  offset.z+=clampf(point.z-18,-2,12)*reach
  offset.x+=clampf(point.x-5,-6,6)*0.22*reach
  var step:=smoothstep(0,0.30,phase)*(1-smoothstep(0.74,1,phase))*low
  var advance:=clampf(point.z-18,-2,12)
  for side in 2:
   # A short staggered placement precedes the deep bend. Keeping both heels
   # behind a low, forward pelvis would drive the knees through the ground.
   var placement:=maxf(0,advance-1) if side==0 else maxf(0,advance+8)
   # During a moving pickup shorten the step before loading the crouched leg;
   # a full rearward walking stride cannot support a deep forward reach.
   pose.legs[side].end.z=lerpf(pose.legs[side].end.z,placement,step)
   pose.legs[side].end.y=lerpf(pose.legs[side].end.y,2.1,reach*low)
   var lift:=sin(clampf(phase/0.30,0,1)*PI) if phase<0.30 else sin(clampf((phase-0.74)/0.26,0,1)*PI)
   pose.legs[side].end.y+=lift*1.3*low
  pose.hands[0]=pose.hands[0].lerp(original*Vector3(-10,32,10),reach)
 if state not in SLIDE_STATES and state not in [&"slide_jump",&"death"]:
  chest=Transform3D(Basis.from_euler(chest_rotation),pivot+offset-Basis.from_euler(chest_rotation)*pivot)*original
  pelvis=Transform3D(Basis.from_euler(pelvis_rotation),pivot+offset-Basis.from_euler(pelvis_rotation)*pivot)*original
  if state in [&"run",&"start_run",&"stop_run",&"equip_run"]:
   var cycle:float=phase if state==&"run" else gait
   var amount:=smoothstep(0,1,phase) if state==&"start_run" else (1-smoothstep(0,1,phase) if state==&"stop_run" else 1.0)
   var euler:=pelvis.basis.get_euler()
   euler.x-=(1-RUN_HIP_SCALE)*.025*sin(cycle*TAU)*amount
   var reduced:=Basis.from_euler(euler)
   pelvis.origin+=pelvis.basis*pivot-reduced*pivot
   pelvis.basis=reduced
   pelvis.origin.y+=(1-RUN_HIP_SCALE)*.65*cos(cycle*TAU*2)*amount
  if striding:
   # Reduce total gait rotation, retaining the constant forward lean. Scaling
   # only the counter-rotation would actually increase the final hip swing.
   var pivot_world:Vector3=pelvis*pivot
   var calm:=Basis(Vector3.RIGHT,pelvis.basis.get_euler().x)
   pelvis.basis=calm.slerp(pelvis.basis,GAIT_HIP_MOTION)
   pelvis.origin=pivot_world-pelvis.basis*pivot
  var change:=chest*original.affine_inverse()
  pose.body=chest
  pose.pelvis=pelvis
  pose.grip=change*pose.grip
  pose.shaft=change.basis*pose.shaft
  for side in 2:
   pose.shoulders[side]=chest*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
   pose.hips[side]=pelvis*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
   pose.hands[side]=change*pose.hands[side]
 else:pose.pelvis=pose.body

static func lengthen_stride(pose:Dictionary,horizontal_scale:float=STRIDE_SCALE) -> void:
 # Keep the existing stance/lift curve, extending only horizontal travel.
 # Settle the pelvis just enough to reach both planted feet with fixed bones;
 # otherwise clamped IK would shorten the requested step or lift a support foot.
 var settle:=0.0
 for side in 2:
  var ankle:Vector3=pose.legs[side].end
  var neutral:Vector3=pose.get("leg_frame",Basis.IDENTITY)*Vector3((-1 if side==0 else 1)*pose.get("stance_lane",Anatomy.HIP.x),0,0)
  ankle.x=neutral.x+(ankle.x-neutral.x)*horizontal_scale;ankle.z=neutral.z+(ankle.z-neutral.z)*horizontal_scale
  pose.legs[side].end=ankle
  var hip:Vector3=pose.hips[side]
  var horizontal:=Vector2(ankle.x-hip.x,ankle.z-hip.z).length_squared()
  var vertical:=sqrt(maxf(0.01,pow(Anatomy.THIGH+Anatomy.SHIN-0.08,2)-horizontal))
  settle=maxf(settle,hip.y-ankle.y-vertical)
  if pose.has("gait_extent"):
   # Reserve reach for both ends of the whole step. Per-frame reach correction
   # otherwise pumps the hips up/down by several units at each foot transfer.
   for sign_value in [-1.0,1.0]:
    var extreme:Vector3=neutral+pose.gait_travel*pose.gait_extent*sign_value
    var distance_xz:=Vector2(extreme.x-hip.x,extreme.z-hip.z).length_squared()
    var height:=sqrt(maxf(.01,pow(Anatomy.THIGH+Anatomy.SHIN-.08,2)-distance_xz))
    settle=maxf(settle,hip.y-2.1-height)
 # Phase-independent support height: damp vertical motion around the gait's
 # existing stance, rather than raising its mean and clipping the swing arc.
 var centre_height:=Anatomy.HIP.y
 if pose.has("gait_extent"):
  for side in 2:
   var centre_hip:=Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
   var lane:Vector3=pose.get("leg_frame",Basis.IDENTITY)*Vector3((-1 if side==0 else 1)*pose.stance_lane,0,0)
   for sign_value in [-1.0,1.0]:
    var end:Vector3=lane+pose.gait_travel*pose.gait_extent*sign_value
    var horizontal:=Vector2(end.x-centre_hip.x,end.z-centre_hip.z).length_squared()
    centre_height=minf(centre_height,2.1+sqrt(maxf(.01,pow(Anatomy.THIGH+Anatomy.SHIN-.08,2)-horizontal)))
 pose.gait_center_height=lerpf(Anatomy.HIP.y,centre_height,GAIT_LOWERING)
 var down:=Vector3.DOWN*settle
 pose.body.origin+=down;pose.grip+=down
 for side in 2:
  pose.hips[side]+=down;pose.shoulders[side]+=down;pose.hands[side]+=down

static func upright_gait(pose:Dictionary) -> bool:
 return pose.get("upright_attack",false) or pose.get("clip_state",&"") in [&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"equip_walk",&"equip_run"]

static func raise_gait(pose:Dictionary) -> void:
 # Reduce the complete descent, including authored bob and reach compensation,
 # rather than just one term of the pelvis motion.
 var pelvis:Transform3D=pose.get("pelvis",pose.body)
 var height:float=(pelvis*Vector3(0,Anatomy.HIP.y,0)).y
 var lowering:=GAIT_LOWERING
 var target_height:=lerpf(height,Anatomy.HIP.y,1-lowering)
 if pose.get("upright_attack",false):
  # Leave a small, eased knee reserve for the striking-side support step.
  target_height=minf(target_height,Anatomy.HIP.y-.35*pickup_weight(pose.phase))
 var up:Vector3=Vector3.UP*(target_height-height)*(pose.attack_stance_weight if pose.get("upright_attack",false) else 1.0)
 pose.body.origin+=up;pose.pelvis.origin+=up;pose.grip+=up
 for side in 2:
  pose.hips[side]+=up;pose.shoulders[side]+=up;pose.hands[side]+=up

static func calm_gait(pose:Dictionary) -> void:
 # Dampen the final hip motion, not individual terms which may cancel each
 # other. Keep the mean forward lean and all foot timing/leg trajectories.
 var pivot:=Vector3(0,Anatomy.HIP.y,0)
 var pelvis:Transform3D=pose.pelvis
 var hip:Vector3=pelvis*pivot
 var centre:=Vector3(0,pose.get("gait_center_height",Anatomy.HIP.y),0)
 var shift:Vector3=(centre-hip)*(1-GAIT_HIP_REDUCTION)
 var angles:=pelvis.basis.get_euler()
 var lean:float=pose.body.basis.get_euler().x
 angles=Vector3(lerpf(lean,angles.x,GAIT_HIP_REDUCTION),angles.y*GAIT_HIP_REDUCTION,angles.z*GAIT_HIP_REDUCTION)
 pelvis.basis=Basis.from_euler(angles)
 pelvis.origin=hip+shift-pelvis.basis*pivot
 pose.pelvis=pelvis;pose.body.origin+=shift;pose.grip+=shift
 for side in 2:
  pose.hips[side]=pelvis*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.shoulders[side]+=shift;pose.hands[side]+=shift

static func grounded_reach(hip:Vector3,ankle:Vector3,a:float,b:float) -> Vector3:
 # Keep the sole height when a more upright pelvis makes the old extreme
 # unreachable. Smoothly limit horizontal reach instead of lifting the foot
 # or extending a thigh/shin; the IK knee remains softly flexed.
 var planar:=Vector2(ankle.x-hip.x,ankle.z-hip.z)
 var limit:=sqrt(maxf(.01,pow(a+b-.08,2)-pow(hip.y-ankle.y,2)))
 var length:=planar.length()
 if length>.0001:
  var soft:=maxf(0,minf(length,limit)-.35*log(1+exp(-absf(length-limit)/.35)))
  planar*=soft/length
  ankle.x=hip.x+planar.x;ankle.z=hip.z+planar.y
 return ankle

static func solve_legs(pose: Dictionary) -> Dictionary:
 # Keep each foot in its own stance lane, rotated with diagonal travel.
 var boundary:=Anatomy.FOOT_HALF_WIDTH+Anatomy.FOOT_GAP*0.5
 for side in 2:
  var ankle: Vector3=pose.legs[side].end
  if pose.state!=&"death":
   var across:Vector3=pose.get("leg_frame",Basis.IDENTITY).x
   var lateral:=ankle.dot(across)
   var safe:=minf(lateral,-boundary) if side==0 else maxf(lateral,boundary)
   ankle+=across*(safe-lateral)
  if upright_gait(pose):ankle=grounded_reach(pose.hips[side],ankle,Anatomy.THIGH,Anatomy.SHIN)
  var pitch: float=pose.legs[side].pitch
  pose.legs[side]=Pose.joint(pose.hips[side],ankle,Anatomy.THIGH,Anatomy.SHIN,pose.get("leg_poles",[Vector3.BACK,Vector3.BACK])[side])
  pose.legs[side].pitch=pitch
 return pose

static func arm_is_free(pose:Dictionary,side:int) -> bool:
 var family:StringName=pose.get("family",&"")
 return family==&"" or (family!=&"bow" and not Profiles.profile(family).two_hands and side!=pose.active)

static func relaxed_arm(pose:Dictionary,side:int) -> Dictionary:
 if not arm_is_free(pose,side):return {}
 var body:Transform3D=pose.body
 var upper:Vector3=(body.basis*Vector3(0.16*(-1 if side==0 else 1),-1,0.02)).normalized()
 var hinge:Vector3=(body.basis.x-upper*upper.dot(body.basis.x)).normalized()
 var forearm:=upper.rotated(hinge,-deg_to_rad(8))
 var root:Vector3=pose.shoulders[side];var joint:=root+upper*Pose.UPPER_ARM
 return {"root":root,"joint":joint,"end":joint+forearm*Pose.FOREARM}

static func running_arm(pose:Dictionary,side:int,gait:float) -> Dictionary:
 # Occupied hands preserve their category grip, including the drawing hand.
 if not arm_is_free(pose,side):return {}
 var body:Transform3D=pose.body
 var swing:float=Controls.sample(&"run",gait).arms[side]*ARM_SWING_SCALE
 var upper:Vector3=body.basis*(Basis(Vector3.RIGHT,swing)*Vector3(0.24*(-1 if side==0 else 1),-1,0)).normalized()
 var hinge:=body.basis.x-upper*upper.dot(body.basis.x);hinge=hinge.normalized()
 var forearm:=upper.rotated(hinge,-deg_to_rad(105))
 var root:Vector3=pose.shoulders[side];var joint:=root+upper*Pose.UPPER_ARM
 return {"root":root,"joint":joint,"end":joint+forearm*Pose.FOREARM}

static func clear_soles(pose:Dictionary) -> void:
 # The imported feet extend eight units in front of the ankle. Roll around
 # the visible sole, not its bone origin; preserve the authored swing lift.
 for side in 2:
  var pitch:float=pose.legs[side].pitch
  if pose.clip_state in [&"crouch_walk",&"equip_crouch_walk",&"start",&"stop",&"start_run",&"stop_run"]:pose.legs[side].end.y+=.20
  pose.legs[side].end.y+=maxf(0,sin(pitch))*8.03+maxf(0,-sin(pitch))*1.25


static func smootherstep(a:float,b:float,t:float) -> float:
 var x:=clampf((t-a)/(b-a),0,1)
 return x*x*x*(x*(x*6-15)+10)

static func reduce_weapon_pitch(pose:Dictionary,crouch:float) -> void:
 var before:Transform3D=pose.body
 var angles:=before.basis.get_euler()
 var stance:=.08*clampf(crouch,0,1)
 angles.x=stance+(angles.x-stance)*.5
 var basis:=Basis.from_euler(angles)
 var pivot:=Vector3(0,Anatomy.HIP.y,0)
 var after:=Transform3D(basis,before.origin+before.basis*pivot-basis*pivot)
 var change:=after*before.affine_inverse()
 pose.body=after;pose.grip=change*pose.grip;pose.shaft=change.basis*pose.shaft
 for side in 2:
  pose.shoulders[side]=change*pose.shoulders[side]
  pose.hands[side]=change*pose.hands[side]

static func punch(pose:Dictionary,t:float) -> void:
 var side:int=pose.active;var s:float=-1 if side==0 else 1
 var body:Transform3D=pose.body
 var drive:=smoothstep(.22,.5,t)*(1-smoothstep(.64,1,t))
 var ready:=smoothstep(0,.28,t)*(1-smoothstep(.72,1,t))
 pose.arm_poles=[]
 for arm in 2:
  var rest:=relaxed_arm(pose,arm)
  var hand:Vector3
  if arm==side:
   var wind:=body*Vector3(s*7.5,43.5,9)
   var shoulder:Vector3=pose.shoulders[side]
   var hit:=shoulder+body.basis*Vector3(0,-1.6,18.5)
   var contact:Vector3=pose.get("look_contact",Vector3.INF)
   if contact.is_finite():
    pose.contact_reachable=shoulder.distance_to(contact)>=8.15 and shoulder.distance_to(contact)<=18.6 and contact.z>=4.8
    hit=shoulder+shoulder.direction_to(contact)*minf(18.6,shoulder.distance_to(contact))
   # A jab extends from a tucked ready fist, then immediately retraces that
   # same line. No held-out impact or downward scoop on the return.
   if t<.28:hand=(rest.end as Vector3).lerp(wind,smoothstep(0,.28,t))
   elif t<=.5:hand=wind.lerp(hit,smoothstep(.28,.5,t))
   elif t<.72:hand=hit.lerp(wind,smoothstep(.5,.72,t))
   else:hand=wind.lerp(rest.end,smoothstep(.72,1,t))
   var axis:Vector3=shoulder.direction_to(hand)
   var pole:=body.basis*Vector3(s*.15,-1,.10)
   pose.arm_poles.append(preload("res://scripts/prototype_3d/human_kinematics.gd").transport_pole(shoulder.direction_to(rest.end),rest.joint-shoulder,axis,pole,ready))
  else:
   var local:Vector3=body.affine_inverse()*rest.end
   var guard:=body*Vector3(-s*8,lerpf(local.y,38,.2),9)
   var transition:=smootherstep(0,.42,t)*(1-smootherstep(.60,1,t))
   hand=(rest.end as Vector3).lerp(guard,transition)
   var shoulder:Vector3=pose.shoulders[arm]
   var axis:=shoulder.direction_to(hand)
   var desired:=body.basis*Vector3((-1 if arm==0 else 1)*.12,-.02,-1.0)
   pose.arm_poles.append(preload("res://scripts/prototype_3d/human_kinematics.gd").transport_pole(shoulder.direction_to(rest.end),rest.joint-shoulder,axis,desired,transition*.3))
  pose.hands[arm]=hand
 # The striking-side foot precedes the impact and settles before the fist lands.
 pose.legs[side].end.z+=drive*2.5
 var lift:=sin(clampf(t/.32,0,1)*PI) if t<.32 else sin(clampf((t-.72)/.28,0,1)*PI)
 pose.legs[side].end.y+=maxf(0,lift)*.75
 pose.grip=pose.hands[side]

static func jump_arms(pose:Dictionary,t:float) -> void:
 var rest:=sample(pose.family,&"idle",0,0,Vector3.ZERO,pose.get("look_contact",Vector3.INF))
 var change:Transform3D=pose.body*(rest.body as Transform3D).affine_inverse()
 var keyed:=Controls.sample(&"jump",t)
 var lift:float=keyed.arms.z
 for side in 2:
  var arm:=relaxed_arm(rest,side)
  var hand:Vector3=arm.end if not arm.is_empty() else rest.hands[side]
  pose.hands[side]=change*hand+pose.body.basis*Vector3(0,keyed.arms.y,keyed.arms.x)
 pose.grip=change*rest.grip+pose.body.basis*Vector3(0,keyed.arms.y,keyed.arms.x)
 var wrist:=Basis(pose.body.basis.x,-.08*lift)
 pose.tool_basis=wrist*change.basis*rest.get("tool_basis",Aim.frame(rest.shaft))
 pose.shaft=pose.tool_basis.y


static func mix_motion(a:Dictionary,b:Dictionary,weight:float) -> Dictionary:
 var pose:=a.duplicate(true);var t:=clampf(weight,0,1)
 pose.body=(a.body as Transform3D).interpolate_with(b.body,t)
 pose.pelvis=(a.pelvis as Transform3D).interpolate_with(b.pelvis,t)
 pose.grip=(a.grip as Vector3).lerp(b.grip,t)
 pose.tool_basis=(a.get("tool_basis",Aim.frame(a.shaft)) as Basis).slerp(b.get("tool_basis",Aim.frame(b.shaft)),t)
 pose.shaft=pose.tool_basis.y
 for side in 2:
  pose.hands[side]=(a.hands[side] as Vector3).lerp(b.hands[side],t)
  pose.legs[side].end=(a.legs[side].end as Vector3).lerp(b.legs[side].end,t)
  pose.legs[side].pitch=lerpf(a.legs[side].pitch,b.legs[side].pitch,t)
 return pose

static func keyed_locomotion(pose:Dictionary,state:StringName,phase:float) -> void:
 var keys:=Controls.sample(state,phase)
 var original:Transform3D=pose.body
 var chest:Vector3=keys.chest
 if state==&"walk":
  chest.y=-sin(phase*TAU)*.025
  chest.z=-sin(phase*TAU)*.004
 var basis:=Basis.from_euler(chest)
 var pivot:=Vector3(0,Anatomy.HIP.y,0)
 var sway:Vector3=keys.body*GAIT_HIP_MOTION
 var next:=Transform3D(basis,pivot-basis*pivot+sway)
 var change:=next*original.affine_inverse()
 pose.body=next;pose.grip=change*pose.grip;pose.shaft=change.basis*pose.shaft
 for side in 2:
  pose.shoulders[side]=next*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
  pose.hips[side]=next*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.hands[side]=change*pose.hands[side]
  var foot:Vector3=keys.foot_l if side==0 else keys.foot_r
  pose.legs[side].end=Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,2.1+foot.y,foot.x/STRIDE_SCALE)
  pose.legs[side].pitch=foot.z
  if arm_is_free(pose,side) and state==&"walk":pose.hands[side]=walking_arm(pose,side,phase).end

static func walking_arm(pose:Dictionary,side:int,gait:float) -> Dictionary:
 if pose.get("clip_state",&"")!=&"walk" or not arm_is_free(pose,side):return {}
 var body:Transform3D=pose.body
 var phase:=gait+side*.5
 var seconds:=cycle_distance(0,0,pose.get("gait_travel",Vector3.BACK))/(2*GAIT_PLAYBACK_RATE)
 var lag:=WALK_ARM_LAG_SECONDS/seconds
 # The elbow initiates a small backward sweep opposite the swinging leg.
 # The forearm follows slightly later instead of moving as a rigid rod.
 var elbow_angle:=sin(phase*TAU)*.10
 var following_angle:=sin((phase-lag)*TAU)*.10
 var upper:Vector3=body.basis*(Basis(Vector3.RIGHT,elbow_angle)*Vector3((-.16 if side==0 else .16),-1,0)).normalized()
 var hinge:=body.basis.x-upper*upper.dot(body.basis.x);hinge=hinge.normalized()
 var forearm:=upper.rotated(hinge,-deg_to_rad(12)+following_angle-elbow_angle)
 var shoulder:Vector3=pose.shoulders[side];var elbow:=shoulder+upper*Pose.UPPER_ARM
 return {"root":shoulder,"joint":elbow,"end":elbow+forearm*Pose.FOREARM,"wrist":sin((phase-lag)*TAU)*.025}

static func keyed_jump(pose:Dictionary,phase:float) -> void:
 var keys:=Controls.sample(&"jump",phase)
 var shift:Vector3=keys.body
 var turn:=Basis.from_euler(keys.chest)
 var pivot:Vector3=pose.body*Vector3(0,Anatomy.HIP.y,0)
 var change:=Transform3D(turn,pivot-turn*pivot+shift)
 pose.body=change*pose.body;pose.pelvis.origin+=shift;pose.grip=change*pose.grip
 for side in 2:
  pose.shoulders[side]=change*pose.shoulders[side];pose.hips[side]+=shift;pose.hands[side]=change*pose.hands[side]
  var foot:Vector3=keys.foot_l if side==0 else keys.foot_r
  pose.legs[side].end=Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,2.1+foot.y,foot.x)
  pose.legs[side].pitch=foot.z
