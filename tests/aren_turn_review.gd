extends SceneTree
## Exercise the comparison component only; playable approval remains separate.
var failures:Array[String]=[]
var checks:=0
var maximum_slide:=0.0
var maximum_twist:=0.0
var pose_cost:=Vector2.ZERO
var sampled_frames:=0
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 checks+=1
 if not value and message not in failures:failures.append(message);push_error(message)
func run() -> void:
 var review=load("res://scenes/prototype_3d/aren_turn_review.tscn").instantiate()
 root.add_child(review);review.set_physics_process(false)
 var actor=review.actors[1]
 var case_index:=0
 for style in ["normal","cautious","tired"]:
  for running in [false,true]:
   for angle in [45.0,90.0,180.0]:
    review.state=style;review.running=running;review.turn_angle=angle
    review.gradual=case_index%2==0;review.moving_camera=case_index%3!=0;review.irregular=case_index%2==1
    review.restart()
    var previous:Array[Dictionary]=[]
    for frame in 270:
     await physics_frame
     var heading:float=actor.rotation.y
     review.advance_review(1.0/30)
     pose_cost+=Vector2(review.drivers[0].pose_ms,review.drivers[1].pose_ms);sampled_frames+=1
     check(is_finite(actor.measured_speed) and actor.measured_speed<actor.speed_for("run")*1.15,"Physical speed exceeded approved envelope")
     check(absf(wrapf(actor.rotation.y-heading,-PI,PI))<=deg_to_rad(180)/30+.0001,"Body rotated too far in one tick")
     for side in actor.terrain_contacts.size():
      var contact:Dictionary=actor.terrain_contacts[side]
      if previous.size()>side and contact.planted and previous[side].planted and contact.anchor.is_equal_approx(previous[side].anchor):
       var id:int=actor.native.legs[side].ids[2]
       var actual:Transform3D=actor.global_transform*actor.native.posed[id]
       var slide:=Vector2(actual.origin.x-contact.anchor.x,actual.origin.z-contact.anchor.z).length()
       var basis:Basis=actual.basis.orthonormalized()
       var twist:float=basis.get_rotation_quaternion().angle_to(contact.basis.orthonormalized().get_rotation_quaternion())
       maximum_slide=maxf(maximum_slide,slide);maximum_twist=maxf(maximum_twist,twist)
       check(slide<.006,"Planted foot slid horizontally")
       check(twist<deg_to_rad(2),"Planted foot rotated")
     previous.clear()
     for contact in actor.terrain_contacts:previous.append(contact.duplicate())
    check(actor.measured_speed<.03,"Release did not stop locomotion")
    print("PASS turn review ",style," run=",running," angle=",angle," irregular=",review.irregular," camera=",review.moving_camera," smooth=",review.gradual)
    case_index+=1
 print("Turn viewer: ",checks," checks; failures ",failures.size(),"; planted XZ drift ",maximum_slide*1000," mm; rotation ",rad_to_deg(maximum_twist)," deg; average pose ms before/after ",pose_cost/maxi(1,sampled_frames))
 review.free();quit(0 if failures.is_empty() else 1)
