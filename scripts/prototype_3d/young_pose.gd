extends RefCounted
## Authored motion for the reference creature: a heavy knuckle walker, with
## fixed anatomy and a bind stance independent from the animation catalogue.
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
const STATES:Array[StringName]=[&"idle",&"walk",&"run",&"rise",&"attack",&"lower",&"sit_down",&"sit",&"sit_up",&"feed",&"stun_fall",&"stun_hold",&"stun_rise",&"death",&"corpse"]

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
 return {&"walk":.52,&"run":.26,&"rise":.28,&"lower":.28,&"attack":1.0,&"sit_down":.28,&"sit_up":.28,&"sit":4.0,&"idle":4.0,&"feed":1.5,&"stun_fall":.24,&"stun_hold":1.02,&"stun_rise":.24,&"death":2.0,&"corpse":2.0}.get(state,1.0)

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
  pose.body=body_frame(.20+sin(cycle*TAU*2)*.008,0.0+(1-cos(cycle*TAU*2))*(.12 if run else .06),0,wave*.009,wave*.012,wave*.10)
  pose.head=Basis.from_euler(Vector3(sin(cycle*TAU*2)*.012,-wave*.012,-wave*.006))
  for side in 2:
   var hind:=Joints.stance_swing(cycle+side*.5,4.5,1.8 if run else 1.25,.6)
   var front:=Joints.stance_swing(cycle+side*.5+(.5 if run else .25),4.3,1.4 if run else .9,.6)
   pose.feet[side]+=Vector3(0,hind.lift,hind.z);pose.pitches[side]=hind.pitch
   pose.hands[side]+=Vector3(0,front.lift,front.z)
 elif state in [&"rise",&"lower"]:
  var rising:=t if state==&"rise" else 1-t
  pose=between(setup(&"quad"),setup(&"guard"),smoothstep(0,1,rising))
  # Transfer to the hind feet before unloading the heavy front fists.
  for side in 2:
   var step:=smoothstep(side*.35,(side+1)*.35,rising)
   pose.feet[side].z=lerpf(-4.5,-4.5,step)
   pose.feet[side].y+=sin(step*PI)*.65
   pose.hands[side]=(setup(&"quad").hands[side] as Vector3).lerp(setup(&"guard").hands[side],smoothstep(.35,1,rising))
 elif state==&"attack":
  pose=setup(&"guard")
  var wind:=smoothstep(0,.27,t)*(1-smoothstep(.50,.82,t))
  var drive:=smoothstep(.27,.5,t)*(1-smoothstep(.65,1,t))
  var s:float=1 if left else -1
  pose.body=body_frame(drive*.08,drive*.25,drive*.85-wind*.20,s*(wind*.07-drive*.10),s*drive*.018,s*(wind*.20-drive*.25))
  pose.head=Basis(Vector3.UP,-s*drive*.025)
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
 elif state==&"death":pose=between(setup(&"quad"),setup(&"corpse"),smoothstep(0,.88,t))
 elif state==&"corpse":pose=setup(&"corpse")
 return solve(pose,state,t)

static func solve(data:Dictionary,state:StringName,phase:float) -> Dictionary:
 var body:Transform3D=data.body
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
  var knee_pole:=Basis(Vector3.UP,body.basis.get_euler().y)*Vector3.BACK
  var leg:=Joints.joint(body*Vector3(s*HIP_X,8.5,-6),ankle,LEG_A,LEG_B,knee_pole)
  leg.pitch=pitch;legs.append(leg)
  arms.append(Joints.joint(body*Vector3(s*SHOULDER_X,18,5.5),data.hands[side],ARM_A,ARM_B,body.basis*Vector3(s,0,-.3)))
 return {"body":body,"head":data.head,"head_origin":body*HEAD_ROOT,"legs":legs,"arms":arms,"standing":data.standing,"state":state,"phase":phase}

static func blend(current:Dictionary,target:Dictionary,delta:float) -> Dictionary:
 return mix(current,target,1-exp(-maxf(0,delta)*18))

static func mix(current:Dictionary,target:Dictionary,amount:float) -> Dictionary:
 var pose:Dictionary=target.duplicate(true)
 pose.body=(current.body as Transform3D).interpolate_with(target.body,amount)
 pose.head=(current.head as Basis).slerp(target.head,amount)
 pose.standing=lerpf(current.standing,target.standing,amount)
 var feet:Array=[];var hands:Array=[];var pitches:Array=[]
 for side in 2:
  feet.append((current.legs[side].end as Vector3).lerp(target.legs[side].end,amount))
  hands.append((current.arms[side].end as Vector3).lerp(target.arms[side].end,amount))
  pitches.append(lerpf(current.legs[side].get("pitch",0),target.legs[side].get("pitch",0),amount))
 pose.feet=feet;pose.hands=hands;pose.pitches=pitches;pose.adjust_sole=false
 return solve(pose,target.state,target.phase)
