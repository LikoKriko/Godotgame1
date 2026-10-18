extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Model=preload("res://scripts/prototype_3d/survivor_model.gd")
const Turn=preload("res://scripts/prototype_3d/gait_direction.gd")
const Kinematics=preload("res://scripts/prototype_3d/human_kinematics.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 for fps in [30,60,120]:
  for from in 8:
   for to in 8:
    if from==to:continue
    var turn:=Turn.new();var a:=Vector3(sin(from*TAU/8),0,cos(from*TAU/8));var b:=Vector3(sin(to*TAU/8),0,cos(to*TAU/8))
    turn.sample(a,0)
    var first:=turn.sample(b,1.0/fps)
    require(first.distance_to(b)>.01,"Every directional change has a visible transition rather than snapping")
    var previous:=first.angle_to(b)
    for frame in int(ceil(.12*fps))+2:
     var actual:=turn.sample(b,1.0/fps)
     require(absf(actual.length()-1)<.00001,"Opposite directions cannot cancel the gait direction")
     require(actual.angle_to(b)<=previous+.0006,"Direction transition follows the short arc without overshoot")
     previous=actual.angle_to(b)
    require(previous<.0006,"Direction transition finishes in 0.12 seconds at every tested frame rate")
  var continuous:=Turn.new();continuous.sample(Vector3.BACK,0)
  for i in fps*2:
   var t:float=i/float(fps);var target:=Vector3(sin(t),0,cos(t));var actual:=continuous.sample(target,1.0/fps)
   require(actual.angle_to(target)<.13,"Continuous camera-relative steering cannot continually restart and freeze the step transition")
 var actor:=Model.new();root.add_child(actor)
 var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/animation_polish_reference.json"))
 for item in reference.pitch:
  actor.family_override=StringName(item.family);actor.action_crouch=item.crouch
  actor.aim_contact=Vector3(0,item.height,28 if item.height==14 else (32 if item.height==30 else 31))
  actor.animate(&"action",.5,true)
  var stance:float=.08*item.crouch
  # The newly reduced axe/pickaxe add a low-contact hinge of their own;
  # verify the shared pitch independently, then retain half that added hinge.
  var hinge:=.18*(1-smoothstep(22,36,item.height)) if item.family in ["axe","pickaxe"] else 0.0
  var shared_basis:Basis=actor.last_pose.body.basis*Basis(Vector3.RIGHT,-hinge)
  require(absf(shared_basis.get_euler().x-(stance+(item.pitch-stance)*.5))<.00001,"Every melee family halves torso inclination while retaining the crouched stance")
  require(actor.last_pose.contact_reachable and actor.tip_socket.position.distance_to(actor.aim_contact)<.03,"More upright strokes still meet the reticle with both hands attached")
 actor.family_override=&"";actor.action_crouch=0;actor.aim_contact=Vector3.INF
 for item in reference.hip:
  var pose:=Clips.sample(&"",StringName(item.state),item.phase,item.phase,Vector3.BACK)
  var x:float=(pose.pelvis*Vector3(0,31,0)).x
  require(absf(x-item.x*.7)<.004,"Hip sway is reduced thirty percent throughout running and its transitions")
 actor.animate(&"idle",0,false)
 var neutral:Basis=actor.last_pose.body.basis.inverse()*actor.rig.posed[5].basis;var previous:=neutral
 var excursion:=0.0;var rotation_step:=0.0
 for i in 65:
  actor.animate(&"action",i/64.0,false)
  var current:Basis=actor.last_pose.body.basis.inverse()*actor.rig.posed[5].basis
  excursion=maxf(excursion,neutral.get_rotation_quaternion().angle_to(current.get_rotation_quaternion()))
  rotation_step=maxf(rotation_step,previous.get_rotation_quaternion().angle_to(current.get_rotation_quaternion()));previous=current
 require(excursion<reference.support.excursion*.75,"The supporting forearm rotates substantially less through the punch")
 require(rotation_step<reference.support.step*.5 and rotation_step<.12,"Support-arm entry and recovery are slower and avoid an initial forearm flip")
 var arrays:=actor.AXILLA_SKIN.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var selected:Dictionary={};var edges:Dictionary={}
 for i in vertices.size():
  var p:=vertices[i]
  if absf(p.x)>4 and absf(p.x)<8 and p.y>40 and p.y<48 and p.z<1.8:selected[i]=true
 for i in range(0,indices.size(),3):
  for side in 3:
   var a:int=indices[i+side];var b:int=indices[i+(side+1)%3]
   if not selected.has(a) and not selected.has(b):continue
   if vertices[a].distance_to(vertices[b])<.02:continue
   edges[Vector2i(mini(a,b),maxi(a,b))]=true
 var probes:Dictionary={}
 for edge in edges:probes[edge.x]=true;probes[edge.y]=true
 var maximum_strain:=0.0
 for side in 2:
  actor.punch_side=side
  for frame in 65:
   actor.animate(&"action",frame/64.0,false)
   var posed:Dictionary={}
   for i in probes:
    var point:=Vector3.ZERO
    for slot in 4:point+=actor.rig.posed[bones[i*4+slot]]*(actor.rig.rest[bones[i*4+slot]].affine_inverse()*vertices[i])*weights[i*4+slot]
    posed[i]=point
   for edge in edges:maximum_strain=maxf(maximum_strain,posed[edge.x].distance_to(posed[edge.y])/vertices[edge.x].distance_to(vertices[edge.y]))
 require(maximum_strain<3.6,"Real axillary skin remains below the new strain bound, versus 8.25 before this fix")
 print("Axillary worst edge ratio ",maximum_strain,"; support rotation excursion ",excursion,"; maximum frame rotation ",rotation_step)
 var maximum_drop:=0.0
 actor.family_override=&"sword"
 for i in 65:
  actor.animate(&"action",i/64.0,true)
  var p:Dictionary=actor.last_pose;var side:int=p.active
  var normal:=Kinematics.arm(p.shoulders[side],actor.rig.posed[6+side*3].origin,p.body.basis,side,false,0,1)
  var drop:float=(normal.joint-actor.rig.posed[5+side*3].origin).dot(p.body.basis.y)
  require(drop>=-.00001,"Sword elbow lowering never raises the elbow at a fixed grip")
  maximum_drop=maxf(maximum_drop,drop)
 require(maximum_drop>.25,"Sword elbow lowering produces a visible change")
 for family in Clips.FAMILIES:
  actor.family_override=family
  for clip in [&"slide_back_left",&"slide_back_right"]:
   for frame in 17:
    actor.animate(clip,frame/16.0,family!=&"",0,.25)
    require(actor.grip_error<.045,"Both rear diagonal slides retain equipped grips")
    for side in 2:
     var start:=10+side*3
     require(absf(actor.rig.posed[start].origin.distance_to(actor.rig.posed[start+1].origin)-14.5)<.001 and absf(actor.rig.posed[start+1].origin.distance_to(actor.rig.posed[start+2].origin)-14.5)<.001,"Rear diagonals retain fixed thigh and shin lengths")
    var floor_y:=INF
    for i in range(0,vertices.size(),53):
     var point:=Vector3.ZERO
     for slot in 4:point+=actor.rig.posed[bones[i*4+slot]]*(actor.rig.rest[bones[i*4+slot]].affine_inverse()*vertices[i])*weights[i*4+slot]
     floor_y=minf(floor_y,point.y)
    require(floor_y>=-.12,"Diagonal slide keeps the real imported skin above the floor")
   actor.animate(clip,.5,family!=&"",0,.25)
   var feet:Array[Transform3D]=[actor.rig.posed[12],actor.rig.posed[15]]
   actor.animate(&"slide_jump",0,family!=&"")
   for side in 2:
    require(actor.rig.posed[12+side*3].origin.distance_to(feet[side].origin)<.001,"Rear diagonal jump inherits the actual displayed feet")
    require(actor.rig.posed[12+side*3].basis.get_rotation_quaternion().angle_to(feet[side].basis.get_rotation_quaternion())<.001,"Rear diagonal jump preserves ankle orientation at takeoff")
 actor.free();print("%s: %d direction, torso, shoulder, forearm, hips and diagonal slide checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
