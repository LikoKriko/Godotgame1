extends "res://scripts/animation/authoring/aren_fall_actor.gd"
## Review-only, imported whole-body animation. No gameplay or health replacement.
const ExtremeClip=preload("res://assets/characters/prototype_3d/generated/aren_extreme_blender_v1/extreme.res")
const Sample=preload("res://scripts/animation/authoring/aren_cycle_sampler.gd")
const Contacts=preload("res://scripts/animation/authoring/aren_blender_landing_contacts.gd")
const TILT=33.0/60
const IMPACT=77.0/60
const PRONE=108.0/60
const GETUP=144.0/60
var END:float=ExtremeClip.length
var extreme_sampler=Sample.new()
var contact_writer=Contacts.new()
var outcome:="survive" # Explicit preview of an external post-damage result.
var phase_index:=0
var impact_events:=0
var tilt_fraction:=-1.0
var clip_time:=0.0
var phase_clock:=0.0
var controls_locked:=true
var preview_body:CharacterBody3D
var preview_floor:StaticBody3D
var vertical_speed:=0.0
var skin_local:=PackedVector3Array()
var skin_bones:=PackedInt32Array()
var skin_weights:=PackedFloat32Array()
var skin_offsets:=PackedInt32Array()
var ground_lift:=0.0
var palm_locks:Dictionary={}
var getup_contacts:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/prototype_3d/generated/aren_extreme_blender_v1/timing.json")).get("getup_contacts",{})
var foot_locks:Dictionary={}
var hand_vertices:Array[PackedInt32Array]=[PackedInt32Array(),PackedInt32Array()]
func _ready() -> void:
 super._ready()
 review_height=8
 contact_writer.configure(self)
 extreme_sampler.configure(library,native.skeleton)
 extreme_sampler.clips.extreme=ExtremeClip
 var bindings:Array=[]
 for track in ExtremeClip.get_track_count():bindings.append(native.skeleton.find_bone(str(ExtremeClip.track_get_path(track).get_subname(0))))
 extreme_sampler.tracks.extreme=bindings
 preview_floor=StaticBody3D.new();get_parent().add_child(preview_floor)
 var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100);floor_shape.shape=box;floor_shape.position.y=-.1;preview_floor.add_child(floor_shape)
 preview_body=CharacterBody3D.new();get_parent().add_child(preview_body)
 var collision:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.12;collision.shape=sphere;collision.position.y=.12;preview_body.add_child(collision)
 # Packed visible-skin envelope, including the approved composite head.
 for surface in native.mesh.mesh.get_surface_count():
  var arrays:Array=native.mesh.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=bones.size()/vertices.size()
  for vertex in range(0,vertices.size(),4):
   var point_index:int=skin_offsets.size()
   var owned:Vector2=Vector2.ZERO
   skin_offsets.append(skin_bones.size())
   for slot in slots:
    var at:=vertex*slots+slot
    if weights[at]<=0:continue
    var bone:int=native.mesh.skin.get_bind_bone(bones[at])
    for side in 2:
     var ancestor:=bone
     while ancestor>=0:
      if ancestor==native.arms[side].ids[3]:owned[side]+=weights[at];break
      ancestor=native.parents[ancestor]
    skin_bones.append(bone)
    skin_local.append(native.mesh.skin.get_bind_pose(bones[at])*vertices[vertex]*weights[at]);skin_weights.append(weights[at])
   for side in 2:
    if owned[side]>.9:hand_vertices[side].append(point_index)
 skin_offsets.append(skin_bones.size())
func _exit_tree() -> void:
 if is_instance_valid(preview_body):preview_body.queue_free()
 if is_instance_valid(preview_floor):preview_floor.queue_free()
func begin_preview(_name:String) -> void:
 assert(review_height>=8)
 preview_name="idle_to_fall";segment_name=preview_name;preview_clock=0;preview_done=false
 preview_stage="fall";stage_time=0;fall_time=0;phase_clock=0;phase_index=0
 palm_locks.clear();foot_locks.clear()
 drop_height=review_height;floor_y=0;vertical_speed=0;impact_events=0;tilt_fraction=-1;controls_locked=true
 position=Vector3(0,drop_height,0);preview_body.position=position
 reset_motion("idle");airborne_source=capture_pose();apply_extreme(0)
func preview_duration(_name:String="") -> float:
 return Fall.flight_duration(drop_height)+(END-IMPACT if outcome=="survive" else GETUP-IMPACT)
func step_preview(dt:float) -> void:
 if preview_stage=="fall":
  fall_time+=dt;vertical_speed-=Jump.GRAVITY*dt
  var collision:=preview_body.move_and_collide(Vector3(0,vertical_speed*dt,0))
  position=preview_body.position
  var fraction:float=clampf((drop_height-position.y)/drop_height,0,1)
  if fraction>=.19 and tilt_fraction<0:tilt_fraction=fraction
  phase_index=0 if fraction<.19 else 1
  var flight:=sqrt(fraction)
  clip_time=TILT*sqrt(fraction/.19) if fraction<.19 else lerpf(TILT,IMPACT,(flight-sqrt(.19))/(1-sqrt(.19)))
  apply_extreme(clip_time)
  if collision and collision.get_normal().y>.7:
   impact_events+=1;vertical_speed=0;preview_stage="impact";phase_clock=0;phase_index=2;apply_extreme(IMPACT)
 elif preview_stage=="impact":
  phase_clock+=dt;clip_time=minf(IMPACT+phase_clock,PRONE);apply_extreme(clip_time)
  if clip_time>=PRONE-.000001:preview_stage="prone";phase_index=3;phase_clock=0
 elif preview_stage=="prone":
  phase_clock+=dt;apply_extreme(PRONE)
  if phase_clock>=GETUP-PRONE:
   if outcome=="survive":preview_stage="getup";phase_index=4;phase_clock=0
   else:preview_done=true # Keep the prone pose and controls locked indefinitely.
 elif preview_stage=="getup":
  phase_clock+=dt;clip_time=minf(GETUP+phase_clock,END);apply_extreme(clip_time)
  if clip_time>=END-.000001:controls_locked=false;preview_done=true;preview_stage="idle"
 jump_state={"phase":phase_index,"height":drop_height-position.y,"vertical_velocity":vertical_speed,"grounded":preview_stage not in ["lead","fall"]}
func skin_minimum() -> float:
 var lowest:=INF
 for vertex in skin_offsets.size()-1:
  var point:=Vector3.ZERO
  for at in range(skin_offsets[vertex],skin_offsets[vertex+1]):
   var transform:Transform3D=native.posed[skin_bones[at]]
   point+=transform.basis*skin_local[at]+transform.origin*skin_weights[at]
  lowest=minf(lowest,(global_transform*point).y)
 return lowest
func apply_extreme(seconds:float) -> void:
 clip_time=seconds
 var pose:Dictionary=extreme_sampler.sample("extreme",minf(seconds,ExtremeClip.length-.000001))
 var finish:=Jump.smooth5((seconds-(END-.3))/.3)
 if finish>0:
  var idle:Dictionary=sampler.sample("idle",0)
  for bone in pose.poses.size():pose.poses[bone]=pose.poses[bone].interpolate_with(idle.poses[bone],finish)
 contact_writer.restore(self,pose.poses)
 var authored_hands:Array[Vector3]=[]
 for arm in native.arms:authored_hands.append(global_transform*native.posed[arm.ids[3]].origin)
 ground_lift=0
 # Normalize the authored skin envelope to the physical controller base even
 # in flight, so first contact never introduces a corrective root jump.
 if seconds<END:
  ground_lift=maxf(0,.008-(skin_minimum()-global_position.y))*(1-finish)
  for bone in native.posed.size():native.posed[bone].origin.y+=ground_lift/SCALE
 if seconds>=IMPACT-.18 and seconds<END-.3:fit_supports(seconds,authored_hands)
 for side in 2:contact_writer.correct_knee(self,side)
 contact_writer.write(self)

func hand_minimum(side:int) -> float:
 var lowest:=INF
 for vertex in hand_vertices[side]:
  var point:=Vector3.ZERO
  for at in range(skin_offsets[vertex],skin_offsets[vertex+1]):
   var transform:Transform3D=native.posed[skin_bones[at]]
   point+=transform.basis*skin_local[at]+transform.origin*skin_weights[at]
  lowest=minf(lowest,(global_transform*point).y)
 return lowest
func fit_supports(seconds:float,authored_hands:Array[Vector3]) -> void:
 # Blender owns body coordination. Fit only the current authored support goals.
 var elapsed:=seconds-GETUP
 var release_window:Array=getup_contacts.palm_release
 var release:float=Jump.smooth5((elapsed-release_window[0])/(release_window[1]-release_window[0]))
 for side in 2:
  var arm:Dictionary=native.arms[side]
  var goal:Vector3=global_transform.affine_inverse()*authored_hands[side]
  var planted:bool=elapsed>=float(getup_contacts.palms[side]) and elapsed<=float(release_window[1])
  if planted:
   if not palm_locks.has(side):palm_locks[side]=authored_hands[side]
   goal=(global_transform.affine_inverse()*palm_locks[side]).lerp(native.posed[arm.ids[3]].origin,release)
  # Keep the approved brace/prone/placement arcs; counter the geometric lift.
  if elapsed<0 or planted or elapsed<float(getup_contacts.palms[side]):
   for iteration in 3:
    contact_writer.adjust_chain(self,arm.ids,1,arm.a,arm.b,goal)
    var low:=hand_minimum(side)
    if (absf(low-.008)<.0003 if planted else low>=.0078):break
    goal.y+=(.008-low)*(1-release)/SCALE
   if planted:palm_locks[side]=global_transform*native.posed[arm.ids[3]].origin
 for side in 2:
  var swing:Array=getup_contacts.foot_swings[side]
  var planted:bool=elapsed>=float(getup_contacts.feet[side]) and (elapsed<float(swing[0]) or elapsed>=float(swing[1]))
  if not planted:foot_locks.erase(side);continue
  var leg:Dictionary=native.legs[side]
  if not foot_locks.has(side):foot_locks[side]=global_transform*native.posed[leg.ids[2]].origin
  var goal:Vector3=global_transform.affine_inverse()*foot_locks[side]
  for iteration in 3:
   contact_writer.adjust_chain(self,leg.ids,0,leg.a,leg.b,goal)
   var low:=INF
   for point in contact_writer.sole_support.world_skin_points(native,side,global_transform):low=minf(low,point.y)
   if absf(low-.008)<.0003:break
   goal.y+=(.008-low)/SCALE
