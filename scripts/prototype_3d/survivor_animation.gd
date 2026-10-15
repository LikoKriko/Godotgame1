extends RefCounted
## Reuses the game's gesture/stance timing with the 3D survivor's shared anatomy.
const Pose = preload("res://scripts/continuous_body_pose.gd")
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Aim = preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles = preload("res://scripts/prototype_3d/held_profiles.gd")
const Weapons=preload("res://scripts/prototype_3d/weapon_motion.gd")
const Slide=preload("res://scripts/prototype_3d/slide_pose.gd")
const STRIDE_SCALE:=1.3
const ARM_SWING_SCALE:=0.9
const FAMILIES: Array[StringName] = [&"",&"axe",&"pickaxe",&"sword",&"bow",&"bottle",&"food",&"carried"]
const STATES: Array[StringName] = [&"idle",&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch",&"crouch_walk",&"slide",&"jump",&"slide_jump",&"equip",&"equip_walk",&"equip_run",&"equip_crouch",&"equip_crouch_walk",&"unequip",&"action",&"draw",&"bow_release",&"pickup",&"pickup_walk",&"eat",&"eat_walk",&"drink",&"drink_walk",&"parry",&"hurt",&"death"]

static func duration(state: StringName,family: StringName = &"") -> float:
 if state==&"death": return 3.0
 if state in [&"eat",&"eat_walk",&"drink",&"drink_walk"]: return 1.2
 if state in [&"pickup",&"pickup_walk"]: return 0.72
 if state==&"slide": return 0.46
 if state in [&"jump",&"slide_jump"]: return 0.66
 if state==&"crouch_walk":return 1.25*STRIDE_SCALE
 if state==&"bow_release":return .24
 if state==&"draw": return 0.5
 if state==&"action": return 1.0125 if family==&"sword" else 0.75
 if String(state).begins_with("equip") or state==&"unequip": return 0.5 if family==&"pickaxe" else 0.42
 if state in [&"start",&"start_run"]: return 0.14
 if state in [&"stop",&"stop_run"]: return 0.18
 if state in [&"walk",&"run"]:return (0.45 if state==&"run" else 0.60)*STRIDE_SCALE
 return 0.60

static func sample(family: StringName,state: StringName,phase: float,movement_phase: float = 0.0,movement: Vector3 = Vector3.ZERO,contact: Vector3 = Vector3.INF,slide_launch:Dictionary={},crouch_amount:float=0.0) -> Dictionary:
 var source_state := &"run" if state==&"slide" else state
 if state in [&"pickup",&"pickup_walk"]:source_state=&"walk" if state==&"pickup_walk" else &"idle"
 if state==&"unequip": source_state=&"equip";phase=1-phase
 if state==&"draw" or (family==&"bow" and state==&"action"):source_state=&"idle"
 if state==&"bow_release":source_state=&"walk" if not movement.is_zero_approx() else &"idle"
 if state in [&"drink",&"drink_walk"]: source_state=&"eat_walk" if state==&"drink_walk" else &"eat"
 if state in [&"parry",&"hurt"]: source_state=&"idle"
 var pose := Pose.sample(&"food" if state in [&"drink",&"drink_walk"] else family,source_state,movement_phase if state in [&"slide",&"bow_release"] else phase,1.0 if source_state==&"equip_crouch" else movement_phase,1.0,-1)
 pose.leg_poles=[Vector3.BACK,Vector3.BACK]
 pose.leg_frame=Basis.IDENTITY
 pose.family=family;pose.clip_state=state;pose.gait_phase=phase if state==&"run" else movement_phase
 pose.look_contact=contact
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
 if not movement.is_zero_approx() and state not in [&"slide",&"jump",&"slide_jump",&"death"]:
  var travel:=Vector3(movement.x,0,movement.z).normalized()
  # Rotate the stance lanes and knee/foot frames together. Keeping the old
  # frontal lanes clips the inward half of a diagonal step into a sideways fan.
  var forward_travel:=travel if travel.z>=0 else -travel
  var yaw:=clampf(atan2(forward_travel.x,forward_travel.z),-PI/4,PI/4)*smoothstep(0,0.35,absf(travel.z))
  if state!=&"pickup_walk":
   pose.leg_frame=Basis(Vector3.UP,yaw)
   pose.leg_poles=[pose.leg_frame*Vector3.BACK,pose.leg_frame*Vector3.BACK]
  var walk_pose:=Pose.sample(family,&"walk",movement_phase) if state in [&"action",&"pickup_walk",&"eat_walk",&"drink_walk",&"unequip"] else pose
  for side in 2:
   var ankle: Vector3=walk_pose.legs[side].end
   var step:=ankle.z*lerpf(1,0.65,absf(travel.x))
   pose.legs[side].end=pose.leg_frame*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,0,0)+Vector3.UP*ankle.y+travel*step
   pose.legs[side].pitch*=travel.z
 var striding:=state in [&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch_walk",&"equip_walk",&"equip_run",&"equip_crouch_walk",&"pickup_walk",&"eat_walk",&"drink_walk"] or (not movement.is_zero_approx() and state in [&"action",&"unequip",&"bow_release"])
 if striding:
  lengthen_stride(pose);body=pose.body
  # Free walking arms retain their resting depth and share the slower gait.
  if state not in [&"run",&"start_run",&"equip_run"]:
   for side in 2:
    if not arm_is_free(pose,side):continue
    var local:Vector3=body.affine_inverse()*pose.hands[side]
    local.z=lerpf(3.5*Anatomy.BODY_DEPTH,local.z,ARM_SWING_SCALE)
    pose.hands[side]=body*local
 natural_motion(pose,state,phase,movement_phase,movement,contact,striding)
 body=pose.body
 if state==&"slide":
  lengthen_stride(pose)
  for side in 2:
   var arm:=running_arm(pose,side,movement_phase)
   if not arm.is_empty():pose.hands[side]=arm.end
  Slide.apply(pose,phase);body=pose.body
 if family==&"" and state==&"action":
  var rest:Dictionary=relaxed_arm(pose,1)
  pose.hands[1]=Pose.gesture(rest.end,body*Vector3(7,38,7),body*Vector3(6,40,18),phase,&"fist")
  var guard:=smoothstep(0,0.25,phase)*(1-smoothstep(0.65,1,phase))
  pose.hands[0]=pose.hands[0].lerp(body*Vector3(-7,37,8),guard)
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
  var opening:=smoothstep(0,0.28,phase)*(1-smoothstep(0.62,1,phase))
  var outward:Vector3=Vector3(-0.86 if free_side==0 else 0.86,-0.38,-0.34).normalized()
  var counterweight:Vector3=pose.shoulders[free_side]+body.basis*outward*18.3
  var relaxed:Dictionary=relaxed_arm(pose,free_side)
  pose.hands[free_side]=relaxed.end.lerp(counterweight,opening)
 if family==&"bow":Weapons.bow(pose,state,phase,contact)
 if family==&"" and state==&"action" and contact.is_finite():
  var shoulder: Vector3=pose.shoulders[1]
  pose.contact_reachable=shoulder.distance_to(contact)>=8.15 and shoulder.distance_to(contact)<=18.6 and contact.z>=4.8
  var end:=shoulder+shoulder.direction_to(contact)*minf(18.6,shoulder.distance_to(contact))
  var amount:=smoothstep(0.25,0.5,phase)*(1-smoothstep(0.61,1,phase))
  pose.hands[1]=pose.hands[1].lerp(end,amount)
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
 if state==&"slide_jump":
  var launch:Dictionary=slide_launch if not slide_launch.is_empty() else sample(family,&"slide",0.55,movement_phase)
  Slide.jump_from(pose,launch,phase)
 return solve_legs(pose)

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
  offset.x=-wave*0.32
  pelvis_rotation=Vector3(0,wave*0.035+pose.leg_frame.get_euler().y*0.5,wave*0.012)
  chest_rotation=Vector3(0,-wave*0.025,-wave*0.014)
 elif state==&"idle":
  var breath:=sin(phase*TAU)
  chest_rotation.x=breath*0.004
 if state in [&"crouch",&"crouch_walk",&"equip_crouch",&"equip_crouch_walk"]:
  var low:=phase if state==&"crouch" else 1.0
  chest_rotation.x+=low*0.08
  pelvis_rotation.x+=low*0.025
  offset.z-=low*0.45
 if state==&"action" and pose.family!=&"bow":
  var load:=smoothstep(0,0.28,phase)*(1-smoothstep(0.52,0.9,phase))
  var drive:=smoothstep(0.28,0.5,phase)*(1-smoothstep(0.62,1,phase))
  var sign_side:float=-1 if pose.active==0 else 1
  chest_rotation.y+=sign_side*(load*0.055-drive*0.095)
  pelvis_rotation.y+=sign_side*(load*0.025-drive*0.045)
  offset.z+=drive*0.55-load*0.3
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
   chest_rotation.x+=low*0.18*drive
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
  for side in 2:
   if arm_is_free(pose,side):pose.hands[side]=pose.hands[side].lerp(original*Vector3(-11 if side==0 else 11,37,8),airborne*0.55)
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
 if state not in [&"slide",&"slide_jump",&"death"]:
  chest=Transform3D(Basis.from_euler(chest_rotation),pivot+offset-Basis.from_euler(chest_rotation)*pivot)*original
  pelvis=Transform3D(Basis.from_euler(pelvis_rotation),pivot+offset-Basis.from_euler(pelvis_rotation)*pivot)*original
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
 if state==&"death":
  # Hands and feet meet the ground independently of the falling torso instead
  # of rigidly following it below the floor. The head/chest retain clearance.
  var settle:=smoothstep(0.35,0.85,phase)*5.8
  pose.body.origin.y+=settle;pose.pelvis=pose.body
  for side in 2:
   pose.shoulders[side]=pose.body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
   pose.hips[side]=pose.body*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
   pose.hands[side].y=maxf(6.5,pose.hands[side].y+settle)
   var fold:=smoothstep(.3,.7,phase)
   pose.leg_poles[side]=(Vector3.BACK.lerp(Vector3.UP,fold)+Vector3((-1 if side==0 else 1)*sin(fold*PI)*1.3,0,0)).normalized()
   pose.legs[side].end.y=maxf(2.1,pose.legs[side].end.y+settle)

static func lengthen_stride(pose:Dictionary) -> void:
 # Keep the existing stance/lift curve, extending only horizontal travel.
 # Settle the pelvis just enough to reach both planted feet with fixed bones;
 # otherwise clamped IK would shorten the requested step or lift a support foot.
 var settle:=0.0
 for side in 2:
  var ankle:Vector3=pose.legs[side].end
  var neutral:Vector3=pose.get("leg_frame",Basis.IDENTITY)*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,0,0)
  ankle.x=neutral.x+(ankle.x-neutral.x)*STRIDE_SCALE;ankle.z=neutral.z+(ankle.z-neutral.z)*STRIDE_SCALE
  pose.legs[side].end=ankle
  var hip:Vector3=pose.hips[side]
  var horizontal:=Vector2(ankle.x-hip.x,ankle.z-hip.z).length_squared()
  var vertical:=sqrt(maxf(0.01,pow(Anatomy.THIGH+Anatomy.SHIN-0.08,2)-horizontal))
  settle=maxf(settle,hip.y-ankle.y-vertical)
 var down:=Vector3.DOWN*settle
 pose.body.origin+=down;pose.grip+=down
 for side in 2:
  pose.hips[side]+=down;pose.shoulders[side]+=down;pose.hands[side]+=down

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
 var swing:=sin((gait+side*0.5)*TAU)*deg_to_rad(18)*ARM_SWING_SCALE
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
