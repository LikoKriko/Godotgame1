extends "res://scripts/animation/authoring/aren_landing_pose.gd"
## Authoring-only contact transfer: left sole, right knee and right palm.
var previous_posture:=false
var setting_contact:=false
var knee_anchor:=Vector3.ZERO
var knee_minimum:=0.0
var knee_planted:=false
var knee_samples:Array[Array]=[]
var shin_samples:Array[Array]=[]
var rear_basis:=Basis.IDENTITY
var rear_height:=.08
var knee_ready:=false

func _init() -> void:
 set_posture_reference(false)

func set_posture_reference(previous:bool) -> void:
 previous_posture=previous
 leg_poles=[Vector3.BACK,Vector3(.65 if previous else .37,0,1).normalized()]

static func review_profile(velocity_y:float) -> Dictionary:
 var p:=Motion.profile(velocity_y)
 p.absorb=.34+.06*p.intensity
 p.release=.58+.14*p.intensity
 p.release_end=.86+.20*p.intensity
 p.hold=p.release_end
 return p

func configure(actor:Node3D) -> void:
 super.configure(actor)
 if knee_ready:return
 var native=actor.native
 var leg:Dictionary=native.legs[0]
 var knee:Vector3=native.rest[leg.ids[1]].origin
 for surface in native.mesh.mesh.get_surface_count():
  var arrays:Array=native.mesh.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=ids.size()/vertices.size()
  for vertex in vertices.size():
   var point:=Vector3.ZERO;var record:Array=[];var owned:=0.0
   for slot in slots:
    var at:int=vertex*slots+slot
    if weights[at]<=0:continue
    var bind:int=ids[at];var bone:int=native.mesh.skin.get_bind_bone(bind)
    var local:Vector3=native.mesh.skin.get_bind_pose(bind)*vertices[vertex]
    record.append([bone,local*weights[at],weights[at]])
    point+=(native.rest[bone]*local)*weights[at]
    if bone==leg.ids[0] or bone==leg.ids[1]:owned+=weights[at]
   if owned>.9 and point.y<knee.y+.045/SCALE:shin_samples.append(record)
   if owned>.9 and absf(point.y-knee.y)*SCALE<.045 and point.z>knee.z:knee_samples.append(record)
 knee_ready=true

func preparation_foot(actor:Node3D,rest:Dictionary,_p:Dictionary,side:int) -> Transform3D:
 var goal:Transform3D=actor.native.frame*rest.feet[side]
 goal.origin.x=(-.13 if side==0 else .22)/SCALE
 goal.origin.z=(-.10 if side==0 else .50)/SCALE
 return goal

func start(actor:Node3D,height:float,impact_velocity:float,velocity:Vector3=Vector3.ZERO,query:Callable=Callable()) -> void:
 time=0;setting_contact=true
 super.start(actor,height,impact_velocity,velocity,query)
 setting_contact=false
 parameters=review_profile(impact_velocity)
 knee_anchor=contact_position+actor.global_basis.orthonormalized()*Vector3(-.13,.05,.27)
 # Dorsum of the rear foot faces the floor; toes trail behind the knee.
 var foot:Transform3D=actor.native.frame*neutral.feet[0]
 rear_basis=Basis(Vector3.RIGHT,deg_to_rad(135))*foot.basis
 restore(actor,neutral.poses)
 var native=actor.native;var ids:Array=native.legs[0].ids
 var old:Transform3D=native.posed[ids[2]]
 Torso.rotate_branch(native,ids[2],rear_basis,old.origin)
 var low:=INF
 for point in sole_support.world_skin_points(native,0,actor.global_transform):low=minf(low,point.y-(actor.global_transform*old.origin).y)
 rear_height=-low+.001
 restore(actor,entry.poses);write(actor)

func bend(actor:Node3D,load:float,drop:float) -> void:
 super.bend(actor,load,drop)
 if not previous_posture and not setting_contact:
  # Follow the more central pelvis without moving the planted hand target.
  var spine:int=actor.native.spine[0]
  var correction:=deg_to_rad(4)*load
  Torso.rotate_branch(actor.native,spine,Basis(Vector3.RIGHT,correction)*actor.native.posed[spine].basis,actor.native.posed[spine].origin)
  Torso.rotate_branch(actor.native,actor.native.neck,Basis(Vector3.RIGHT,-correction)*actor.native.posed[actor.native.neck].basis,actor.native.posed[actor.native.neck].origin)
 var settle:=Jump.smooth5((time-parameters.absorb)/(parameters.release-parameters.absorb))*load
 var chest:int=actor.native.spine[1]
 Torso.rotate_branch(actor.native,chest,Basis(Vector3.RIGHT,deg_to_rad(6)*settle)*actor.native.posed[chest].basis,actor.native.posed[chest].origin)
 # Move the pelvis into the space between the asymmetric supports.
 var balance:=Jump.smooth5((time-parameters.absorb)/(parameters.release_end-parameters.absorb))
 var shift:Vector3=(Vector3(-.025,0,-.025-.025*balance) if previous_posture else Vector3(-.025,.005,.030+.005*balance))*load/SCALE
 for bone in actor.native.posed.size():actor.native.posed[bone].origin+=shift

func solve_legs(actor:Node3D,exit:Dictionary) -> void:
 var native=actor.native
 var approach:=Jump.smooth5(time/parameters.absorb)
 var rise:=Jump.smooth5((time-parameters.release_end)/(parameters.rise_end-parameters.release_end))
 var kneel:=approach*(1-rise)
 knee_planted=time>=parameters.absorb and time<=parameters.release_end
 foot_error=0
 var left:Dictionary=native.legs[1]
 var left_goal:Transform3D=actor.global_transform.affine_inverse()*feet[1]
 var left_step:=Jump.smooth5((time-(parameters.rise_end-.03))/.25)
 if not exit.is_empty():
  left_goal=left_goal.interpolate_with(native.frame*exit.feet[1],left_step)
  left_goal.origin.y+=sin(left_step*PI)*.055/SCALE
 var right:Dictionary=native.legs[0];var ids:Array=right.ids
 var target_knee:Vector3=actor.global_transform.affine_inverse()*knee_anchor
 # Hip projection onto the thigh sphere gives the knee an exact support,
 # rather than forcing a foot target while translating the torso through it.
 var hip:Vector3=native.posed[ids[0]].origin
 var corrected:Vector3=supported_hip(hip,target_knee,right)
 var shift:Vector3=(corrected-hip)*kneel
 for bone in native.posed.size():native.posed[bone].origin+=shift
 var dy:float=(rear_height-(knee_anchor.y-contact_position.y))/SCALE
 var rear:Vector3=target_knee+Vector3(0,dy,-sqrt(maxf(.001,right.b*right.b-dy*dy)))
 var initial:Transform3D=actor.global_transform.affine_inverse()*feet[0]
 var goal:=initial.interpolate_with(Transform3D(rear_basis,rear),approach)
 goal.origin.y+=sin(approach*PI)*.16/SCALE
 if not exit.is_empty():
  goal=goal.interpolate_with(native.frame*exit.feet[0],rise)
  goal.origin.y+=sin(rise*PI)*.10/SCALE
 # Retain reach while the left foot is still forward during the rise.
 var lower:=0.0
 for pair in [[left,left_goal],[right,goal]]:
  var leg:Dictionary=pair[0];var foot:Transform3D=pair[1]
  var socket:Vector3=native.posed[leg.ids[0]].origin
  var horizontal:=Vector2(foot.origin.x-socket.x,foot.origin.z-socket.z).length_squared()
  lower=maxf(lower,socket.y-foot.origin.y-sqrt(maxf(.001,pow(leg.a+leg.b-.04,2)-horizontal)))
 for bone in native.posed.size():native.posed[bone].origin.y-=lower
 solve_right(actor,goal,target_knee)
 # The swinging rear foot must clear the plane even while it turns plantarward.
 if not knee_planted:
  var low:=INF
  for point in sole_support.world_skin_points(native,0,actor.global_transform):low=minf(low,point.y-contact_position.y)
  if low<.0003:
   goal.origin.y+=(.0003-low)/SCALE
   solve_right(actor,goal,target_knee)
 solve_left(actor,left_goal,left_step)
 if knee_planted:
  # Skin contact, not the bone pivot: keep a fixed knee anchor throughout load.
  for iteration in 3:
   knee_minimum=knee_gap(actor)
   if absf(knee_minimum)<.0002:break
   knee_anchor.y-=knee_minimum
   target_knee=actor.global_transform.affine_inverse()*knee_anchor
   hip=native.posed[ids[0]].origin
   corrected=supported_hip(hip,target_knee,right)
   shift=corrected-hip
   for bone in native.posed.size():native.posed[bone].origin+=shift
   dy=(rear_height-(knee_anchor.y-contact_position.y))/SCALE
   rear=target_knee+Vector3(0,dy,-sqrt(maxf(.001,right.b*right.b-dy*dy)))
   goal=Transform3D(rear_basis,rear)
   solve_right(actor,goal,target_knee)
   solve_left(actor,left_goal,left_step)
 knee_minimum=knee_gap(actor)

func supported_hip(hip:Vector3,knee:Vector3,leg:Dictionary) -> Vector3:
 var dy:float=(rear_height-(knee_anchor.y-contact_position.y))/SCALE
 var shin:=Vector3(0,dy,-sqrt(maxf(.001,leg.b*leg.b-dy*dy))).normalized()
 var direction:Vector3=(hip-knee).normalized()
 var cosine:=cos(deg_to_rad(30.5))
 if direction.dot(shin)>cosine:
  var radial:Vector3=(direction-shin*direction.dot(shin)).normalized()
  direction=shin*cosine+radial*sin(deg_to_rad(30.5))
 return knee+direction*leg.a

func solve_right(actor:Node3D,goal:Transform3D,knee:Vector3) -> void:
 var native=actor.native;var leg:Dictionary=native.legs[0];var ids:Array=leg.ids
 var hip:Vector3=native.posed[ids[0]].origin
 # The native-length solver does not impose a knee angle; enforce its reach
 # after clearance corrections too, including the rear-foot lift.
 if not knee_planted:
  var minimum:=sqrt(leg.a*leg.a+leg.b*leg.b+2*leg.a*leg.b*cos(deg_to_rad(149.5)))
  if hip.distance_to(goal.origin)<minimum:
   var shift:Vector3=goal.origin+(hip-goal.origin).normalized()*minimum-hip
   for bone in native.posed.size():native.posed[bone].origin+=shift
   hip+=shift
 var retire:=Jump.smooth5((time-parameters.release_end)/(parameters.rise_end-parameters.release_end))
 var pole:Vector3=(knee-hip).normalized().lerp(Vector3.BACK,retire).normalized()
 var solved:=Solver.joint(hip,goal.origin,leg.a,leg.b,pole,150)
 native.untwisted_chain(ids,0,solved,Basis.IDENTITY)
 Torso.rotate_branch(native,ids[2],goal.basis,solved.end)
 foot_error=maxf(foot_error,solved.end.distance_to(goal.origin)*SCALE)
 correct_knee(actor,0)

func solve_left(actor:Node3D,goal:Transform3D,step:float) -> void:
 var native=actor.native;var leg:Dictionary=native.legs[1];var ids:Array=leg.ids
 var pole:Vector3=leg_poles[1].lerp(Vector3.BACK,step).normalized()
 var solved:=Solver.joint(native.posed[ids[0]].origin,goal.origin,leg.a,leg.b,pole,150)
 native.untwisted_chain(ids,0,solved,Basis.IDENTITY)
 Torso.rotate_branch(native,ids[2],goal.basis,solved.end)
 settle_sole(actor,1,goal,feet_planes[1],1-step,pole)
 foot_error=maxf(foot_error,solved.end.distance_to(goal.origin)*SCALE)
 correct_knee(actor,1)

func knee_gap(actor:Node3D,include_shin:bool=false) -> float:
 var low:=INF
 for record in (shin_samples if include_shin else knee_samples):
  var point:=Vector3.ZERO
  for influence in record:
   var pose:Transform3D=actor.native.posed[influence[0]]
   point+=pose.basis*influence[1]+pose.origin*influence[2]
  low=minf(low,(actor.global_transform*point).y-contact_position.y)
 return low
