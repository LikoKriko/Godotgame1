extends SceneTree
## New actions must preserve the published appearance and the visible supports,
## not merely keep the skeleton finite.
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func compare(a:Dictionary,b:Dictionary,label:String):
 require(a.body.is_equal_approx(b.body),label+": body joins the next state")
 require(a.head.is_equal_approx(b.head),label+": head joins the next state")
 for side in 2:
  require(a.legs[side].end.distance_to(b.legs[side].end)<.001,label+": foot contact joins the next state")
  require(a.arms[side].end.distance_to(b.arms[side].end)<.001,label+": fist joins the next state")
func run():
 var actor=load("res://scripts/prototype_3d/young_model.gd").new();root.add_child(actor)
 var mesh:Mesh=actor.mesh_node.mesh
 var seeds:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/first/meshy/rig_seeds.json"))
 for bone in range(2,14):
  var point:Array=seeds[bone].a
  require(actor.rest[bone].origin.distance_to(Vector3(point[0],point[1],point[2]))<.001,"Runtime bind matches the original Meshy heat rig: "+String(seeds[bone].name))
 var arrays:Array=mesh.surface_get_arrays(0)
 require(mesh==load("res://assets/enemies/first/meshy/mossclaw_skin.res"),"Animations share the authoritative imported Meshy asset")
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var probes:Array[int]=[]
 for i in range(0,vertices.size(),maxi(1,vertices.size()/2100)):probes.append(i)
 for state in Motion.STATES:
  for left in [false,true]:
   var previous:Array=[]
   for frame in 33:
    var phase:=frame/32.0;actor.animate(state,phase,left)
    for side in 2:
     var arm:Dictionary=actor.last_pose.arms[side];var leg:Dictionary=actor.last_pose.legs[side]
     require(absf(arm.root.distance_to(arm.joint)-Motion.ARM_A)<.001 and absf(arm.joint.distance_to(arm.end)-Motion.ARM_B)<.001,"Arm bones retain reference lengths in "+String(state))
     require(absf(leg.root.distance_to(leg.joint)-Motion.LEG_A)<.001 and absf(leg.joint.distance_to(leg.end)-Motion.LEG_B)<.001,"Hind legs retain reference lengths in "+String(state))
     require(leg.joint.y>.8 and leg.end.y>1.25,"Short hind legs remain above ground")
    var minimum:=100.0
    for index:int in probes:
     var point:=Vector3.ZERO
     for slot in 4:
      var bone:int=bones[index*4+slot];point+=(actor.posed[bone]*(actor.rest[bone].affine_inverse()*vertices[index]))*weights[index*4+slot]
     minimum=minf(minimum,point.y)
    require(minimum>=-.15,"Visible skin/fur/stone cannot sink below the original ground margin: %s %.2f"%[state,minimum])
    var current:Array=[]
    for transform:Transform3D in actor.posed:
     require(transform.is_finite() and absf(transform.basis.determinant()-1)<.001,"Skeletal frames stay finite without scaling or reflections")
     current.append(transform.basis.get_rotation_quaternion())
    if not previous.is_empty():
     var maximum:=0.0
     for i in current.size():maximum=maxf(maximum,previous[i].angle_to(current[i]))
     require(maximum<.65,"Full limb frames turn continuously in "+String(state))
    previous=current
 require(actor.mesh_node.mesh==mesh,"All fifteen states reuse the supplied Meshy bind mesh")
 for pair in [[&"idle",0.0,&"boxing_rise",0.0],[&"boxing_rise",1.0,&"boxing_guard",0.0],[&"boxing_guard",0.0,&"boxing_lower",0.0],[&"boxing_lower",1.0,&"idle",0.0],[&"idle",0.0,&"rise",0.0],[&"rise",1.0,&"attack",0.0],[&"attack",1.0,&"lower",0.0],[&"lower",1.0,&"idle",0.0],[&"idle",0.0,&"sit_down",0.0],[&"sit_down",1.0,&"sit",0.0],[&"sit",0.0,&"sit_up",0.0],[&"sit_up",1.0,&"idle",0.0],[&"idle",0.0,&"feed",0.0],[&"stun_fall",1.0,&"stun_hold",0.0],[&"stun_hold",0.0,&"stun_rise",0.0],[&"stun_rise",1.0,&"idle",0.0],[&"death",1.0,&"corpse",0.0]]:
  compare(Motion.sample(pair[0],pair[1]),Motion.sample(pair[2],pair[3]),String(pair[0])+" -> "+String(pair[2]))
 for loop in [&"idle",&"walk",&"run",&"sit",&"feed",&"boxing_guard",&"boxing_walk"]:compare(Motion.sample(loop,0),Motion.sample(loop,1),String(loop)+" loop")
 var feed_start:Dictionary=Motion.sample(&"feed",0);var feeding:Dictionary=Motion.sample(&"feed",.20)
 require(feed_start.arms[0].end.distance_to(feeding.arms[0].end)>4,"Feeding now has a real alternating reach, not only a head nod")
 for interrupted in [&"walk",&"attack",&"sit",&"feed",&"hook",&"boxing_guard",&"boxing_walk"]:
  actor.animate(interrupted,.4,true)
  var start:Dictionary=actor.last_pose.duplicate(true)
  actor.animate(&"stun_fall",0,true,.016)
  compare(start,actor.last_pose,String(interrupted)+" interrupted by stun")
  actor.animate(interrupted,.4,true)
  start=actor.last_pose.duplicate(true)
  actor.animate(&"death",0,true,.016)
  compare(start,actor.last_pose,String(interrupted)+" interrupted by death")
 actor.animate(&"corpse",1);var still:Array=actor.posed.duplicate()
 actor.animate(&"corpse",.3)
 for i in still.size():require(still[i].is_equal_approx(actor.posed[i]),"Corpse remains still after falling")
 actor.free();print("%s: %d reference-preservation, full-skin support, continuity and creature animation checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
