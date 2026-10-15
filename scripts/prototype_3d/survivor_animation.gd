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
 pose.family=family;pose.clip_state=state;pose.gait_phase=phase if state==&"run" else movement_phase
 var original_body: Transform3D = pose.body
 var body: Transform3D = original_body
 if state==&"action" or state==&"draw":
  # Keep the pelvis near standing height; aim with shoulder/arm IK first.
  var standing_y:=Anatomy.HIP.y
  var pelvis:Vector3=body*Vector3(0,standing_y,0)
  body.origin.y+=maxf(0,standing_y-1.2-pelvis.y)
 # An impact transfers weight through the chest and pelvis before settling.
 var recoil := 0.0
 if state==&"action": recoil=sin(clampf((phase-0.5)/0.16,0,1)*PI)*exp(-maxf(0,phase-0.5)*4)
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
 if family==&"axe":
  var shaft:Vector3=pose.shaft.normalized()
  var edge:Vector3=body.basis*Vector3.BACK;edge-=shaft*edge.dot(shaft)
  if edge.length_squared()<0.01:edge=body.basis*Vector3.RIGHT
  edge=edge.normalized();pose.tool_basis=Basis(edge,shaft,edge.cross(shaft).normalized())
 if family in [&"axe",&"pickaxe",&"sword"] and state==&"action":
  var rest_grip:=body*Vector3(-3.36,32,5.5)
  var wind:=body*Vector3(-3.36,45,8.8)
  var wind_axis: Vector3=body.basis*Vector3(0.15,0.98,-0.1).normalized()
  if family==&"axe":
   pose.grip=Pose.gesture(rest_grip,wind,body*Vector3(2,35,14),phase,family)
   pose.shaft=Pose.gesture(Vector3(0.42,0.72,0.55),wind_axis,Vector3(0.1,0.1,1),phase,family).normalized()
  elif family==&"sword":
   pose.grip=body*Pose.gesture(Vector3(6,31,6),Vector3(9,42,8),Vector3(-2,34,12),phase,family)
   pose.shaft=(body.basis*Pose.gesture(Vector3(0,0.35,0.94),Vector3(0.1,0.9,0.42),Vector3(-0.65,-0.3,0.7),phase,family)).normalized()
  pose.grip.z=maxf(pose.grip.z,4.5)
  if family==&"axe":
   var edge:Vector3=Vector3.BACK-pose.shaft*pose.shaft.z
   if edge.length_squared()<0.01:edge=Vector3.RIGHT
   edge=edge.normalized();pose.tool_basis=Basis(edge,pose.shaft,edge.cross(pose.shaft).normalized())
  if contact.is_finite():
   var profile:=Profiles.profile(family)
   var solution:=Aim.solve(contact,pose.shoulders,profile.tip,pose.active,profile.two_hands)
   pose.contact_reachable=not solution.is_empty()
   if solution.is_empty():
    var center: Vector3=(pose.shoulders[0]+pose.shoulders[1])*0.5
    solution=Aim.solve(center+center.direction_to(contact)*30,pose.shoulders,profile.tip,pose.active,profile.two_hands)
   if not solution.is_empty():
    var amount:=smoothstep(0.26,0.5,phase)*(1-smoothstep(0.62,1,phase))
    var aimed:Basis=pose.get("tool_basis",Aim.frame(pose.shaft)).slerp(solution.basis,amount)
    pose.grip=pose.grip.lerp(solution.grip,amount);pose.shaft=aimed.y;pose.tool_basis=aimed
 if family==&"bow" and contact.is_finite() and state not in [&"death",&"eat",&"drink",&"pickup"]:
  var active:int=pose.active
  var drawn:=smoothstep(0,0.26,phase) if state in [&"draw",&"action"] else 0.0
  var anchor:Vector3=body*Vector3(-2.2,46.8,5.3)
  var direction:=anchor.direction_to(contact)
  if direction.is_zero_approx():direction=Vector3.BACK
  var grip:Vector3=anchor+direction*12
  if pose.shoulders[active].distance_to(grip)>18.4:grip=pose.shoulders[active]+pose.shoulders[active].direction_to(grip)*18.4
  direction=grip.direction_to(contact)
  var up:=Vector3.UP-direction*direction.y
  if up.length_squared()<0.01:up=Vector3.BACK-direction*direction.z
  up=up.normalized()
  var near_amount:=1-smoothstep(55,120,Vector2(contact.x-anchor.x,contact.z-anchor.z).length())
  up=up.rotated(direction,-near_amount*0.15)
  var right:=up.cross(direction).normalized()
  pose.grip=grip;pose.shaft=direction.cross(right).normalized()
  pose.hands[1-active]=grip-direction*lerpf(4,12,drawn)
  pose.tool_basis=Basis(right,pose.shaft,direction)
 if family==&"" and state==&"action" and contact.is_finite():
  var shoulder: Vector3=pose.shoulders[1]
  var end:=shoulder+shoulder.direction_to(contact)*minf(18.6,shoulder.distance_to(contact))
  var amount:=smoothstep(0.25,0.5,phase)*(1-smoothstep(0.61,1,phase))
  pose.hands[1]=pose.hands[1].lerp(end,amount)
 if state in [&"drink",&"drink_walk"]:
  var amount:=smoothstep(0,0.25,phase)*(1-smoothstep(0.75,1,phase))
  pose.grip=body*Vector3(6.5,32,7).lerp(Vector3(0.8,46.7,9.5),amount)
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

static func arm_is_free(pose:Dictionary,side:int) -> bool:
 var family:StringName=pose.get("family",&"")
 return family==&"" or (family!=&"bow" and not Profiles.profile(family).two_hands and side!=pose.active)

static func relaxed_arm(pose:Dictionary,side:int) -> Dictionary:
 if not arm_is_free(pose,side):return {}
 var body:Transform3D=pose.body
 var upper:Vector3=(body.basis*Vector3(0.16*(-1 if side==0 else 1),-1,0.02)).normalized()
 var hinge:Vector3=(body.basis.x-upper*upper.dot(body.basis.x)).normalized()
 var forearm:=upper.rotated(hinge,-deg_to_rad(15))
 var root:Vector3=pose.shoulders[side];var joint:=root+upper*Pose.UPPER_ARM
 return {"root":root,"joint":joint,"end":joint+forearm*Pose.FOREARM}

static func running_arm(pose:Dictionary,side:int,gait:float) -> Dictionary:
 # Occupied hands preserve their category grip, including the drawing hand.
 if not arm_is_free(pose,side):return {}
 var body:Transform3D=pose.body
 var swing:=sin((gait+side*0.5)*TAU)*deg_to_rad(18)
 var upper:Vector3=body.basis*(Basis(Vector3.RIGHT,swing)*Vector3(0.24*(-1 if side==0 else 1),-1,0)).normalized()
 var hinge:=body.basis.x-upper*upper.dot(body.basis.x);hinge=hinge.normalized()
 var forearm:=upper.rotated(hinge,-deg_to_rad(105))
 var root:Vector3=pose.shoulders[side];var joint:=root+upper*Pose.UPPER_ARM
 return {"root":root,"joint":joint,"end":joint+forearm*Pose.FOREARM}
