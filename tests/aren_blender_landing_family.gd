extends SceneTree
const Family=preload("res://scripts/animation/authoring/aren_blender_landing_motion.gd")
var errors:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(value:bool,label:String) -> void:
 checks+=1
 if not value and label not in errors:errors.append(label);push_error(label)
func segment_distance(point:Vector3,a:Vector3,b:Vector3) -> float:
 return point.distance_to(a+(b-a)*clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1))
func run() -> void:
 check(not Family.accepts(.55) and not Family.accepts(1.5) and not Family.accepts(8.0),"approved low landings and collapse excluded")
 var actor=load("res://scenes/prototype_3d/aren_blender_landing_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 var last_duration:=0.0
 var maximum_step:=0.0;var minimum_knee:=INF;var maximum_knee:=0.0
 for height in [3.0,3.01,3.5,4.0,4.8,5.5,6.0,6.8,7.5,7.9,7.999]:
  actor.review_height=height;actor.begin_preview("idle_to_fall")
  var p:Dictionary=actor.landing_profile()
  check(p.duration>=last_duration,"recovery grows continuously with impact speed")
  last_duration=p.duration
  var previous:Array[Vector3]=[];var contacts:=0;var frames:=0
  while not actor.preview_done and frames<800:
   actor.advance_jump_preview(1.0/120);frames+=1
   var n=actor.native
   var ids:Array=[n.binding.bone(&"root"),n.legs[0].ids[1],n.legs[1].ids[1],n.arms[0].ids[3],n.arms[1].ids[3]]
   for i in ids.size():
    var point:Vector3=n.posed[ids[i]].origin*actor.SCALE
    check(n.posed[ids[i]].is_finite(),"finite family pose")
    if previous.size()>i:
     var delta:=point.distance_to(previous[i]);maximum_step=maxf(maximum_step,delta)
     if actor.preview_stage!="lead":check(delta<.04,"continuous family trajectory at "+str(height))
     previous[i]=point
    else:previous.append(point)
   if actor.preview_stage!="landing":continue
   check(actor.landing.foot_error<.001,"fixed-length foot IK reaches support")
   if frames%4==0:
    for side in 2:
     var low:=INF
     for point in actor.landing.sole_support.world_skin_points(n,side,actor.global_transform):low=minf(low,point.y-actor.floor_y)
     check(low>-.001,"family sole clearance")
    # Anatomical segment envelope: both wrists stay outside both thigh/shin
    # capsules. Complements skinned palm/finger/floor checks and visual review.
    for arm in n.arms:
     var wrist:Vector3=n.posed[arm.ids[3]].origin*actor.SCALE
     for leg in n.legs:
      for segment in 2:
       var a:Vector3=n.posed[leg.ids[segment]].origin*actor.SCALE
       var b:Vector3=n.posed[leg.ids[segment+1]].origin*actor.SCALE
       check(segment_distance(wrist,a,b)>.055,"hand/leg separation")
   if actor.landing.palm_planted:
    contacts+=1
    var gap:float=actor.landing.knee_minimum
    minimum_knee=minf(minimum_knee,gap);maximum_knee=maxf(maximum_knee,gap)
    check(gap>=.03 and gap<=.05,"family knee remains suspended 3–5 cm at "+str(height))
    check(absf(actor.landing.palm_minimum)<.001 and actor.landing.palm_error<.001,"family palm reaches skin contact")
    for point in actor.landing.skin_points(actor,true):check(point.y-actor.floor_y>-.002,"family finger clearance")
    var left:Array=n.legs[1].ids
    var direction:Vector3=n.posed[left[1]].origin-n.posed[left[0]].origin
    check(absf(rad_to_deg(atan2(direction.x,direction.z)))<30,"family front knee points forward")
  check(actor.preview_done and contacts>15,"complete reception with contact at "+str(height))
 check(is_equal_approx(Family.profile(-sqrt(2*actor.Jump.GRAVITY*3)).duration,1.8),"3 m recovery stays 1.8 seconds")
 actor.free()
 print("BLENDER FAMILY ",checks," checks; maximum step ",maximum_step," knee ",minimum_knee,"..",maximum_knee," failures ",errors)
 quit(0 if errors.is_empty() else 1)
