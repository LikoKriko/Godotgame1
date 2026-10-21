extends SceneTree
## Real sandbox stairs, approached from every side; physics rays are the oracle.
var failures:Array[String]=[]
var checks:=0
var maximum_surface_error:=0.0
var maximum_skin_error:=0.0
var maximum_slide:=0.0
var surface_checks:=0
var maximum_length_error:=0.0
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 checks+=1
 if not value and message not in failures:failures.append(message);push_error(message)
func check_skin(actor:Node3D) -> void:
 var support=actor.foot_support
 # Moving/rotating the actor must move the same articulated skin envelope as
 # the mesh, even though its imported, quantized weights do not sum to one.
 var frame:=Transform3D(Basis(Vector3.UP,1.37).scaled(Vector3.ONE*(1.75/64)),Vector3(19,.2,-12))
 for side in 2:
  var world:PackedVector3Array=support.world_skin_points(actor.native,side,frame)
  for vertex in support.skin_samples[side].size():
   var local:=Vector3.ZERO
   for influence in support.skin_samples[side][vertex]:
    var pose:Transform3D=actor.native.posed[influence[0]]
    local+=pose.basis*influence[1]+pose.origin*influence[2]
   var error:float=world[vertex].distance_to(frame*local)
   maximum_skin_error=maxf(maximum_skin_error,error)
   check(error<.000001,"Sole envelope moved relative to the rendered skin")
func check_surface(scene:Node3D) -> void:
 var actor=scene.actor;var support=actor.foot_support
 for side in 2:
  # Include a slightly buried pose, so a missed step cannot hide behind a
  # foot that the previous IK iteration has already lifted out of contact.
  var frame:Transform3D=actor.global_transform.translated(Vector3.DOWN*.008)
  if not support.may_penetrate(actor.native,side,frame,scene.body.get_world_3d().direct_space_state):continue
  if not support.boxes_valid:continue
  var fast:float=support.boxes_lift(actor.native,side,frame)
  var reference:=0.0
  for point in support.skinned_points(actor.native,side):
   var world:Vector3=frame*point
   var hit:Dictionary=actor.probe(world)
   if not hit.is_empty():reference=maxf(reference,hit.position.y+.003-world.y)
  maximum_surface_error=maxf(maximum_surface_error,absf(fast-reference));surface_checks+=1
  check(fast>=reference-.0001,"Cached boxes missed the actual supporting step")
  check(absf(fast-reference)<.004,"Cached boxes selected a different stair level")
func run() -> void:
 var scene=load("res://scenes/prototype_3d/aren_terrain_test.tscn").instantiate()
 root.add_child(scene);scene.automated=true;scene.set_physics_process(false)
 var cases:=0
 for style in ["normal","cautious","tired"]:
  scene.actor.change_style(style)
  for sprint in [false,true]:
   for angle in [0,45,90,135,180,225,270,315]:
    var direction:=Basis(Vector3.UP,deg_to_rad(angle))*Vector3.FORWARD
    var at:=Vector3(7,0,-6.9)-direction*2.7;at.y=.32
    scene.reset_at(at);scene.test_run=sprint
    scene.test_input=Vector2(direction.x,direction.z)
    scene.actor.rotation.y=atan2(direction.x,direction.z)
    var previous:Array[Dictionary]=[]
    for tick in 160:
     await physics_frame
     # Include keyboard retargeting and a moving camera on the terraces.
     if tick>=115 and tick<135:
      scene.yaw+=.012
      scene.test_input=Vector2(direction.x,direction.z).rotated(.25)
     scene._physics_process(1.0/60)
     var actor=scene.actor
     check(absf(actor.turn_bank)<=deg_to_rad(4)+.0001,"Stair turn exceeded the balanced bank")
     check(absf(actor.reach_velocity)<=.75001,"Pelvis compensation lost its velocity bound")
     check(is_finite(actor.pelvis_offset),"Pelvis correction is not finite")
     for side in actor.terrain_contacts.size():
      var leg:Dictionary=actor.native.legs[side];var ids:Array=leg.ids
      var hip:Vector3=actor.native.posed[ids[0]].origin
      var knee:Vector3=actor.native.posed[ids[1]].origin
      var ankle:Vector3=actor.native.posed[ids[2]].origin
      var length_error:float=maxf(absf(hip.distance_to(knee)-leg.a),absf(knee.distance_to(ankle)-leg.b))*(1.75/64)
      maximum_length_error=maxf(maximum_length_error,length_error)
      # Joint/pole calculations use single-precision vectors. Keep a physical
      # 0.05 mm tolerance, far below a visible stretch or the 3 mm sole margin.
      check(length_error<.00005,"Stair IK changed native bone lengths")
      check(hip.distance_to(ankle)>=actor.minimum_reach(side)-.0001,"Stair IK exceeded the authored anatomical flexion bound")
      var contact:Dictionary=actor.terrain_contacts[side]
      if previous.size()>side and contact.planted and previous[side].planted and contact.anchor.is_equal_approx(previous[side].anchor):
       var actual:Transform3D=actor.global_transform*actor.native.posed[ids[2]]
       var slide:=Vector2(actual.origin.x-contact.anchor.x,actual.origin.z-contact.anchor.z).length()
       maximum_slide=maxf(maximum_slide,slide)
       check(slide<.006,"Stair support slid horizontally")
       check(actual.basis.orthonormalized().get_rotation_quaternion().angle_to(contact.basis.orthonormalized().get_rotation_quaternion())<deg_to_rad(2),"Stair support rotated abruptly")
     previous.clear()
     for contact in actor.terrain_contacts:previous.append(contact.duplicate())
     if tick%16==0 and tick>30:check_surface(scene)
     if tick==65:check_skin(actor)
    cases+=1
 print("Stair support: ",cases," cases; ",checks," checks; failures ",failures.size(),"; skin error ",maximum_skin_error*1000," mm; surface difference ",maximum_surface_error*1000," mm; planted slide ",maximum_slide*1000," mm; bone length error ",maximum_length_error*1000," mm; box poses ",surface_checks)
 scene.free();quit(0 if failures.is_empty() else 1)
