extends RefCounted
## Authored reference-informed gestures for the imported survivor. Contacts are
## solved at the hit key; the rest of the stroke has its own load and recovery.
const Aim=preload("res://scripts/prototype_3d/tool_aim.gd")
const Profiles=preload("res://scripts/prototype_3d/held_profiles.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const MELEE:Array[StringName]=[&"axe",&"pickaxe",&"sword"]
static func frame(body:Basis,shaft:Vector3,family:StringName) -> Basis:
 var y:Vector3=(body*shaft).normalized()
 var edge:Vector3=body.z if family!=&"sword" else body.x
 var x:Vector3=(edge-y*edge.dot(y)).normalized()
 if x.length_squared()<.01:x=(body.x-y*body.x.dot(y)).normalized()
 return Basis(x,y,x.cross(y).normalized())
static func guard(body:Transform3D,family:StringName,running:float=0.0) -> Transform3D:
 var grip:=Vector3(-3.5,35.5,12.0)
 var axis:=Vector3(.38,.76,.53)
 if family==&"pickaxe":grip=Vector3(-3.5,35,12.5);axis=Vector3(.38,.76,.53)
 if family==&"sword":grip=Vector3(8.0,34.0,10.0);axis=Vector3(.10,.46,.88)
 grip=grip.lerp(Vector3(-3.5,39,13) if family!=&"sword" else Vector3(8.5,38,11),running)
 axis=axis.lerp(Vector3(.12,.94,.31) if family!=&"sword" else Vector3(.10,.70,.70),running)
 # Ten degrees farther from vertical in the same carrying plane.
 var tilt_axis:=Vector3.UP.cross(axis).normalized()
 axis=axis.rotated(tilt_axis,deg_to_rad(10))
 return Transform3D(frame(body.basis,axis,family),body*grip)
static func carry(pose:Dictionary,state:StringName,phase:float,_gait:float) -> void:
 var family:StringName=pose.family
 if family not in MELEE:return
 var running:=1.0 if state in [&"run",&"start_run",&"equip_run"] else 0.0
 var target:=guard(pose.body,family,running)
 if state in [&"idle",&"walk",&"run",&"crouch",&"crouch_walk",&"start",&"stop",&"start_run",&"stop_run"]:
  pose.grip=target.origin;pose.tool_basis=target.basis;pose.shaft=target.basis.y
 elif String(state).begins_with("equip") or state==&"unequip":
  var weight:=smoothstep(.35,1,phase)
  pose.grip=(pose.grip as Vector3).lerp(target.origin,weight)
  pose.tool_basis=pose.get("tool_basis",frame(pose.body.basis,Vector3(.3,.8,.5),family)).slerp(target.basis,weight)
  pose.shaft=pose.tool_basis.y
static func melee(pose:Dictionary,t:float,contact:Vector3,impact_pose:Dictionary={}) -> void:
 var family:StringName=pose.family;var profile:=Profiles.profile(family)
 var solution:Dictionary={}
 if not impact_pose.is_empty():
  solution={"grip":impact_pose.grip,"basis":impact_pose.tool_basis}
  pose.contact_reachable=impact_pose.get("contact_reachable",false)
  var transfer:Vector3=impact_pose.get("reach_transfer",Vector3.ZERO)*smoothstep(.26,.5,t)*(1-smoothstep(.62,1,t))
  pose.body.origin+=transfer;pose.pelvis.origin+=transfer
  for side in 2:pose.shoulders[side]+=transfer;pose.hips[side]+=transfer;pose.hands[side]+=transfer
 elif contact.is_finite():
  solution=Aim.solve(contact,pose.shoulders,profile.tip,pose.active,profile.two_hands,pose.body,profile.support)
  if solution.is_empty():
   # Retarget the measured source tip without changing limb lengths or the
   # reduced knee bend. Use the smallest forward weight shift that can reach.
   for distance in [1.5,2.0,2.5,3.0,3.5,4.0,4.5]:
    var transfer:=Vector3(contact.x,0,contact.z).normalized()*float(distance)
    var shoulders:Array=[pose.shoulders[0]+transfer,pose.shoulders[1]+transfer]
    if Aim.solve(contact,shoulders,profile.tip,pose.active,profile.two_hands,Transform3D(pose.body.basis,pose.body.origin+transfer),profile.support).is_empty():continue
    transfer*=smoothstep(.26,.5,t)*(1-smoothstep(.62,1,t))
    pose.reach_transfer=transfer
    pose.body.origin+=transfer;pose.pelvis.origin+=transfer
    for side in 2:pose.shoulders[side]+=transfer;pose.hips[side]+=transfer;pose.hands[side]+=transfer
    solution=Aim.solve(contact,pose.shoulders,profile.tip,pose.active,profile.two_hands,pose.body,profile.support)
    break
  pose.contact_reachable=not solution.is_empty()
  if solution.is_empty():
   var center:Vector3=(pose.shoulders[0]+pose.shoulders[1])*.5
   solution=Aim.solve(center+center.direction_to(contact)*30,pose.shoulders,profile.tip,pose.active,profile.two_hands,pose.body,profile.support)
 var body:Transform3D=pose.body
 var rest:=guard(body,family)
 var wind_grip:=Vector3(-1.5,46.0,14.0)
 var wind_axis:=Vector3(.35,.936,.03)
 var hit_grip:=Vector3(-1,34,15)
 var hit_axis:=Vector3(.10,.14,.98)
 if family==&"pickaxe":
  wind_grip=Vector3(-2,46,14);wind_axis=Vector3(.03,.99,.06)
  hit_grip=Vector3(-1,29,16);hit_axis=Vector3(0,-.45,.89)
 elif family==&"sword":
  wind_grip=Vector3(12,43,10);wind_axis=Vector3(.14,.96,-.24)
  hit_grip=Vector3(1,36,15);hit_axis=Vector3(-.55,-.15,.82)
 var wind:=Transform3D(frame(body.basis,wind_axis,family),body*wind_grip)
 var hit:=Transform3D(solution.basis,solution.grip) if not solution.is_empty() else Transform3D(frame(body.basis,hit_axis,family),body*hit_grip)
 var follow:=hit
 follow.origin+=body.basis*(Vector3(-1.0,-.8,1.0) if family==&"sword" else Vector3(0,-1,1))
 follow.basis=follow.basis.rotated(body.basis.z,.28) if family==&"sword" else follow.basis.rotated(body.basis.x,.20)
 var recover:=rest
 recover.origin+=body.basis*Vector3(0,3.0,4.0)
 var tool:Transform3D
 if t<=.28:tool=rest.interpolate_with(wind,smoothstep(0,.28,t))
 elif t<=.5:tool=wind.interpolate_with(hit,pow(clampf((t-.28)/.22,0,1),1.85))
 elif t<=.65:tool=hit.interpolate_with(follow,smoothstep(.5,.65,t))
 elif t<=.84:tool=follow.interpolate_with(recover,smoothstep(.65,.84,t))
 else:tool=recover.interpolate_with(rest,smoothstep(.84,1,t))
 if family in [&"axe",&"pickaxe"]:
  # Extract the head forward/up before recovering, keeping the supporting arm
  # outside the upper garment instead of sweeping it across the chest.
  var extraction:=smoothstep(.5,.62,t)*(1-smoothstep(.88,1,t))
  tool.origin+=body.basis*Vector3(0,2,8)*extraction
 pose.grip=tool.origin;pose.tool_basis=tool.basis;pose.shaft=tool.basis.y
static func bow(pose:Dictionary,state:StringName,t:float,contact:Vector3) -> void:
 if state not in [&"idle",&"walk",&"run",&"crouch",&"crouch_walk",&"draw",&"action",&"bow_release"]:return
 var body:Transform3D=pose.body
 var releasing:=state==&"bow_release"
 var drawing:=state in [&"draw",&"action"]
 var phase:=clampf(t,0,1)
 var lift:=smoothstep(0,.34,phase) if drawing else (1-smoothstep(.45,1,phase) if releasing else 0.0)
 var pull:=smoothstep(.18,.9,phase) if drawing else 1.0
 var head:=Basis.IDENTITY.slerp(body.basis,.2)
 var anchor:Vector3=body*Anatomy.HEAD_ANCHOR+head*Vector3(4.8,.8,4.0)
 var point:=contact if contact.is_finite() else Vector3(0,53,200)
 var direction:=anchor.direction_to(point)
 if direction.is_zero_approx():direction=Vector3.BACK
 var shoulder:Vector3=pose.shoulders[pose.active]
 # Intersect the aim line from the real cheek anchor with the bow arm's reach.
 # A small bend remains in the elbow instead of forcing a locked joint.
 var offset:=anchor-shoulder
 var along:=offset.dot(direction)
 var reach:float=-along+sqrt(maxf(0,along*along-offset.length_squared()+18.0*18.0))
 var aimed:Vector3=anchor+direction*clampf(reach,8,21)
 if shoulder.distance_to(aimed)>18.4:aimed=shoulder+shoulder.direction_to(aimed)*18.4
 var carry_grip:Vector3=body*Vector3(-8.5,37,12)
 pose.grip=carry_grip.lerp(aimed,lift)
 direction=pose.grip.direction_to(point)
 var up:=Vector3.UP-direction*direction.y
 if up.length_squared()<.01:up=Vector3.BACK-direction*direction.z
 up=up.normalized()
 var cant:=1-smoothstep(55,120,Vector2(point.x-anchor.x,point.z-anchor.z).length())
 up=up.rotated(direction,-cant*.15-deg_to_rad(10))
 var right:=up.cross(direction).normalized()
 pose.tool_basis=Basis(right,direction.cross(right).normalized(),direction)
 pose.shaft=pose.tool_basis.y
 var ready:Vector3=body*Vector3(8.5,35,8)
 var string_hand:Vector3=pose.grip-direction*4
 string_hand=string_hand.lerp(anchor,pull)
 if releasing:string_hand=anchor+(-direction*1.2+head.x*2.0)*sin(clampf(phase/.7,0,1)*PI)
 pose.hands[1-pose.active]=ready.lerp(string_hand,lift)
