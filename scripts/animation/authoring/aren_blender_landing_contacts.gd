extends "res://scripts/animation/authoring/aren_kneeling_landing_pose.gd"
## Contacts only: the imported Blender clip owns every whole-body pose.
var locks:Array[Transform3D]=[]
var hand_lock:=Vector3.ZERO
var hand_locked:=false
var right_replanted:=false

func set_posture_reference(_previous:bool) -> void:
 super.set_posture_reference(false)

func begin_contacts(actor:Node3D) -> void:
 configure(actor);contact_position=actor.global_position;locks.clear();hand_locked=false;right_replanted=false
 for leg in actor.native.legs:locks.append(actor.global_transform*actor.native.posed[leg.ids[2]])

func adjust_chain(actor:Node3D,ids:Array,first:int,a:float,b:float,goal:Vector3) -> void:
 var native=actor.native
 var chain:Dictionary={"root":native.posed[ids[first]].origin,"joint":native.posed[ids[first+1]].origin,"end":native.posed[ids[first+2]].origin}
 var axis:Vector3=(chain.end-chain.root).normalized()
 var radial:Vector3=chain.joint-chain.root
 var pole:Vector3=(radial-axis*radial.dot(axis)).normalized()
 var axes:Array=[]
 for segment in 2:axes.append(Frames.segment_frame(chain,segment).inverse()*native.posed[ids[first+segment]].basis)
 var end_basis:Basis=native.posed[ids[first+2]].basis
 var solved:=Solver.joint(chain.root,goal,a,b,pole,150)
 native.orient_chain(ids,first,solved,axes)
 Torso.rotate_branch(native,ids[first+2],end_basis,solved.end)

func apply_contacts(actor:Node3D,seconds:float) -> void:
 time=seconds;palm_planted=time>=.20 and time<=23.0/60;support_loaded=palm_planted;knee_planted=false
 foot_error=0;palm_error=0
 var native=actor.native
 for side in 2:
  var planted:bool=time<=56.0/60 if side==1 else (time<=23.0/60 or time>=56.0/60)
  if not planted:continue
  var leg:Dictionary=native.legs[side]
  if side==0 and time>=56.0/60 and not right_replanted:
   locks[0]=actor.global_transform*native.posed[leg.ids[2]];right_replanted=true
  var goal:Vector3=actor.global_transform.affine_inverse()*locks[side].origin
  # Reuse native IK and actual skinned sole envelopes; preserve the clip's pole/twist.
  for iteration in 2:
   adjust_chain(actor,leg.ids,0,leg.a,leg.b,goal)
   var low:=INF
   for point in sole_support.world_skin_points(native,side,actor.global_transform):low=minf(low,point.y-actor.floor_y)
   if absf(low-.0003)<.0002:break
   goal.y+=(.0003-low)/(actor.global_basis.y.length())
  foot_error=maxf(foot_error,(native.posed[leg.ids[2]].origin-goal).length()*SCALE)
 if palm_planted:
  var arm:Dictionary=native.arms[0];var ids:Array=arm.ids
  if not hand_locked:
   hand_lock=actor.global_transform*native.posed[ids[3]].origin;hand_locked=true
   var low:=INF
   for point in skin_points(actor):low=minf(low,point.y-actor.floor_y)
   hand_lock.y-=low
  var goal:Vector3=actor.global_transform.affine_inverse()*hand_lock
  for iteration in 2:
   adjust_chain(actor,ids,1,arm.a,arm.b,goal)
   var low:=INF
   for point in skin_points(actor):low=minf(low,point.y-actor.floor_y)
   if absf(low)<.00015:break
   goal.y-=low/actor.global_basis.y.length()
  palm_error=native.posed[ids[3]].origin.distance_to(goal)*SCALE
 var arm:Array=native.arms[0].ids
 elbow_degrees=rad_to_deg((native.posed[arm[2]].origin-native.posed[arm[1]].origin).angle_to(native.posed[arm[3]].origin-native.posed[arm[2]].origin))
 palm_minimum=INF
 for point in skin_points(actor):palm_minimum=minf(palm_minimum,point.y-actor.floor_y)
 knee_minimum=knee_gap(actor)
 for side in 2:correct_knee(actor,side)
 write(actor)
