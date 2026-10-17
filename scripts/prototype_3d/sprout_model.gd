extends Node3D
## Enemy3: the user's mesh, UVs, skin weights and 35-bone rig, in source metres.
## Pure presentation; the first walk does not add AI, spawns or combat rules.
const SOURCE=preload("res://assets/enemies/third/sprout/model.scn")
const Body=preload("res://scripts/continuous_body_pose.gd")
const CYCLE_SECONDS:=1.25
const STRIDE:=0.095
const SUPPORT:=0.60
const SPEED:=2.0*STRIDE/(SUPPORT*CYCLE_SECONDS)
const GROUND_OFFSET:=0.015508
const RUN_CYCLE_SECONDS:=.60
const RUN_SUPPORT:=.42
const RUN_SPEED:=SPEED*10.0
const RUN_STRIDE:=RUN_SPEED*RUN_SUPPORT*RUN_CYCLE_SECONDS*.5
const RUN_PITCH:=PI/3
const VISUAL_BOUNDS:=AABB(Vector3(-1,-.7,-1.7),Vector3(2,2.5,3.6))
var skeleton:Skeleton3D
var mesh_node:MeshInstance3D
var bind:Array[Transform3D]=[]
var local_bind:Array[Transform3D]=[]
var posed:Array[Transform3D]=[]
var parents:Array[int]=[]
var contacts:Array[Dictionary]=[]

func _ready() -> void:
 var model:=SOURCE.instantiate();add_child(model);model.position.y+=GROUND_OFFSET
 skeleton=model.find_children("*","Skeleton3D",true,false)[0]
 mesh_node=model.find_children("*","MeshInstance3D",true,false)[0]
 mesh_node.custom_aabb=VISUAL_BOUNDS
 for i in skeleton.get_bone_count():
  bind.append(skeleton.get_bone_global_pose(i));local_bind.append(skeleton.get_bone_pose(i));parents.append(skeleton.get_bone_parent(i))
 posed.assign(bind)

func bone(label:String) -> int:return skeleton.find_bone(label)
func inherit(i:int) -> void:
 posed[i]=posed[parents[i]]*local_bind[i] if parents[i]>=0 else local_bind[i]
func aim(i:int,child:int,origin:Vector3,target:Vector3) -> void:
 var turn:=Basis(Quaternion((bind[child].origin-bind[i].origin).normalized(),(target-origin).normalized()))
 posed[i]=Transform3D(turn*bind[i].basis,origin)
func turn_about(i:int,axis:Vector3,angle:float) -> void:
 posed[i].basis=Basis(axis,angle)*posed[i].basis

func animate(phase:float,amount:float=1.0) -> void:
 if not is_instance_valid(skeleton):return
 amount=clampf(amount,0,1);phase=fposmod(phase,1.0)
 contacts.clear()
 # All four independent roots in the supplied rig follow the same body motion.
 var body:=Transform3D(Basis.IDENTITY,Vector3(.004*sin(phase*TAU)*amount,-.006*(1-cos(phase*TAU*2))*amount,0))
 for i in bind.size():
  inherit(i)
  if parents[i]<0:posed[i]=body*bind[i]
  for side in 2:
   var suffix:="_L" if side==0 else "_R"
   var hip:=bone("pierna2"+suffix);var knee:=bone("pierna3"+suffix);var hock:=bone("pierna4"+suffix);var foot:=bone("pierna5"+suffix)
   if i==hip:
    var step:=Body.stance_swing(phase+side*.5,STRIDE*amount,.045*amount,SUPPORT,amount)
    var ankle:=bind[foot].origin+Vector3(0,step.lift,step.z)
    # Keep the digitigrade lower segment and sole level during ground support.
    # The shared solver uses authoring units; scale metres to centimetres so its
    # fixed numerical margin is 0.4 mm instead of four centimetres.
    var target_hock:Vector3=ankle-(bind[foot].origin-bind[hock].origin)
    var upper:float=bind[hip].origin.distance_to(bind[knee].origin)
    var lower:float=bind[knee].origin.distance_to(bind[hock].origin)
    var solved:=Body.joint(posed[hip].origin*100,target_hock*100,upper*100,lower*100,Vector3(0,0,1))
    var joint:Vector3=solved.joint/100;var end:Vector3=solved.end/100
    aim(hip,knee,posed[hip].origin,joint)
    # Children are solved when visited; temporary targets survive inheritance.
    contacts.append({"side":side,"stance":fposmod(phase+side*.5,1)<SUPPORT,"target":ankle,"knee":joint,"hock":end,"foot":foot})
   if i==knee:
    var c:Dictionary=contacts[side];aim(knee,hock,c.knee,c.hock)
   if i==hock:
    var c:Dictionary=contacts[side];aim(hock,foot,c.hock,c.target)
   if i==foot:posed[i]=Transform3D(bind[i].basis,contacts[side].target)
   # Small arms counterbalance the alternating hind legs, preserving the fingers.
   if i==bone("brazo2"+suffix):turn_about(i,Vector3.RIGHT,.13*sin((phase+side*.5)*TAU)*amount)
  if i==bone("Hueso.001"):turn_about(i,Vector3.UP,.025*sin(phase*TAU)*amount)
  if i==bone("Hueso.004"):turn_about(i,Vector3.UP,-.02*sin(phase*TAU)*amount)
  if i==bone("pierna1_R.002"):turn_about(i,Vector3.UP,.045*sin(phase*TAU-.45)*amount)
  if i==bone("pierna1_R.004"):turn_about(i,Vector3.UP,.035*sin(phase*TAU-.9)*amount)
 # amount=0 restores the supplied pose exactly, including the authored wrist.
 if amount==0:posed.assign(bind)
 for i in bind.size():skeleton.set_bone_pose(i,posed[parents[i]].affine_inverse()*posed[i] if parents[i]>=0 else posed[i])


func animate_run(phase:float,amount:float=1.0) -> void:
 if not is_instance_valid(skeleton):return
 phase=fposmod(phase,1.0);amount=clampf(amount,0,1)
 contacts.clear()
 # The original roots share a modest running crouch; the lumbar joint alone
 # inclines the chest/head. Legs keep independent support on the ground.
 var bob:=.010*sin(phase*TAU*2)
 var body:=Transform3D(Basis.IDENTITY,Vector3(.007*sin(phase*TAU)*amount,(-.11+bob)*amount,0))
 for i in bind.size():
  inherit(i)
  if parents[i]<0:posed[i]=body*bind[i]
  if i==bone("Hueso.001"):turn_about(i,Vector3.RIGHT,RUN_PITCH*amount)
  for side in 2:
   var suffix:="_L" if side==0 else "_R"
   var hip:=bone("pierna2"+suffix);var knee:=bone("pierna3"+suffix);var hock:=bone("pierna4"+suffix);var foot:=bone("pierna5"+suffix)
   if i==hip:
    var step:=Body.stance_swing(phase+side*.5,RUN_STRIDE*amount,.13*amount,RUN_SUPPORT,amount)
    var ankle:=bind[foot].origin+Vector3(0,step.lift,step.z)
    var target_hock:Vector3=ankle-(bind[foot].origin-bind[hock].origin)
    var upper:float=bind[hip].origin.distance_to(bind[knee].origin)
    var lower:float=bind[knee].origin.distance_to(bind[hock].origin)
    var solved:=Body.joint(posed[hip].origin*100,target_hock*100,upper*100,lower*100,Vector3(0,0,1))
    var joint:Vector3=solved.joint/100;var end:Vector3=solved.end/100
    aim(hip,knee,posed[hip].origin,joint)
    contacts.append({"side":side,"stance":fposmod(phase+side*.5,1)<RUN_SUPPORT,"target":ankle,"knee":joint,"hock":end,"foot":foot})
   if i==knee:
    var c:Dictionary=contacts[side];aim(knee,hock,c.knee,c.hock)
   if i==hock:
    var c:Dictionary=contacts[side];aim(hock,foot,c.hock,c.target)
   if i==foot:posed[i]=Transform3D(bind[i].basis,contacts[side].target)
   # Shoulder swing stays local to the tilted chest, preserving elbows/digits.
   if i==bone("brazo2"+suffix):turn_about(i,Vector3.RIGHT,.32*sin((phase+side*.5)*TAU)*amount)
  if i==bone("pierna1_R.002"):turn_about(i,Vector3.RIGHT,-.12*amount)
  if i==bone("pierna1_R.004"):turn_about(i,Vector3.UP,.065*sin(phase*TAU-.6)*amount)
 if amount==0:posed.assign(bind)
 for i in bind.size():skeleton.set_bone_pose(i,posed[parents[i]].affine_inverse()*posed[i] if parents[i]>=0 else posed[i])
