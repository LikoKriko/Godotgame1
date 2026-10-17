extends RefCounted
## Native SmartRig authoring. Coordinates are source metres, not the old rig.
const Rig=preload("res://scripts/animation/shared/rig_binding.gd")
const RIG_PROFILE=preload("res://data/animation/enemies/enemy1.tres")
const Frames=preload("res://scripts/prototype_3d/human_kinematics.gd")
const Joint=preload("res://scripts/continuous_body_pose.gd")
const STATES:Array[StringName]=[&"idle",&"walk",&"run",&"rise",&"attack",&"boxing_guard",&"boxing_walk",&"boxing_rise",&"boxing_lower",&"hook",&"lower",&"sit_down",&"sit",&"sit_up",&"feed",&"sleep_down",&"sleep",&"wake_up",&"stun_fall",&"stun_hold",&"stun_rise",&"death",&"corpse"]
const LOOP_STATES:Array[StringName]=[&"idle",&"walk",&"run",&"boxing_guard",&"boxing_walk",&"sit",&"feed",&"sleep"]
const WALK_SPEED:=.85
const RUN_SPEED:=1.7
const GAME_SCALE:=.875/1.7000001668930054
const NOSE:=Vector3(.0101,.9006,1.14912784)
var rest:Array[Transform3D]=[]
var local_rest:Array[Transform3D]=[]
var parents:Array[int]=[]
var names:Dictionary={}
var posed:Array[Transform3D]=[]
var supports:Array[Dictionary]=[]
var limbs:Array[Dictionary]=[]
var anchors:Array[Dictionary]=[]
var plant_errors:Array[float]=[]
var last_controls:Dictionary={}
var last_state:StringName=&""
var last_phase:=0.0
var last_left:=true
static func seconds(state:StringName) -> float:
 return {&"sleep_down":.7,&"sleep":4.0,&"wake_up":.65,&"walk":.64,&"run":.48,&"rise":.28,&"lower":.28,&"attack":1.0,&"hook":1.2,&"boxing_rise":.28,&"boxing_lower":.28,&"boxing_walk":.36,&"boxing_guard":4.0,&"sit_down":.28,&"sit_up":.28,&"sit":4.0,&"idle":4.0,&"feed":1.5,&"stun_fall":.24,&"stun_hold":1.02,&"stun_rise":.24,&"death":2.0,&"corpse":2.0}.get(state,1.0)
static func clip_name(state:StringName,left:bool=true) -> StringName:
 return StringName(String(state)+("_left" if left else "_right")) if state in [&"attack",&"hook"] else state
func configure(rig:Skeleton3D) -> void:
 rest.clear();local_rest.clear();parents.clear();names.clear();limbs.clear();anchors.clear()
 var anatomy:=Rig.new()
 if not anatomy.configure(rig,RIG_PROFILE):push_error(str(anatomy.errors));return
 names=anatomy.names;parents.assign(anatomy.parents);rest.assign(anatomy.globals);local_rest.assign(anatomy.locals)
 posed.assign(rest)
 for label in [&"hind_l",&"hind_r",&"fore_l",&"fore_r"]:
  var chain:Dictionary=anatomy.chains[label]
  limbs.append({"ids":chain.ids,"a":chain.a,"b":chain.b})
 prepare_anchors(rig)
func prepare_anchors(rig:Skeleton3D) -> void:
 var node:MeshInstance3D=rig.find_children("*","MeshInstance3D",true,false)[0]
 var arrays:Array=node.mesh.surface_get_arrays(0)
 var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var w:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 for k in 4:
  var sums:Dictionary={};var count:=0
  for vertex in v.size():
   if v[vertex].y>(.065 if k<2 else .29):continue
   var belongs:=0.0
   for slot in 4:
    if node.skin.get_bind_bone(ids[vertex*4+slot]) in limbs[k].ids:belongs+=w[vertex*4+slot]
   if belongs<.9:continue
   count+=1
   for slot in 4:
    var bind_index:int=ids[vertex*4+slot];var weight:float=w[vertex*4+slot]
    var bone:int=node.skin.get_bind_bone(bind_index)
    if not sums.has(bone):sums[bone]={"point":Vector3.ZERO,"weight":0.0}
    sums[bone].point+=(node.skin.get_bind_pose(bind_index)*v[vertex])*weight
    sums[bone].weight+=weight
  assert(count>0)
  for bone in sums:sums[bone].point/=count;sums[bone].weight/=count
  anchors.append(sums)
func skin_anchor(k:int) -> Vector3:
 var point:=Vector3.ZERO
 for bone in anchors[k]:point+=posed[bone].basis*anchors[k][bone].point+posed[bone].origin*anchors[k][bone].weight
 return point
func stable_pole(k:int,target:Vector3,desired:Vector3,amount:float=0.0) -> Vector3:
 var ids:Array=limbs[k].ids
 var parent:int=parents[ids[0]]
 var frame:Basis=posed[parent].basis*rest[parent].basis.inverse()
 var before:Vector3=frame*rest[ids[0]].origin.direction_to(rest[ids[2]].origin)
 var pole:Vector3=frame*(rest[ids[1]].origin-rest[ids[0]].origin)
 var axis:Vector3=posed[ids[0]].origin.direction_to(target)
 return Frames.transport_pole(before,pole,axis,desired,amount)
func solve_limb(k:int,target:Vector3,value:Dictionary,body:Transform3D) -> void:
 var limb:Dictionary=limbs[k];var ids:Array=limb.ids;var side:=k%2
 var terminal:=Basis(Vector3.RIGHT,value.foot_pitch[side])*(rest[ids[3]].origin-rest[ids[2]].origin) if k<2 else Vector3.ZERO
 var pole:Vector3=body.basis*((rest[ids[1]].origin-rest[ids[0]].origin) if k<2 else value.poles[side])
 pole=stable_pole(k,target-terminal,pole)
 var solved:=Rig.solve_metres(posed[ids[0]].origin,target-terminal,limb.a,limb.b,pole)
 aim(ids[0],ids[1],solved.root,solved.joint);aim(ids[1],ids[2],solved.joint,solved.end)
 posed[ids[2]]=Transform3D((Basis(Vector3.RIGHT,value.foot_pitch[side]) if k<2 else body.basis)*rest[ids[2]].basis,solved.end)
 if k<2:posed[ids[3]]=Transform3D(posed[ids[2]].basis*rest[ids[2]].basis.inverse()*rest[ids[3]].basis,solved.end+terminal)
func plant_surface(k:int,goal:float,value:Dictionary,body:Transform3D) -> void:
 var target:Vector3=value.feet[k] if k<2 else value.hands[k-2]
 var reference_z:float=last_controls.get(k,target.z)
 target.z=reference_z
 var best:=target;var error:=INF
 for attempt in 12:
  solve_limb(k,target,value,body)
  var actual:float=skin_anchor(k).z;var difference:=goal-actual
  if absf(difference)<error:error=absf(difference);best=target
  if error<.0001:break
  var trial:=target+Vector3(0,0,.001)
  solve_limb(k,trial,value,body)
  var slope:float=(skin_anchor(k).z-actual)/.001
  target.z+=clampf(difference/slope if absf(slope)>.03 else signf(difference)*.03,-.10,.10)
 if error>.0005:
  var previous_z:float=-1.0;var previous_error:=0.0;var have_previous:=false;var best_gap:=INF
  for index in 61:
   var z:float=-1.0+index*.04
   var trial:=Vector3(target.x,target.y,z);solve_limb(k,trial,value,body)
   var current:float=skin_anchor(k).z-goal
   if have_previous and current*previous_error<=0:
    var lo:=previous_z;var hi:=z;var lo_error:=previous_error
    for iteration in 16:
     var mid:float=(lo+hi)*.5;trial.z=mid;solve_limb(k,trial,value,body)
     var difference:float=skin_anchor(k).z-goal
     if difference*lo_error<=0:hi=mid
     else:lo=mid;lo_error=difference
    trial.z=(lo+hi)*.5;solve_limb(k,trial,value,body)
    var precise:float=absf(skin_anchor(k).z-goal)
    var gap:float=absf(trial.z-reference_z)
    if precise<.0001 and gap<best_gap:best=trial;error=precise;best_gap=gap
   previous_z=z;previous_error=current;have_previous=true
 solve_limb(k,best,value,body);last_controls[k]=best.z;plant_errors.append(error)
func aim(i:int,child:int,point:Vector3,target:Vector3) -> void:
 var turn:=Basis(Quaternion(rest[i].origin.direction_to(rest[child].origin),point.direction_to(target)))
 posed[i]=Transform3D(turn*rest[i].basis,point)
func posture(kind:StringName) -> Dictionary:
 var value:Dictionary={"pitch":.16,"down":.06,"z":0.0,"yaw":0.0,"roll":0.0,"head":-.20,"spine_pitch":.30,"head_yaw":0.0,"tail":0.0,"feet":[],"hands":[],"poles":[],"foot_pitch":[0.0,0.0]}
 if kind==&"guard":value.pitch=0.0;value.down=0.0;value.spine_pitch=0.0;value.head=0.0
 elif kind==&"sit":value.pitch=.06;value.spine_pitch=.10;value.down=.26;value.z=-.06;value.head=.03
 elif kind==&"sleep":value.pitch=.20;value.spine_pitch=.15;value.down=.28;value.head=.24
 elif kind==&"stun":value.pitch=.34;value.spine_pitch=.10;value.down=.24;value.roll=.06;value.head=.10
 elif kind==&"corpse":value.pitch=.20;value.spine_pitch=0.0;value.down=.45;value.head=.10
 for side in 2:
  var sign_side:float=-1 if side==0 else 1
  var foot:Vector3=rest[limbs[side].ids[3]].origin;foot.z=-.13
  var hand:=Vector3(sign_side*.70,.278 if side==0 else .259,.45)
  if kind==&"guard":foot=rest[limbs[side].ids[3]].origin;hand=rest[limbs[side+2].ids[2]].origin
  elif kind in [&"sit",&"sleep"]:foot.z=.08;hand.x=sign_side*.62;hand.z=.48
  elif kind==&"stun":foot.x=sign_side*.53;hand.x=sign_side*.69;hand.z=.53
  elif kind==&"corpse":foot.x=sign_side*.72;foot.z=-.30;hand.x=sign_side*.92;hand.z=.58
  value.feet.append(foot);value.hands.append(hand);value.poles.append(rest[limbs[side+2].ids[1]].origin-rest[limbs[side+2].ids[0]].origin)
 return value
func blend(a:Dictionary,b:Dictionary,t:float) -> Dictionary:
 var value:Dictionary=a.duplicate(true)
 for key in ["pitch","down","z","yaw","roll","head","spine_pitch","head_yaw","tail"]:value[key]=lerpf(a[key],b[key],t)
 for key in ["feet","hands","poles"]:
  for side in 2:value[key][side]=a[key][side].lerp(b[key][side],t)
 return value
func boxing() -> Dictionary:
 var value:=posture(&"guard")
 for side in 2:
  var s:float=-1 if side==0 else 1
  var forearm:=Vector3(s*.50,.85,.16).normalized()
  var outward:=(Vector3(s,0,0)-forearm*forearm.dot(Vector3(s,0,0))).normalized()
  var upper:=forearm*cos(deg_to_rad(70))+outward*sin(deg_to_rad(70))
  var limb:Dictionary=limbs[side+2]
  value.hands[side]=rest[limb.ids[0]].origin+upper*limb.a+forearm*limb.b
  value.poles[side]=upper
 return value
func sample(state:StringName,phase:float,left:bool=true) -> Array[Transform3D]:
 if state!=last_state or left!=last_left or (phase<last_phase and not (last_phase>.9 and phase<.1)):last_controls.clear()
 last_state=state;last_phase=phase;last_left=left
 if state==&"reference":posed.assign(rest);return posed
 var t:=clampf(phase,0,1);var cycle:=fposmod(t,1.0);var value:=posture(&"quad");supports.clear();plant_errors.clear()
 if state==&"idle":value.down+=sin(cycle*TAU)*.002;value.head_yaw=sin(cycle*TAU)*.015
 elif state in [&"walk",&"run",&"boxing_walk"]:
  var upright:=state==&"boxing_walk"
  var run:=state==&"run"
  if upright:
   value=boxing();value.down=.04
   for side in 2:value.feet[side].z=-.06;value.hands[side].y-=.04
  else:
   value.pitch=.24 if run else .16;value.down=.09 if run else .06;value.spine_pitch=.34 if run else .30;value.head=-.25 if run else -.20
   if run:
    for side in 2:value.feet[side].z=-.07
  var support:=.60 if upright else (.55 if run else .64)
  var stride:float=(RUN_SPEED if run or upright else WALK_SPEED)/GAME_SCALE*seconds(state)*support*.5
  value.down+=(1-cos(cycle*TAU*2))*(.008 if run else .004)
  value.yaw=sin(cycle*TAU)*.008;value.roll=sin(cycle*TAU)*.008
  for side in 2:
   var offset:float=RIG_PROFILE.phase_offset(&"hind_l" if side==0 else &"hind_r",run)
   var step:=Joint.stance_swing(cycle+offset,stride,.12 if run else .065,support)
   value.feet[side]+=Vector3(0,step.lift,step.z)
   value.foot_pitch[side]=step.pitch*.45 if not step.lift==0 else 0.0
   supports.append({"limb":side,"stance":fposmod(cycle+offset,1)<support})
   if not upright:
    var front_phase:float=cycle+offset+(RIG_PROFILE.phase_offset(&"fore_l" if side==0 else &"fore_r",run)-offset)
    var front:=Joint.stance_swing(front_phase,stride,.11 if run else .07,support)
    value.hands[side]+=Vector3(0,front.lift,front.z)
    supports.append({"limb":side+2,"stance":fposmod(front_phase,1)<support})
  value.tail=sin(cycle*TAU-.4)*.045
 elif state in [&"rise",&"lower",&"boxing_rise",&"boxing_lower"]:
  var up:bool=state in [&"rise",&"boxing_rise"]
  value=blend(value,boxing() if String(state).begins_with("boxing") else posture(&"guard"),smoothstep(0,1,t if up else 1-t))
 elif state in [&"sit_down",&"sit_up"]:value=blend(value,posture(&"sit"),smoothstep(0,1,t if state==&"sit_down" else 1-t))
 elif state==&"sit":value=posture(&"sit");value.down+=sin(cycle*TAU)*.002;value.head_yaw=sin(cycle*TAU)*.07
 elif state in [&"sleep_down",&"sleep",&"wake_up"]:
  value=blend(value,posture(&"sleep"),1.0 if state==&"sleep" else smoothstep(0,1,t if state==&"sleep_down" else 1-t))
  if state==&"sleep":value.down+=sin(cycle*TAU)*.0018;value.head+=sin(cycle*TAU)*.004
 elif state in [&"stun_fall",&"stun_hold",&"stun_rise"]:value=blend(value,posture(&"stun"),1.0 if state==&"stun_hold" else smoothstep(0,1,t if state==&"stun_fall" else 1-t))
 elif state in [&"death",&"corpse"]:
  var progress:=1.0 if state==&"corpse" else t
  var kneel:=posture(&"quad");kneel.down=.28;kneel.pitch=.30
  value=blend(value,kneel,smoothstep(0,.35,progress));value=blend(value,posture(&"corpse"),smoothstep(.35,1,progress))
 elif state in [&"boxing_guard",&"hook"]:
  value=boxing()
  if state==&"boxing_guard":value.down+=sin(cycle*TAU)*.002
  else:
   var sign_side:float=-1 if left else 1
   var drive:=smoothstep(.24,.55,t)*(1-smoothstep(.65,1,t));var load:=smoothstep(0,.24,t)*(1-smoothstep(.24,.55,t))
   value.yaw=sign_side*(load*.14-drive*.24);value.head_yaw=-sign_side*drive*.12
   var side:=0 if left else 1
   var angle:=lerpf(PI*.5,.55,smoothstep(.24,.58,t))
   var swept:=Vector3(sign_side*(.24+.63*sin(angle)),1.18,.38+.52*cos(angle))
   var opened:=Vector3(sign_side*.92,1.20,.36)
   var target:Vector3=value.hands[side].lerp(opened,smoothstep(0,.24,t)) if t<.24 else swept.lerp(value.hands[side],smoothstep(.65,1,t))
   value.hands[side]=target;value.poles[side]=value.poles[side].lerp(Vector3(sign_side,.15,-.4),drive+load)
 elif state==&"attack":
  value=posture(&"guard")
  var sign_side:float=-1 if left else 1
  var drive:=smoothstep(.27,.5,t)*(1-smoothstep(.65,1,t));var load:=smoothstep(0,.27,t)*(1-smoothstep(.5,.88,t))
  value.yaw=sign_side*(load*.08-drive*.13);value.z=drive*.035;value.pitch=drive*.035
  var side:=0 if left else 1
  var rest_hand:Vector3=value.hands[side]
  value.hands[side]=Joint.gesture(rest_hand,Vector3(sign_side*.70,.80,.18),Vector3(sign_side*.55,.97,.99),t,&"fist")
  value.hands[1-side]=value.hands[1-side].lerp(Vector3(-sign_side*.63,.69,.44),load*.5+drive*.3)
 elif state==&"feed":
  value.head=.045*sin(cycle*TAU*2);value.z=.04*smoothstep(0,.2,cycle)*(1-smoothstep(.75,1,cycle))
  for side in 2:
   var part:=fposmod(cycle+side*.5,1)
   var reach:=smoothstep(0,.16,part)*(1-smoothstep(.32,.55,part))
   value.hands[side]=value.hands[side].lerp(Vector3((-1 if side==0 else 1)*.57,.56,.78),reach)
 var chest_yaw:float=value.yaw if state in [&"attack",&"hook"] else 0.0
 if state in [&"attack",&"hook"]:value.yaw=0.0
 var basis:=Basis.from_euler(Vector3(value.pitch,value.yaw,value.roll));var pivot:=Vector3(0,.65,-.15)
 var body:=Transform3D(basis,pivot-basis*pivot+Vector3(0,-value.down,value.z))
 var solved:Array[Dictionary]=[]
 solved.resize(4)
 for i in rest.size():
  posed[i]=posed[parents[i]]*local_rest[i] if parents[i]>=0 else body*rest[i]
  if i==names.Bone_003:posed[i].basis=Basis(Vector3.UP,chest_yaw)*Basis(Vector3.RIGHT,value.spine_pitch)*posed[i].basis
  if i==names.Bone_016:posed[i].basis=Basis(Vector3.UP,value.head_yaw)*Basis(Vector3.RIGHT,value.head)*posed[i].basis
  if i==names.Bone_005:posed[i].basis=Basis(Vector3.UP,value.tail)*posed[i].basis
  for k in 4:
   var limb:Dictionary=limbs[k];var ids:Array=limb.ids;var side:int=k%2
   if i==ids[0]:
    var end:Vector3=value.feet[side] if k<2 else value.hands[side]
    var terminal:=Vector3.ZERO
    if k<2:terminal=Basis(Vector3.RIGHT,value.foot_pitch[side])*(rest[ids[3]].origin-rest[ids[2]].origin);end-=terminal
    var pole:Vector3=body.basis*((Vector3((-1 if side==0 else 1),.05,.12) if state in [&"death",&"corpse"] else rest[ids[1]].origin-rest[ids[0]].origin) if k<2 else value.poles[side])
    var amount:=0.0
    if k<2 and state in [&"death",&"corpse"]:amount=1.0 if state==&"corpse" else smoothstep(.35,1,t)
    elif k>=2 and state in [&"boxing_guard",&"boxing_walk",&"hook"]:amount=1.0
    elif k>=2 and state in [&"boxing_rise",&"boxing_lower"]:amount=smoothstep(0,1,t if state==&"boxing_rise" else 1-t)
    pole=stable_pole(k,end,pole,amount)
    solved[k]=Rig.solve_metres(posed[i].origin,end,limb.a,limb.b,pole)
    solved[k].terminal=terminal
    aim(i,ids[1],solved[k].root,solved[k].joint)
   elif i==ids[1]:aim(i,ids[2],solved[k].joint,solved[k].end)
   elif i==ids[2]:
    var frame:Basis=Basis(Vector3.RIGHT,value.foot_pitch[side])*rest[i].basis if k<2 else (body.basis*rest[i].basis if state in [&"idle",&"walk",&"run",&"feed",&"sit",&"sleep",&"corpse",&"death"] else posed[ids[1]].basis*rest[ids[1]].basis.inverse()*rest[i].basis)
    posed[i]=Transform3D(frame,solved[k].end)
   elif k<2 and i==ids[3]:posed[i]=Transform3D(posed[ids[2]].basis*rest[ids[2]].basis.inverse()*rest[i].basis,solved[k].end+solved[k].terminal)
 if state in [&"walk",&"run",&"boxing_walk"]:
  var support:=.60 if state==&"boxing_walk" else (.55 if state==&"run" else .64)
  var stride:float=(RUN_SPEED if state!=&"walk" else WALK_SPEED)/GAME_SCALE*seconds(state)*support*.5
  for side in 2:
   var offset:float=RIG_PROFILE.phase_offset(&"hind_l" if side==0 else &"hind_r",state==&"run")
   var step:=Joint.stance_swing(cycle+offset,stride,0,support)
   plant_surface(side,-.18+step.z,value,body)
   if state!=&"boxing_walk":
    var front:=Joint.stance_swing(cycle+offset+(RIG_PROFILE.phase_offset(&"fore_l" if side==0 else &"fore_r",state==&"run")-offset),stride,0,support)
    plant_surface(side+2,(.50 if state==&"run" else .55)+front.z,value,body)
 return posed
