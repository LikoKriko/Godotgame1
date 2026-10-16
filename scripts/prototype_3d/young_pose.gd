extends RefCounted
## Authored motion for the reference creature: a heavy knuckle walker, with
## fixed anatomy and a bind stance independent from the animation catalogue.
const Frames=preload("res://scripts/prototype_3d/human_kinematics.gd")
const Fall=preload("res://scripts/prototype_3d/fall_motion.gd")
const Joints=preload("res://scripts/continuous_body_pose.gd")
const ARM_A:=6.1
const ARM_B:=6.6
const LEG_A:=4.3
const LEG_B:=4.4
const HIP_X:=7.0
const FOOT_X:=8.4
const SHOULDER_X:=8.7
const REST_HAND:=Vector3(10.8,9.2,13.0)
const HEAD_ANCHOR:=Vector3(0,22,7)
const SNOUT_OFFSET:=Vector3(0,-5.8811,14.8445)
const HEAD_ROOT:=HEAD_ANCHOR
const FOOT_Y:=1.5
const FIST_Y:=5.0
const STATES:Array[StringName]=[&"idle",&"walk",&"run",&"rise",&"attack",&"boxing_guard",&"boxing_walk",&"boxing_rise",&"boxing_lower",&"hook",&"lower",&"sit_down",&"sit",&"sit_up",&"feed",&"stun_fall",&"stun_hold",&"stun_rise",&"death",&"corpse"]

static func bind_pose() -> Dictionary:
 # Fixed neutral joints used to bake the Meshy heat weights. Animation edits
 # must never change these coordinates or the imported geometry.
 var legs:Array=[];var arms:Array=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  var leg:=Joints.joint(Vector3(s*HIP_X,8.5,-6),Vector3(s*FOOT_X,1.5,-4.5),LEG_A,LEG_B,Vector3.BACK)
  leg.pitch=0.0;legs.append(leg)
  arms.append(Joints.joint(Vector3(s*SHOULDER_X,18,5.5),Vector3(s*REST_HAND.x,REST_HAND.y,REST_HAND.z),ARM_A,ARM_B,Vector3(s,0,-.3)))
 return {"body":Transform3D.IDENTITY,"head":Basis.IDENTITY,"head_origin":HEAD_ROOT,"legs":legs,"arms":arms,"standing":1.0,"state":&"reference","phase":0.0}

static func seconds(state:StringName) -> float:
 return {&"walk":.52,&"run":.36,&"rise":.28,&"lower":.28,&"attack":1.0,&"hook":1.2,&"boxing_rise":.28,&"boxing_lower":.28,&"boxing_walk":.65,&"boxing_guard":4.0,&"sit_down":.28,&"sit_up":.28,&"sit":4.0,&"idle":4.0,&"feed":1.5,&"stun_fall":.24,&"stun_hold":1.02,&"stun_rise":.24,&"death":2.0,&"corpse":2.0}.get(state,1.0)

static func body_frame(pitch:float,down:float,z:float=0.0,yaw:float=0.0,roll:float=0.0,x:float=0.0) -> Transform3D:
 var pivot:=Vector3(0,8.5,-6)
 var basis:=Basis.from_euler(Vector3(pitch,yaw,roll))
 return Transform3D(basis,pivot-basis*pivot+Vector3(x,-down,z))

static func setup(kind:StringName) -> Dictionary:
 var body:=body_frame(.20,0)
 var head:=Basis.IDENTITY
 var standing:=0.0
 if kind==&"guard":body=Transform3D.IDENTITY;standing=1.0
 if kind==&"sit":body=body_frame(.14,3.0,-.6);head=Basis(Vector3.RIGHT,.04)
 if kind==&"stun":body=body_frame(.38,2.0,0,0,.035);head=Basis(Vector3.RIGHT,.30)
 if kind==&"corpse":body=body_frame(.55,1.0,0,0,.12);head=Basis.from_euler(Vector3(.20,0,.07))
 var feet:Array=[];var hands:Array=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  var foot:=Vector3(s*FOOT_X,FOOT_Y,-4.5)
  var hand:=Vector3(s*10.8,FIST_Y,14.0)
  if kind==&"guard":foot=Vector3(s*FOOT_X,1.5,-4.5);hand=Vector3(s*REST_HAND.x,REST_HAND.y,REST_HAND.z)
  if kind==&"sit":foot=Vector3(s*9.0,FOOT_Y+.5,0.0);hand=Vector3(s*12.2,FIST_Y+.85,12.2)
  if kind in [&"stun",&"corpse"]:foot=Vector3(s*9.0,FOOT_Y+.5,-6.0);hand=Vector3(s*(14.2 if kind==&"stun" else 14.5),FIST_Y+.85,12.2)
  feet.append(foot);hands.append(hand)
 return {"body":body,"head":head,"feet":feet,"hands":hands,"pitches":[0.0,0.0],"standing":standing}

static func between(a:Dictionary,b:Dictionary,amount:float) -> Dictionary:
 var pose:Dictionary=a.duplicate(true)
 pose.body=(a.body as Transform3D).interpolate_with(b.body,amount)
 pose.head=(a.head as Basis).slerp(b.head,amount)
 pose.standing=lerpf(a.standing,b.standing,amount)
 for side in 2:
  pose.feet[side]=(a.feet[side] as Vector3).lerp(b.feet[side],amount)
  pose.hands[side]=(a.hands[side] as Vector3).lerp(b.hands[side],amount)
 return pose

static func boxing_setup() -> Dictionary:
 var pose:=setup(&"guard")
 pose.arm_poles=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  # 110 degree interior elbow angle: upper-arm/forearm directions differ by 70.
  # The stone fists sit outside the cheeks, never in front of the long snout.
  var forearm:=Vector3(-s*.10,.96,.26).normalized()
  var outward:=(Vector3(s,0,0)-forearm*forearm.dot(Vector3(s,0,0))).normalized()
  var upper:=forearm*cos(deg_to_rad(70))+outward*sin(deg_to_rad(70))
  var shoulder:=Vector3(s*SHOULDER_X,18,5.5)
  pose.hands[side]=shoulder+upper*ARM_A+forearm*ARM_B
  pose.arm_poles.append(upper)
 return pose

static func sample(state:StringName,phase:float,left:bool=true) -> Dictionary:
 if state==&"reference":return bind_pose()
 var t:=clampf(phase,0,1)
 var pose:=setup(&"quad")
 var cycle:=fposmod(t,1.0)
 var walking:=state in [&"walk",&"run"]
 if state==&"idle":
  pose.body.origin.y+=sin(cycle*TAU)*.045
  pose.head=Basis(Vector3.UP,sin(cycle*TAU)*.018)
 elif walking:
  var run:=state==&"run"
  var wave:=sin(cycle*TAU)
  pose.body=body_frame((.32 if run else .20)+sin(cycle*TAU*2)*.008,0.0+(1-cos(cycle*TAU*2))*(.12 if run else .06),0,wave*.009,wave*.012,wave*.10)
  pose.head=Basis.from_euler(Vector3(sin(cycle*TAU*2)*.012,-wave*.012,-wave*.006))
  for side in 2:
   var hind:=Joints.stance_swing(cycle+side*.5,6.0 if run else 4.5,1.8 if run else 1.25,.6)
   var front:=Joints.stance_swing(cycle+side*.5+(.5 if run else .25),5.4 if run else 4.3,1.4 if run else .9,.6)
   pose.feet[side]+=Vector3(0,hind.lift,hind.z);pose.pitches[side]=hind.pitch
   pose.hands[side]+=Vector3(0,front.lift,front.z-(3.0 if run else 0.0))
 elif state in [&"rise",&"lower"]:
  var rising:=t if state==&"rise" else 1-t
  pose=between(setup(&"quad"),setup(&"guard"),smoothstep(0,1,rising))
  # Transfer to the hind feet before unloading the heavy front fists.
  for side in 2:
   var step:=smoothstep(side*.35,(side+1)*.35,rising)
   pose.feet[side].z=lerpf(-4.5,-4.5,step)
   pose.feet[side].y+=sin(step*PI)*.65
   pose.hands[side]=(setup(&"quad").hands[side] as Vector3).lerp(setup(&"guard").hands[side],smoothstep(.35,1,rising))
 elif state in [&"boxing_guard",&"boxing_walk",&"boxing_rise",&"boxing_lower",&"hook"]:
  pose=boxing_setup()
  if state in [&"boxing_rise",&"boxing_lower"]:
   pose=between(setup(&"quad"),pose,smoothstep(0,1,t if state==&"boxing_rise" else 1-t))
   # Interpolate the elbow pole too, avoiding an abrupt elbow flip on standing.
   var amount:=smoothstep(0,1,t if state==&"boxing_rise" else 1-t)
   for side in 2:
    var s:float=-1 if side==0 else 1
    pose.get_or_add("arm_poles",[]).append((pose.body.basis*Vector3(s,0,-.3)).lerp(boxing_setup().arm_poles[side],amount))
  elif state==&"boxing_walk":
   for side in 2:
    var step:=Joints.stance_swing(cycle+side*.5,1.9,.7,.65)
    pose.feet[side]+=Vector3(0,step.lift,step.z)
    pose.pitches[side]=step.pitch*.4
  elif state==&"hook":
   var s:float=1 if left else -1
   var wind:=smoothstep(0,.25,t)*(1-smoothstep(.25,.50,t))
   var turn:=smoothstep(.25,.53,t)*(1-smoothstep(.66,1,t))
   # Rotate about the hips without translating or lifting the planted feet.
   pose.pelvis=Transform3D.IDENTITY
   pose.body=body_frame(turn*.025,0,0,s*(wind*.10-turn*.20),s*turn*.018)
   pose.head=pose.body.basis*Basis(Vector3.UP,s*(turn*.06-wind*.03))
   for side in 2:
    var sign_side:float=-1 if side==0 else 1
    var hand:Vector3=pose.hands[side]
    if (side==1)==left:
     var opened:=Vector3(sign_side*19.0,22.0,9.0)
     var swept:Vector3
     var arc:=smoothstep(.25,.58,t)
     var angle:=lerpf(PI*.5,.70,arc)
     swept=Vector3(sign_side*(4.0+15.0*sin(angle)),22.0,9.0+10.0*cos(angle))
     hand=hand.lerp(opened,smoothstep(0,.25,t)) if t<.25 else swept.lerp(hand,smoothstep(.66,1,t))
     pose.arm_poles[side]=(pose.arm_poles[side] as Vector3).lerp(Vector3(sign_side,.12,-.25),smoothstep(0,.25,t)*(1-smoothstep(.66,1,t)))
    pose.hands[side]=pose.body*hand
    pose.arm_poles[side]=pose.body.basis*pose.arm_poles[side]
 elif state==&"attack":
  pose=setup(&"guard")
  var wind:=smoothstep(0,.27,t)*(1-smoothstep(.50,.82,t))
  var drive:=smoothstep(.27,.5,t)*(1-smoothstep(.65,1,t))
  var s:float=1 if left else -1
  pose.pelvis=Transform3D.IDENTITY
  pose.body=body_frame(drive*.08,drive*.12,drive*.85-wind*.20,s*(wind*.10-drive*.16),s*drive*.018,s*(wind*.20-drive*.25))
  pose.head=pose.body.basis*Basis(Vector3.UP,-s*drive*.025)
  for side in 2:
   var sign_side:float=-1 if side==0 else 1
   var rest:=Vector3(sign_side*REST_HAND.x,REST_HAND.y,REST_HAND.z)
   var hand:=rest
   if (side==1)==left:
    hand=Joints.gesture(rest,Vector3(sign_side*11.5,15.0,5.0),Vector3(sign_side*9.0,16.0,16.0),t,&"fist")
   else:hand=rest.lerp(Vector3(sign_side*11.8,12.5,9.0),wind*.55+drive*.35)
   pose.hands[side]=pose.body*hand
 elif state in [&"sit_down",&"sit_up"]:
  var sitting:=t if state==&"sit_down" else 1-t
  pose=between(setup(&"quad"),setup(&"sit"),smoothstep(0,1,sitting))
  for side in 2:
   var step:=smoothstep(side*.42,(side+1)*.42,sitting)
   pose.feet[side].z=lerpf(-4.5,0,step)
   pose.feet[side].y+=sin(step*PI)*.65
 elif state==&"sit":
  pose=setup(&"sit")
  pose.body.origin.y+=sin(cycle*TAU)*.05
  pose.head=Basis.from_euler(Vector3(.04+sin(cycle*TAU*2)*.012,sin(cycle*TAU)*.10,0))
 elif state==&"feed":
  for side in 2:
   var feed_cycle:=fposmod(cycle+side*.5,1)
   var reach:=smoothstep(0,.12,feed_cycle)*(1-smoothstep(.28,.46,feed_cycle))
   var s:float=-1 if side==0 else 1
   pose.hands[side]=(pose.hands[side] as Vector3).lerp(Vector3(s*11.2,8.5,18.0),reach)
  pose.head=Basis.from_euler(Vector3(.08*sin(cycle*TAU*2),sin(cycle*TAU)*.025,0))
 elif state in [&"stun_fall",&"stun_rise"]:
  var falling:=t if state==&"stun_fall" else 1-t
  pose=between(setup(&"quad"),setup(&"stun"),smoothstep(0,1,falling))
 elif state==&"stun_hold":pose=setup(&"stun")
 elif state==&"death":pose=Fall.young(t,setup(&"quad"))
 elif state==&"corpse":pose=Fall.young(1,setup(&"quad"))
 return solve(pose,state,t)

static func solve(data:Dictionary,state:StringName,phase:float) -> Dictionary:
 var body:Transform3D=data.body
 var pelvis:Transform3D=data.get("pelvis",body)
 var legs:Array=[];var arms:Array=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  var ankle:Vector3=data.feet[side]
  var pitch:float=data.pitches[side]
  # Roll about the visible toe/heel support, including the long stone claws.
  if data.get("adjust_sole",true):
   ankle.y+=maxf(0,sin(pitch))*8.8+maxf(0,-sin(pitch))*4.5
   # Heat weights blend the rear sole into the calf. Clear the heel as the
   # short tibia swings forward, rather than stretching it through the floor.
   ankle.y+=maxf(0,ankle.z+4.5)*.27+absf(ankle.z+4.5)*.15
  var knee_pole:Vector3=data.get("leg_poles",[Basis(Vector3.UP,pelvis.basis.get_euler().y)*Vector3.BACK,Basis(Vector3.UP,pelvis.basis.get_euler().y)*Vector3.BACK])[side]
  var leg:=Joints.joint(pelvis*Vector3(s*HIP_X,8.5,-6),ankle,LEG_A,LEG_B,knee_pole)
  leg.pitch=pitch;legs.append(leg)
  arms.append(Joints.joint(body*Vector3(s*SHOULDER_X,18,5.5),data.hands[side],ARM_A,ARM_B,data.get("arm_poles",[body.basis*Vector3(-1,0,-.3),body.basis*Vector3(1,0,-.3)])[side]))
 return {"foot_bases":data.get("foot_bases",[]),"tail_turn":data.get("tail_turn",0.0),"body":body,"pelvis":pelvis,"head":data.head,"head_origin":body*HEAD_ROOT,"legs":legs,"arms":arms,"standing":data.standing,"state":state,"phase":phase}

static func blend(current:Dictionary,target:Dictionary,delta:float) -> Dictionary:
 return mix(current,target,1-exp(-maxf(0,delta)*18))

static func mix(current:Dictionary,target:Dictionary,amount:float) -> Dictionary:
 var pose:Dictionary=target.duplicate(true)
 pose.body=(current.body as Transform3D).interpolate_with(target.body,amount)
 pose.pelvis=(current.get("pelvis",current.body) as Transform3D).interpolate_with(target.get("pelvis",target.body),amount)
 pose.head=(current.head as Basis).slerp(target.head,amount)
 pose.standing=lerpf(current.standing,target.standing,amount)
 pose.tail_turn=lerpf(current.get("tail_turn",0.0),target.get("tail_turn",0.0),amount)
 pose.leg_poles=[]
 pose.foot_bases=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  var foot:Vector3=(current.legs[side].end as Vector3).lerp(target.legs[side].end,amount)
  var hip:Vector3=pose.pelvis*Vector3(s*HIP_X,8.5,-6)
  pose.leg_poles.append(Frames.transport_pole((current.legs[side].end-current.legs[side].root).normalized(),current.legs[side].joint-current.legs[side].root,hip.direction_to(foot),target.legs[side].joint-target.legs[side].root,amount))
  var old:Basis=current.foot_bases[side] if not current.get("foot_bases",[]).is_empty() else Basis(Vector3.RIGHT,current.legs[side].get("pitch",0.0))
  var next:Basis=target.foot_bases[side] if not target.get("foot_bases",[]).is_empty() else Basis(Vector3.RIGHT,target.legs[side].get("pitch",0.0))
  pose.foot_bases.append(old.slerp(next,amount))
 var feet:Array=[];var hands:Array=[];var pitches:Array=[];var poles:Array=[]
 for side in 2:
  var s:float=-1 if side==0 else 1
  var hand:Vector3=(current.arms[side].end as Vector3).lerp(target.arms[side].end,amount)
  var shoulder:Vector3=pose.body*Vector3(s*SHOULDER_X,18,5.5)
  poles.append(Frames.transport_pole((current.arms[side].end-current.arms[side].root).normalized(),current.arms[side].joint-current.arms[side].root,shoulder.direction_to(hand),target.arms[side].joint-target.arms[side].root,amount))
  feet.append((current.legs[side].end as Vector3).lerp(target.legs[side].end,amount))
  hands.append((current.arms[side].end as Vector3).lerp(target.arms[side].end,amount))
  pitches.append(lerpf(current.legs[side].get("pitch",0),target.legs[side].get("pitch",0),amount))
 pose.arm_poles=poles;pose.feet=feet;pose.hands=hands;pose.pitches=pitches;pose.adjust_sole=false
 return solve(pose,target.state,target.phase)
