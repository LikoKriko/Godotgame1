extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor);actor.family_override=&""
 for side in 2:
  actor.punch_side=side
  var sign_side:float=-1 if side==0 else 1
  for crouch in [0.0,1.0]:
   actor.action_crouch=crouch
   for movement:Vector3 in [Vector3.ZERO,Vector3.BACK]:
    for contact:Vector3 in [Vector3.INF,Vector3(sign_side*6,40,18),Vector3(sign_side*5,32,15)]:
     actor.aim_contact=contact
     var previous:Array=[]
     for frame in 65:
      var t:=frame/64.0;actor.animate(&"action",t,false,0,.2,movement)
      var pose:Dictionary=actor.last_pose
      var free:=1-side
      var rest:=Clips.relaxed_arm(pose,free)
      var local_rest:Vector3=pose.body.affine_inverse()*rest.end
      var hand:Vector3=pose.body.affine_inverse()*actor.rig.posed[6+free*3].origin
      var weight:=smoothstep(0,.22,t)*(1-smoothstep(.72,1,t))
      require(absf(hand.y-(local_rest.y+(38-local_rest.y)*.2*weight))<.02,"Support-hand elevation is half of the previous forty-percent lift")
      for arm in 2:
       var start:=4+arm*3
       require(absf(actor.rig.posed[start].origin.distance_to(actor.rig.posed[start+1].origin)-10)<.001,"Jab preserves upper arm length")
       require(absf(actor.rig.posed[start+1].origin.distance_to(actor.rig.posed[start+2].origin)-9)<.001,"Jab preserves forearm length")
      if not previous.is_empty():
       for bone in range(4,10):
        require(actor.rig.posed[bone].origin.distance_to(previous[bone].origin)<2.0,"Both arms move continuously through jab and recoil")
        require(actor.rig.posed[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(previous[bone].basis.orthonormalized().get_rotation_quaternion())<.8,"Jab does not flip an elbow or wrist")
      previous=actor.rig.posed.duplicate()
     actor.animate(&"action",.5,false,0,.2,movement)
     if contact.is_finite() and actor.last_pose.get("contact_reachable",false):require(actor.rig.posed[6+side*3].origin.distance_to(contact)<.03,"Jab still reaches the chosen reticle contact at impact")
  actor.action_crouch=0;actor.aim_contact=Vector3.INF
  actor.animate(&"action",.5,false)
  var shoulder:Vector3=actor.rig.posed[4+side*3].origin;var wrist:Vector3=actor.rig.posed[6+side*3].origin
  require(shoulder.distance_to(wrist)>18.5,"Jab extends almost fully with a soft elbow")
  var elbow_local:Vector3=actor.last_pose.body.affine_inverse()*actor.rig.posed[5+side*3].origin
  require(elbow_local.y<48 and absf(elbow_local.x-sign_side*6.2)<1.5,"Striking elbow stays under and behind the fist rather than flaring sideways")
  var outward:=Clips.sample(&"",&"action",.39,0,Vector3.ZERO,Vector3.INF,{},0,side)
  var retreat:=Clips.sample(&"",&"action",.61,0,Vector3.ZERO,Vector3.INF,{},0,side)
  require((outward.body.affine_inverse()*outward.hands[side]).distance_to(retreat.body.affine_inverse()*retreat.hands[side])<.001,"Jab retracts on the same straight line used to extend")
 actor.free();print("%s: %d support lift, straight jab, contact, anatomy and continuity checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
