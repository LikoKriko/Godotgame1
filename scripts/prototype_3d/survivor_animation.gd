extends RefCounted
## Reuses the game's gesture/stance timing with the 3D survivor's shared anatomy.
const Pose = preload("res://scripts/continuous_body_pose.gd")
const Anatomy = preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Aim = preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles = preload("res://scripts/prototype_3d/held_profiles.gd")
const FAMILIES: Array[StringName] = [&"",&"axe",&"pickaxe",&"sword",&"bow",&"bottle",&"food",&"carried"]
const STATES: Array[StringName] = [&"idle",&"walk",&"run",&"start",&"stop",&"start_run",&"stop_run",&"crouch",&"crouch_walk",&"slide",&"jump",&"slide_jump",&"equip",&"equip_walk",&"equip_run",&"equip_crouch",&"equip_crouch_walk",&"unequip",&"action",&"draw",&"pickup",&"pickup_walk",&"eat",&"eat_walk",&"drink",&"drink_walk",&"parry",&"hurt",&"death"]

static func duration(state: StringName,family: StringName = &"") -> float:
 if state==&"death": return 3.0
 if state in [&"eat",&"eat_walk",&"drink",&"drink_walk"]: return 1.2
 if state in [&"pickup",&"pickup_walk"]: return 0.36
 if state==&"slide": return 0.46
 if state in [&"jump",&"slide_jump"]: return 0.66
 if state==&"crouch_walk":return 1.25
 if state==&"draw": return 0.5
 if state==&"action": return 1.0125 if family==&"sword" else 0.75
 if String(state).begins_with("equip") or state==&"unequip": return 0.5 if family==&"pickaxe" else 0.42
 if state in [&"start",&"start_run"]: return 0.14
 if state in [&"stop",&"stop_run"]: return 0.18
 return 0.45 if state==&"run" else 0.60

static func sample(family: StringName,state: StringName,phase: float,movement_phase: float = 0.0,movement: Vector3 = Vector3.ZERO,contact: Vector3 = Vector3.INF) -> Dictionary:
 var source_state := state
 if state==&"unequip": source_state=&"equip";phase=1-phase
 if state==&"draw": source_state=&"action";phase*=0.5
 if state in [&"drink",&"drink_walk"]: source_state=&"eat_walk" if state==&"drink_walk" else &"eat"
 if state in [&"parry",&"hurt"]: source_state=&"idle"
 var pose := Pose.sample(&"food" if state in [&"drink",&"drink_walk"] else family,source_state,phase,1.0 if source_state==&"equip_crouch" else movement_phase,1.0,-1)
 pose.family=family;pose.clip_state=state
 var original_body: Transform3D = pose.body
 var body: Transform3D = original_body
 # An impact transfers weight through the chest and pelvis before settling.
 var recoil := 0.0
 if state==&"action": recoil=sin(clampf((phase-0.5)/0.16,0,1)*PI)*exp(-maxf(0,phase-0.5)*4)
 if state==&"hurt": recoil=sin(phase*PI)
 var guard_amount:=smoothstep(0,0.2,phase)*(1-smoothstep(0.65,1,phase)) if state==&"parry" else 0.0
 var low_guard:=clampf(32-contact.y,0,12)*guard_amount if state==&"parry" and contact.is_finite() else 0.0
 body.origin.y-=low_guard
 body.origin.z-=recoil*0.65
 body.basis=body.basis*Basis(Vector3.RIGHT,-recoil*0.045)
 if state==&"idle": body.origin.y+=sin(phase*TAU)*0.12
 pose.body=body
 for side in 2:
  pose.shoulders[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,0)
  pose.hips[side]=body*Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,Anatomy.HIP.y,0)
  pose.hands[side]=body*Anatomy.limb(original_body.affine_inverse()*pose.hands[side])
  pose.legs[side].end.x*=Anatomy.BODY_WIDTH
 pose.grip=body*Anatomy.limb(original_body.affine_inverse()*pose.grip)
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
  var walk_pose:=Pose.sample(family,&"walk",movement_phase) if state in [&"action",&"pickup_walk",&"eat_walk",&"drink_walk"] else pose
  for side in 2:
   var ankle: Vector3=walk_pose.legs[side].end
   var step:=ankle.z*lerpf(1,0.65,absf(travel.x))
   pose.legs[side].end=Vector3((-1 if side==0 else 1)*Anatomy.HIP.x,ankle.y,0)+travel*step
   pose.legs[side].pitch*=travel.z
 if family in [&"axe",&"pickaxe",&"sword"] and state==&"action":
  var rest_grip:=body*Vector3(-3.36,32,5.5)
  var wind:=body*Vector3(-3.36,45,8.8)
  var wind_axis: Vector3=body.basis*Vector3(0.15,0.98,-0.1).normalized()
  if family==&"axe":
   pose.grip=Pose.gesture(rest_grip,wind,body*Vector3(2,35,14),phase,family)
   pose.shaft=Pose.gesture(Vector3(0.42,0.72,0.55),wind_axis,Vector3(0.1,0.1,1),phase,family).normalized()
  pose.grip.z=maxf(pose.grip.z,4.5)
  if contact.is_finite():
   var profile:=Profiles.profile(family)
   var solution:=Aim.solve(contact,pose.shoulders,profile.tip,pose.active,profile.two_hands)
   pose.contact_reachable=not solution.is_empty()
   if solution.is_empty():
    var center: Vector3=(pose.shoulders[0]+pose.shoulders[1])*0.5
    solution=Aim.solve(center+center.direction_to(contact)*30,pose.shoulders,profile.tip,pose.active,profile.two_hands)
   if not solution.is_empty():
    var amount:=smoothstep(0.26,0.5,phase)*(1-smoothstep(0.62,1,phase))
    var aimed:=Aim.frame(pose.shaft).slerp(solution.basis,amount)
    pose.grip=pose.grip.lerp(solution.grip,amount);pose.shaft=aimed.y;pose.tool_basis=aimed
 if family==&"bow" and contact.is_finite() and state in [&"action",&"draw",&"idle"]:
  var active: int=pose.active
  var direction: Vector3=pose.shoulders[active].direction_to(contact)
  var drawn:=smoothstep(0,0.26,phase)*(1-smoothstep(0.65,1,phase)) if state!=&"idle" else 0.0
  pose.grip=pose.shoulders[active]+direction*lerpf(13,18,drawn)
  pose.shaft=(Vector3.UP-direction*Vector3.UP.dot(direction)).normalized()
  pose.hands[1-active]=pose.hands[1-active].lerp(body*Vector3(4,49,5.5),drawn)
 if family==&"" and state==&"action" and contact.is_finite():
  var shoulder: Vector3=pose.shoulders[1]
  var end:=shoulder+shoulder.direction_to(contact)*minf(18.6,shoulder.distance_to(contact))
  var amount:=smoothstep(0.25,0.5,phase)*(1-smoothstep(0.61,1,phase))
  pose.hands[1]=pose.hands[1].lerp(end,amount)
 if state in [&"drink",&"drink_walk"]:
  var amount:=smoothstep(0,0.25,phase)*(1-smoothstep(0.75,1,phase))
  pose.shaft=(body.basis*Vector3(0,1,0).lerp(Vector3(0,0.65,-0.75),amount)).normalized()
 for side in 2:
  if pose.hands[side].y>30 and pose.hands[side].y<55 and absf(pose.hands[side].x)<7:
   pose.hands[side].z=maxf(pose.hands[side].z,4.8)
 return solve_legs(pose)

static func solve_legs(pose: Dictionary) -> Dictionary:
 # Each foot stays on its anatomical side, including during blended diagonals.
 var boundary:=Anatomy.FOOT_HALF_WIDTH+Anatomy.FOOT_GAP*0.5
 for side in 2:
  var ankle: Vector3=pose.legs[side].end
  if pose.state!=&"death": ankle.x=minf(ankle.x,-boundary) if side==0 else maxf(ankle.x,boundary)
  var pitch: float=pose.legs[side].pitch
  pose.legs[side]=Pose.joint(pose.hips[side],ankle,Pose.THIGH,Pose.SHIN,Vector3.BACK)
  pose.legs[side].pitch=pitch
 return pose
