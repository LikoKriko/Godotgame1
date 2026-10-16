extends SceneTree
## Check the authored strokes on the real imported actor, including held meshes.
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Profile=preload("res://scripts/prototype_3d/meshy_body_profile.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var mesh:Mesh=actor.mesh_node.mesh
 for family in [&"axe",&"pickaxe",&"sword"]:
  actor.family_override=family
  for crouch in [0.0,1.0]:
   actor.action_crouch=crouch
   for contact:Vector3 in [Vector3(0,14,28),Vector3(0,30,32),Vector3(0,42,31)]:
    actor.aim_contact=contact;var previous:=Vector3.INF
    for frame in 65:
     var t:=frame/64.0;actor.animate(&"action",t,family==&"axe")
     require(actor.grip_error<.045,"Both palms retain their actual category grips")
     require(actor.grip_socket.basis.determinant()>.999,"A continuous tool frame retains handedness")
     if previous.is_finite():require(actor.grip_socket.position.distance_to(previous)<4.5,"A stroke cannot jump between load, contact and recovery")
     previous=actor.grip_socket.position
     if frame==32:
      require(actor.last_pose.contact_reachable,"The directed stroke reaches the selected surface")
      require(actor.tip_socket.position.distance_to(contact)<.03,"The physical edge/point meets the reticle exactly at impact")
     # The shaft/blade centre must clear the actual torso envelope. Tool meshes
     # retain their authored thickness; arm/armor volume has a separate suite.
     for step in 12:
      var span:Vector2=preload("res://scripts/prototype_3d/held_profiles.gd").profile(family).get("shaft_range",Vector2(-4,29))
      var point:Vector3=actor.grip_socket.transform*Vector3(0,lerpf(span.x,span.y,step/11.0),0)
      var local:Vector3=actor.last_pose.body.affine_inverse()*point
      var skull_local:Vector3=actor.rig.posed[3].affine_inverse()*point-Vector3(0,.5,2.2)
      var skull_radius:=Vector3(skull_local.x/5.1,skull_local.y/6.2,skull_local.z/6.2).length()
      require(skull_radius>1,"The shaft/blade cannot pass through the skull: %s %.3f"%[family,t])
      if local.y>31 and local.y<51:
       var section:Vector4=Profile.section(local.y)
       var radius:=Vector2(local.x/section.y,(local.z-(section.z+section.w)*.5)/((section.w-section.z)*.5)).length()
       require(radius>1.0,"Shaft/blade stays outside the rib cage: %s %.3f"%[family,t])
    actor.animate(&"action",1,family==&"axe");var end:Transform3D=actor.grip_socket.transform
    actor.animate(&"idle",0,family==&"axe")
    # Compare in the body frame so crouched attacks may recover into crouch.
    if crouch==0:require(end.is_equal_approx(actor.grip_socket.transform),"The stroke recovers into its ordinary guard")
 actor.family_override=&"bow";actor.action_crouch=0;actor.nock_visible=true
 for contact:Vector3 in [Vector3(0,0,45),Vector3(-8,12,70),Vector3(0,55,800)]:
  actor.aim_contact=contact;actor.animate(&"draw",1,true)
  var skull:=Basis.IDENTITY.slerp(actor.last_pose.body.basis,.2)
  var anchor:Vector3=actor.last_pose.body*Anatomy.HEAD_ANCHOR+skull*Vector3(4.8,.8,4.0)
  require(actor.rig.posed[9].origin.distance_to(anchor)<.03,"The drawing palm anchors beside the real cheek")
  var bow_arm_angle:=rad_to_deg((actor.rig.posed[4].origin-actor.rig.posed[5].origin).angle_to(actor.rig.posed[6].origin-actor.rig.posed[5].origin))
  require(bow_arm_angle>120 and bow_arm_angle<175,"The bow arm extends without locking its elbow")
  var grip:Transform3D=actor.grip_socket.transform;var hand:Vector3=actor.rig.posed[9].origin
  actor.animate(&"bow_release",0,true)
  require(grip.is_equal_approx(actor.grip_socket.transform) and hand.distance_to(actor.rig.posed[9].origin)<.03,"Release begins at the displayed full draw")
  var bow=actor.held_props[&"bow"]
  require(not bow.nocked.visible,"Follow-through cannot display a second nocked arrow")
  actor.animate(&"bow_release",1,true);var settled:Transform3D=actor.grip_socket.transform
  actor.animate(&"idle",0,true)
  require(settled.is_equal_approx(actor.grip_socket.transform),"Follow-through lowers back to the ready hold")
 require(actor.mesh_node.mesh==mesh,"The four gestures preserve the shared imported geometry")
 actor.free();print("%s: %d weapon stroke, support, reticle, torso clearance, bow anchor and follow-through checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
