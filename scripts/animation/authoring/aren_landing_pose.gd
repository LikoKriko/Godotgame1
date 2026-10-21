extends RefCounted
## Fixed world contacts, native branch transforms and existing fixed-length IK.
const Motion=preload("res://scripts/animation/authoring/aren_landing_motion.gd")
const Jump=preload("res://scripts/animation/authoring/aren_jump_motion.gd")
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
const Solver=preload("res://scripts/continuous_body_pose.gd")
const Frames=preload("res://scripts/prototype_3d/human_kinematics.gd")
const FootSupport=preload("res://scripts/animation/terrain/terrain_foot_support.gd")
const SCALE=1.75/64.0
var parameters:Dictionary={}
var entry:Dictionary={}
var neutral:Dictionary={}
var feet:Array[Transform3D]=[]
var palm_anchor:=Vector3.ZERO
var palm_normal:=Vector3.UP
var palm_forward:=Vector3.BACK
var palm_basis:=Basis.IDENTITY
var palm_points:PackedVector3Array=[]
var palm_samples:Array[Array]=[]
var hand_samples:Array[Array]=[]
var palm_minimum:=0.0
var finger_bones:Array[int]=[]
var wrist_offset:=Vector3.ZERO
var lowering:=0.0
var active:=false
var palm_planted:=false
var elbow_degrees:=0.0
var palm_error:=0.0
var foot_error:=0.0
var time:=0.0
var support_side:=0
var contact_position:=Vector3.ZERO
var initial_velocity:=Vector3.ZERO
var support_query:=Callable()
var configured:=false
var sole_support=FootSupport.new()
var feet_planes:Array[Plane]=[]
var arm_poles:Array[Vector3]=[]
var arm_axes:Array[Array]=[]
var neutral_arm_poles:Array[Vector3]=[]
var neutral_arm_axes:Array[Array]=[]
var wrist_offsets:Array[Basis]=[]
var neutral_wrist_offsets:Array[Basis]=[]
var release_wrist_offset:=Basis.IDENTITY
var leg_poles:Array[Vector3]=[Vector3.BACK,Vector3(1,.7,.2).normalized()]
var release_wrist_ready:=false
var entry_hand_basis:=Basis.IDENTITY

func configure(actor:Node3D) -> void:
 if configured:return
 var native=actor.native
 var wrist:int=native.arms[support_side].ids[3]
 for bone in native.parents.size():
  var ancestor:int=native.parents[bone]
  while ancestor>=0:
   if ancestor==wrist:finger_bones.append(bone);break
   ancestor=native.parents[ancestor]
 # Palm-only skin points, excluding distal fingers. Work once per actor.
 var owned:Array[int]=finger_bones.duplicate();owned.append(wrist)
 var inverse:Transform3D=native.rest[wrist].affine_inverse()
 for surface in native.mesh.mesh.get_surface_count():
  var arrays:Array=native.mesh.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=ids.size()/vertices.size()
  for vertex in vertices.size():
   var hand_weight:=0.0;var thenar_weight:=0.0;var full_weight:=0.0;var point:=Vector3.ZERO;var record:Array=[]
   for slot in slots:
    var at:int=vertex*slots+slot
    if weights[at]<=0:continue
    var bind:int=ids[at];var bone:int=native.mesh.skin.get_bind_bone(bind)
    if bone==wrist:hand_weight+=weights[at]
    if bone==native.grip.fingers[support_side][4][0]:thenar_weight+=weights[at]
    if bone in owned:full_weight+=weights[at]
    var local:Vector3=native.mesh.skin.get_bind_pose(bind)*vertices[vertex]
    record.append([bone,local*weights[at],weights[at]])
    point+=(native.rest[bone]*local)*weights[at]
   if full_weight>=.75:hand_samples.append(record)
   if hand_weight+thenar_weight>=.75:
    palm_points.append(inverse*point);palm_samples.append(record)
 sole_support.configure(native)
 configured=true

func restore(actor:Node3D,poses:Array) -> void:
 var native=actor.native
 for bone in native.parents.size():
  var parent:int=native.parents[bone]
  native.local_globals[bone]=native.local_globals[parent]*poses[bone] if parent>=0 else poses[bone]
  native.posed[bone]=native.frame*native.local_globals[bone]

func bend(actor:Node3D,load:float,drop:float) -> void:
 var native=actor.native
 var root:int=native.binding.bone(&"root")
 var displacement:Vector3=actor.global_position-contact_position
 displacement.y=0
 var counter:Vector3=actor.global_basis.orthonormalized().inverse()*displacement*(-.8*load)/SCALE
 Torso.rotate_branch(native,root,Basis(Vector3.RIGHT,deg_to_rad(parameters.pelvis_deg)*load)*native.posed[root].basis,native.posed[root].origin-Vector3.UP*drop/SCALE+counter)
 for index in native.spine.size():
  var bone:int=native.spine[index]
  Torso.rotate_branch(native,bone,Basis(Vector3.RIGHT,deg_to_rad(parameters.spine_deg[index])*load)*native.posed[bone].basis,native.posed[bone].origin)
 # A continuous neck counter-rotation retains a forward/downward gaze.
 Torso.rotate_branch(native,native.neck,Basis(Vector3.RIGHT,-deg_to_rad(32)*load)*native.posed[native.neck].basis,native.posed[native.neck].origin)

func prepare(actor:Node3D,ground_gap:float,impact_velocity:float) -> void:
 configure(actor)
 var weight:=Jump.smooth5((1.6-ground_gap)/1.3)
 if weight<=0:return
 var native=actor.native
 var visible:Array=actor.capture_pose().poses
 var rest:Dictionary=actor.sampler.sample("idle",0)
 restore(actor,visible)
 var p:=Motion.profile(impact_velocity)
 var goals:Array[Transform3D]=[]
 var required:=0.0
 for side in 2:
  var leg:Dictionary=native.legs[side]
  var goal:Transform3D=native.frame*rest.feet[side]
  goal.origin.z+=(p.stagger if side==0 else -p.stagger)/SCALE
  if side==1:
   goal.origin.x+=.08/SCALE
   goal.basis=Basis(Vector3.UP,deg_to_rad(25))*goal.basis
  goal=native.posed[leg.ids[2]].interpolate_with(goal,weight)
  goals.append(goal)
  var hip:Vector3=native.posed[leg.ids[0]].origin
  var horizontal:=Vector2(goal.origin.x-hip.x,goal.origin.z-hip.z).length_squared()
  required=maxf(required,hip.y-goal.origin.y-sqrt(maxf(.001,pow(leg.a+leg.b-.04,2)-horizontal)))
 for bone in native.posed.size():native.posed[bone].origin.y-=required
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var goal:Transform3D=goals[side]
  var pole:Vector3=Vector3.BACK.lerp(leg_poles[side],weight).normalized()
  var solved:=Solver.joint(native.posed[ids[0]].origin,goal.origin,leg.a,leg.b,pole,150)
  native.untwisted_chain(ids,0,solved,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],goal.basis,solved.end)
  settle_sole(actor,side,goal,Plane(Vector3.UP,actor.global_position.y),weight,pole)
  correct_knee(actor,side)
 write(actor)

func start(actor:Node3D,height:float,impact_velocity:float,velocity:Vector3=Vector3.ZERO,query:Callable=Callable()) -> void:
 configure(actor)
 parameters=Motion.profile(impact_velocity);entry=actor.capture_pose()
 entry_hand_basis=actor.native.posed[actor.native.arms[support_side].ids[3]].basis
 arm_poles.clear();arm_axes.clear();wrist_offsets.clear()
 for side in 2:
  var reference:=arm_reference(actor,side)
  arm_poles.append(reference.pole);arm_axes.append(reference.axes);wrist_offsets.append(reference.wrist)
 support_query=query
 contact_position=actor.global_position;initial_velocity=Vector3(velocity.x,0,velocity.z)
 feet.clear();feet_planes.clear()
 for leg in actor.native.legs:
  var foot:Transform3D=actor.global_transform*actor.native.posed[leg.ids[2]]
  feet.append(foot)
  var surface:Dictionary=query.call(foot.origin) if query.is_valid() else {}
  feet_planes.append(Plane(surface.normal,surface.normal.dot(surface.position)) if not surface.is_empty() else Plane(Vector3.UP,actor.global_position.y))
 neutral=actor.sampler.sample("idle",0)
 restore(actor,neutral.poses)
 neutral_arm_poles.clear();neutral_arm_axes.clear();neutral_wrist_offsets.clear()
 for side in 2:
  var reference:=arm_reference(actor,side)
  neutral_arm_poles.append(reference.pole);neutral_arm_axes.append(reference.axes);neutral_wrist_offsets.append(reference.wrist)
 bend(actor,1,0)
 var native=actor.native;var arm:Dictionary=native.arms[support_side]
 var shoulder:Vector3=native.posed[arm.ids[1]].origin*SCALE
 var carried:Vector3=initial_velocity*Motion.carry(parameters.absorb,parameters)*.2
 palm_anchor=contact_position+carried+actor.global_basis.orthonormalized()*Vector3(shoulder.x-.015,0,shoulder.z+.075)
 var hit:Dictionary=query.call(palm_anchor) if query.is_valid() else {}
 palm_anchor.y=hit.position.y if not hit.is_empty() else contact_position.y
 palm_normal=hit.normal if not hit.is_empty() else Vector3.UP
 # Fingers lie on the support plane, with the palmar surface facing it.
 var forward:Vector3=actor.global_basis.z.normalized()
 forward=(forward-palm_normal*forward.dot(palm_normal)).normalized()
 palm_forward=actor.global_basis.orthonormalized().inverse()*forward
 var wrist_frame:=Basis(forward.cross(palm_normal).normalized(),-forward,-palm_normal)
 palm_basis=actor.global_basis.orthonormalized().inverse()*wrist_frame*arm.palm*native.rest[arm.ids[3]].basis
 palm_basis=palm_basis.orthonormalized()*Basis.from_scale(native.rest[arm.ids[3]].basis.get_scale()*native.grip.HAND_SCALE)
 var local_normal:Vector3=actor.global_basis.orthonormalized().inverse()*palm_normal
 var low:=INF
 for point in palm_points:low=minf(low,(palm_basis*point).dot(local_normal)*SCALE)
 if not is_finite(low):low=-.015
 wrist_offset=local_normal*low
 var target_wrist:Vector3=actor.global_transform.affine_inverse()*(palm_anchor-carried)-wrist_offset/SCALE
 var flex:=deg_to_rad(parameters.elbow_peak_deg)
 var reach:=sqrt(arm.a*arm.a+arm.b*arm.b+2*arm.a*arm.b*cos(flex))*SCALE
 var horizontal:=Vector2(shoulder.x-target_wrist.x*SCALE,shoulder.z-target_wrist.z*SCALE).length_squared()
 lowering=maxf(.35,shoulder.y-target_wrist.y*SCALE-sqrt(maxf(.001,reach*reach-horizontal)))+.025*parameters.intensity
 active=true;time=0;palm_planted=false;release_wrist_ready=false
 restore(actor,entry.poses);write(actor)

func apply(actor:Node3D,seconds:float,exit:Dictionary={}) -> void:
 time=maxf(0,seconds)
 var native=actor.native
 var amount:=Jump.smooth5(time/parameters.absorb)
 var poses:Array=[]
 for bone in native.parents.size():poses.append(entry.poses[bone].interpolate_with(neutral.poses[bone],amount))
 restore(actor,poses)
 var load:=Motion.load_at(time,parameters)
 bend(actor,load,lowering*load)
 var exit_mix:=Jump.smooth5((time-parameters.rise_end)/(parameters.duration-parameters.rise_end))
 if not exit.is_empty() and exit_mix>0:
  var current:Dictionary=actor.capture_pose();poses.clear()
  for bone in native.parents.size():poses.append(current.poses[bone].interpolate_with(exit.poses[bone],exit_mix))
  restore(actor,poses)
 foot_error=0
 var goals:Array[Transform3D]=[]
 var foot_progress:Array[float]=[]
 var reach_lowering:=0.0
 for side in 2:
  var leg:Dictionary=native.legs[side]
  var goal:Transform3D=actor.global_transform.affine_inverse()*feet[side]
  var progress:=0.0
  if not exit.is_empty():
   var start:float=parameters.rise_end+(.02 if side==0 else -.20)
   progress=clampf((time-start)/.25,0,1)
   goal=goal.interpolate_with(native.frame*exit.feet[side],Jump.smooth5(progress))
   goal.origin.y+=sin(progress*PI)*.055/SCALE
  foot_progress.append(progress)
  goals.append(goal)
  var hip:Vector3=native.posed[leg.ids[0]].origin
  var horizontal:=Vector2(goal.origin.x-hip.x,goal.origin.z-hip.z).length_squared()
  var allowed:float=goal.origin.y+sqrt(maxf(.001,pow(leg.a+leg.b-.04,2)-horizontal))
  reach_lowering=maxf(reach_lowering,hip.y-allowed)
 for bone in native.posed.size():native.posed[bone].origin.y-=reach_lowering
 for side in 2:
  var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
  var goal:Transform3D=goals[side]
  var pole:Vector3=leg_poles[side].lerp(Vector3.BACK,Jump.smooth5(foot_progress[side])).normalized()
  var solved:=Solver.joint(native.posed[ids[0]].origin,goal.origin,leg.a,leg.b,pole,150)
  native.untwisted_chain(ids,0,solved,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],goal.basis,solved.end)
  foot_error=maxf(foot_error,solved.end.distance_to(goal.origin)*SCALE)
  var flex:float=(solved.joint-solved.root).angle_to(solved.end-solved.joint)
  native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cos(flex))*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),flex)))
  settle_sole(actor,side,goal,feet_planes[side],1-Jump.smooth5(foot_progress[side]/.06),pole)
  correct_knee(actor,side)
 solve_free_hand(actor,load)
 solve_hand(actor,load)
 if not exit.is_empty() and exit_mix>0:blend_exit_arms(actor,exit,exit_mix)
 if time>=parameters.duration:
  if not exit.is_empty():restore(actor,exit.poses)
  active=false
 write(actor)

func solve_hand(actor:Node3D,load:float) -> void:
 var native=actor.native;var arm:Dictionary=native.arms[support_side];var ids:Array=arm.ids
 var shoulder:Vector3=native.posed[ids[1]].origin
 var wrist:Transform3D=native.posed[ids[3]]
 var anchor:Vector3=actor.global_transform.affine_inverse()*palm_anchor
 var target_basis:=palm_basis
 var target:=anchor-wrist_offset/SCALE
 # Approach the surface during absorption; the rigid anchor starts at contact.
 var reach_weight:=Jump.smooth5(time/parameters.absorb)
 var release:=Motion.release_at(time,parameters)
 palm_planted=time>=parameters.absorb and time<parameters.release
 var position:Vector3=wrist.origin.lerp(target,reach_weight)
 position=position.lerp(wrist.origin+Vector3(0,.03,.03)/SCALE*load,release)
 var retire:=Jump.smooth5((time-parameters.release_end)/(parameters.rise_end-parameters.release_end))
 var pole:Vector3=arm_poles[support_side].lerp(Vector3(-1,-.12,-.4).normalized(),reach_weight).lerp(neutral_arm_poles[support_side],retire).normalized()
 var solved:=Solver.joint(shoulder,position,arm.a,arm.b,pole,130)
 orient_arm(actor,support_side,solved,reach_weight)
 var entry_hand:Basis=entry_hand_basis
 # Use fixed orientation endpoints during approach, then retire in the forearm frame.
 var basis:Basis=entry_hand.orthonormalized().slerp(target_basis.orthonormalized(),reach_weight)
 if release>0:
  var forearm:Basis=native.posed[ids[2]].basis.orthonormalized()
  if not release_wrist_ready:
   release_wrist_offset=forearm.inverse()*target_basis.orthonormalized();release_wrist_ready=true
  var resting:Basis=native.rest[ids[2]].basis.inverse()*native.rest[ids[3]].basis
  basis=forearm*release_wrist_offset.slerp(resting.orthonormalized(),release)
 basis*=Basis.from_scale(native.rest[ids[3]].basis.get_scale()*native.grip.HAND_SCALE)
 Torso.rotate_branch(native,ids[3],basis,solved.end)
 # Capture locals before changing any parent in the finger hierarchy.
 var finger_locals:Dictionary={}
 for bone in finger_bones:finger_locals[bone]=native.posed[native.parents[bone]].affine_inverse()*native.posed[bone]
 for bone in finger_bones:
  var parent:int=native.parents[bone]
  var current:Transform3D=finger_locals[bone]
  var rest:Transform3D=native.rest[parent].affine_inverse()*native.rest[bone]
  native.posed[bone]=native.posed[parent]*current.interpolate_with(rest,reach_weight*(1-release))
 var thumb:int=native.grip.fingers[support_side][4][0]
 # Abduct the native thumb clear of the palm plane, retaining its socket/lengths.
 var thumb_axis:Vector3=palm_forward
 Torso.rotate_branch(native,thumb,Basis(thumb_axis,deg_to_rad(55)*reach_weight*(1-release))*native.posed[thumb].basis,native.posed[thumb].origin)
 if palm_planted:
  for iteration in 2:
   var gap:=INF
   for point in skin_points(actor):gap=minf(gap,palm_normal.dot(point-palm_anchor))
   if absf(gap)<.00015:break
   position+=actor.global_basis.inverse()*(palm_normal*clampf(-gap,-.015,.015))
   solved=Solver.joint(shoulder,position,arm.a,arm.b,pole,130)
   orient_arm(actor,support_side,solved,reach_weight)
   Torso.rotate_branch(native,ids[3],basis,solved.end)
 palm_minimum=INF
 for point in skin_points(actor):palm_minimum=minf(palm_minimum,palm_normal.dot(point-palm_anchor))
 elbow_degrees=rad_to_deg((solved.joint-solved.root).angle_to(solved.end-solved.joint))
 palm_error=solved.end.distance_to(position)*SCALE if palm_planted else 0.0

func write(actor:Node3D) -> void:
 for bone in actor.native.posed.size():actor.native.local_globals[bone]=actor.native.inverse_frame*actor.native.posed[bone]
 actor.native.writer.apply(actor.native.skeleton,actor.native.local_globals)

func skin_points(actor:Node3D,full:bool=false) -> PackedVector3Array:
 var result:=PackedVector3Array()
 for record in (hand_samples if full else palm_samples):
  var point:=Vector3.ZERO
  for influence in record:
   var pose:Transform3D=actor.native.posed[influence[0]]
   point+=pose.basis*influence[1]+pose.origin*influence[2]
  result.append(actor.global_transform*point)
 return result

func settle_sole(actor:Node3D,side:int,goal:Transform3D,plane:Plane,weight:float,pole:Vector3=Vector3.BACK) -> void:
 if weight<=0:return
 var native=actor.native;var leg:Dictionary=native.legs[side];var ids:Array=leg.ids
 for iteration in 2:
  var gap:=INF
  for point in sole_support.world_skin_points(native,side,actor.global_transform):gap=minf(gap,plane.distance_to(point))
  if absf(gap)<.0002:break
  goal.origin+=actor.global_basis.inverse()*(Vector3.UP*((-gap+.0003)/maxf(plane.normal.y,.1))*weight)
  var solved:=Solver.joint(native.posed[ids[0]].origin,goal.origin,leg.a,leg.b,pole,150)
  native.untwisted_chain(ids,0,solved,Basis.IDENTITY)
  Torso.rotate_branch(native,ids[2],goal.basis,solved.end)

func solve_free_hand(actor:Node3D,load:float) -> void:
 var native=actor.native;var arm:Dictionary=native.arms[1-support_side];var ids:Array=arm.ids
 var root:Vector3=native.posed[ids[1]].origin
 var wrist:Transform3D=native.posed[ids[3]]
 var goal:Vector3=wrist.origin.lerp(root+Vector3(.22+.04*parameters.intensity,.08,.25)/SCALE,load)
 var approach:=Jump.smooth5(time/parameters.absorb)
 var retire:=Jump.smooth5((time-parameters.release_end)/(parameters.rise_end-parameters.release_end))
 var pole:Vector3=arm_poles[1-support_side].lerp(Vector3.RIGHT,approach).lerp(neutral_arm_poles[1-support_side],retire).normalized()
 var solved:=Solver.joint(root,goal,arm.a,arm.b,pole,130)
 orient_arm(actor,1-support_side,solved,approach)
 var original:Basis=wrist_offsets[1-support_side]
 var resting:Basis=native.rest[ids[2]].basis.inverse()*native.rest[ids[3]].basis
 var final:Basis=neutral_wrist_offsets[1-support_side]
 var finish:=Jump.smooth5((time-parameters.rise_end)/(parameters.duration-parameters.rise_end))
 var local:Basis=original.orthonormalized().slerp(resting.orthonormalized(),approach).slerp(final.orthonormalized(),finish)*Basis.from_scale(original.get_scale())
 var basis:Basis=native.posed[ids[2]].basis*local
 Torso.rotate_branch(native,ids[3],basis,solved.end)

func correct_knee(actor:Node3D,side:int) -> void:
 var native=actor.native;var ids:Array=native.legs[side].ids
 var flex:float=(native.posed[ids[1]].origin-native.posed[ids[0]].origin).angle_to(native.posed[ids[2]].origin-native.posed[ids[1]].origin)
 native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cos(flex))*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),flex)))

func orient_arm(actor:Node3D,side:int,solved:Dictionary,weight:float) -> void:
 var axes:Array=[]
 for segment in 2:
  var old:Basis=arm_axes[side][segment]
  var rest:Basis=actor.native.arms[side].axes[segment]
  var neutral_axis:Basis=neutral_arm_axes[side][segment]
  var retire:=Jump.smooth5((time-parameters.release_end)/(parameters.rise_end-parameters.release_end))
  axes.append(old.orthonormalized().slerp(rest.orthonormalized(),weight).slerp(neutral_axis.orthonormalized(),retire)*Basis.from_scale(old.get_scale()))
 actor.native.orient_chain(actor.native.arms[side].ids,1,solved,axes)

func arm_reference(actor:Node3D,side:int) -> Dictionary:
 var ids:Array=actor.native.arms[side].ids
 var root:Vector3=actor.native.posed[ids[1]].origin
 var joint:Vector3=actor.native.posed[ids[2]].origin
 var end:Vector3=actor.native.posed[ids[3]].origin
 var axis:Vector3=(end-root).normalized()
 var radial:=joint-root
 var chain:Dictionary={"root":root,"joint":joint,"end":end}
 return {"wrist":actor.native.posed[ids[2]].basis.inverse()*actor.native.posed[ids[3]].basis,"pole":(radial-axis*radial.dot(axis)).normalized(),"axes":[Frames.segment_frame(chain,0).inverse()*actor.native.posed[ids[1]].basis,Frames.segment_frame(chain,1).inverse()*actor.native.posed[ids[2]].basis]}

func blend_exit_arms(actor:Node3D,exit:Dictionary,weight:float) -> void:
 var current:Dictionary=actor.capture_pose()
 for arm in actor.native.arms:
  for bone in actor.native.binding.branches[arm.ids[0]]:
   var parent:int=actor.native.parents[bone]
   var local:Transform3D=current.poses[bone].interpolate_with(exit.poses[bone],weight)
   actor.native.posed[bone]=actor.native.posed[parent]*local
