extends SceneTree
## Real Blender bake + native rig + fixed contacts + comparison viewer.
var errors:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(value:bool,label:String) -> void:
 checks+=1
 if not value and label not in errors:errors.append(label);push_error(label)
func run() -> void:
 var actor=load("res://scenes/prototype_3d/aren_blender_landing_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false);actor.begin_preview("idle_to_fall")
 var n=actor.native;var previous:Array[Vector3]=[];var seen:=0;var palm_xz:=Vector2.ZERO;var first:=true
 var maximum_step:=0.0;var minimum_knee:=INF;var maximum_knee:=0.0;var minimum_elbow:=180.0
 check(n.parents.size()==66,"native bone count")
 check(actor.PilotClip.get_meta("whole_body_keys").size()==8,"eight authored whole-body keys")
 for frame in 900:
  actor.advance_jump_preview(1.0/120)
  for bone in n.parents.size():check(n.posed[bone].is_finite(),"finite pose")
  var tracked:Array=[n.binding.bone(&"root"),n.legs[0].ids[1],n.legs[1].ids[1],n.arms[0].ids[3],n.arms[1].ids[3]]
  for i in tracked.size():
   var p:Vector3=n.posed[tracked[i]].origin*actor.SCALE
   if previous.size()>i:
    var movement:float=p.distance_to(previous[i]);maximum_step=maxf(maximum_step,movement)
    if actor.preview_stage!="lead":check(movement<.04,"continuous body/knee/hand trajectory "+str(i))
    previous[i]=p
   else:previous.append(p)
  if actor.preview_stage=="fall":check(not actor.landing.palm_planted,"no airborne palm contact")
  if actor.preview_stage=="landing":
   for leg in n.legs:
    var ids:Array=leg.ids
    check(absf(n.posed[ids[0]].origin.distance_to(n.posed[ids[1]].origin)-leg.a)*actor.SCALE<.0001,"native thigh length")
    check(absf(n.posed[ids[1]].origin.distance_to(n.posed[ids[2]].origin)-leg.b)*actor.SCALE<.0001,"native shin length")
   for arm in n.arms:
    var ids:Array=arm.ids
    check(absf(n.posed[ids[1]].origin.distance_to(n.posed[ids[2]].origin)-arm.a)*actor.SCALE<.0001,"native humerus length")
    check(absf(n.posed[ids[2]].origin.distance_to(n.posed[ids[3]].origin)-arm.b)*actor.SCALE<.0001,"native forearm length")
    check(absf(n.posed[ids[3]].basis.get_scale().x/n.rest[ids[3]].basis.get_scale().x-.9)<.0001,"approved hand proportion")
   if frame%4==0:
    for side in 2:
     var low:=INF
     for p in actor.landing.sole_support.world_skin_points(n,side,actor.global_transform):low=minf(low,p.y-actor.floor_y)
     check(low>-.001,"feet do not penetrate floor")
   if actor.landing.palm_planted:
    seen+=1;minimum_knee=minf(minimum_knee,actor.landing.knee_minimum);maximum_knee=maxf(maximum_knee,actor.landing.knee_minimum);minimum_elbow=minf(minimum_elbow,actor.landing.elbow_degrees)
    check(actor.landing.knee_minimum>=.03 and actor.landing.knee_minimum<=.05,"suspended knee 3–5 cm")
    check(not actor.landing.knee_planted,"no knee support")
    var left:Array=n.legs[1].ids
    var direction:Vector3=n.posed[left[1]].origin-n.posed[left[0]].origin
    check(absf(rad_to_deg(atan2(direction.x,direction.z)))<30,"left knee faces forward")
    check(absf(actor.landing.palm_minimum)<.001,"palm skin contact")
    for point in actor.landing.skin_points(actor,true):check(point.y-actor.floor_y>-.002,"finger/thenar clearance")
    check(actor.landing.palm_error<.001,"palm reach")
    check(actor.landing.elbow_degrees>18,"support elbow has flexion")
    var p:Vector3=actor.global_transform*n.posed[n.arms[0].ids[3]].origin
    if first:palm_xz=Vector2(p.x,p.z);first=false
    check(Vector2(p.x,p.z).distance_to(palm_xz)<.001,"palm does not slide")
  if actor.preview_done:break
 check(actor.preview_done and seen>15,"complete clip with sustained contact")
 actor.free()
 var r=load("res://scenes/prototype_3d/aren_authoring_review.tscn").instantiate();root.add_child(r);r.set_process(false)
 check(r.source_index==r.pilot_index,"pilot available in existing viewer")
 r.show_jump_phase(2);var clock:float=r.actors[0].preview_clock
 var pose:Dictionary=r.actors[0].capture_pose();r.compare_pilot()
 check(r.source_index==17,"procedural comparison")
 check(absf(r.actors[0].preview_clock-clock)<.00001 and not r.playing,"comparison preserves time/pause")
 r.compare_pilot()
 var after:Dictionary=r.actors[0].capture_pose()
 for bone in pose.poses.size():check(pose.poses[bone].is_equal_approx(after.poses[bone]),"comparison restores Blender pose")
 for mirror in range(1,4):
  for bone in pose.poses.size():check(r.actors[mirror].native.skeleton.get_bone_pose(bone).is_equal_approx(r.actors[0].native.skeleton.get_bone_pose(bone)),"four camera pose mirrors")
 r.select_source(14)
 check(r.compare_button.visible and not r.compare_button.disabled,"approved locomotion comparison retained")
 check(not r.motion_selector.is_item_disabled(0) and not r.motion_selector.is_item_disabled(1),"approved locomotion selectors retained")
 r.compare_button.pressed.emit()
 check(r.source_index==13,"approved comparison action retained")
 r.free();print("BLENDER PILOT ",checks," checks; maximum tracked step ",maximum_step," knee ",minimum_knee,"..",maximum_knee," support elbow minimum ",minimum_elbow," failures ",errors);quit(0 if errors.is_empty() else 1)
