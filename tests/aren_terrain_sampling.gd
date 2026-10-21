extends SceneTree
const Patch=preload("res://scripts/animation/terrain/terrain_test_patch.gd")
var failures:Array[String]=[]
var checks:=0
var maximum_height_error:=0.0
var maximum_lift_error:=0.0
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 checks+=1
 if not value and message not in failures:failures.append(message);push_error(message)
func run() -> void:
 # Compare the cached triangle surface with the real physics collider,
 # including diagonals, omitted edge triangles and translated patches.
 for forest in [false,true]:
  var patch=Patch.build("SamplingCheck",Vector2(6,8),forest)
  patch.position=Vector3(3,.2,-4);root.add_child(patch)
  for frame in 2:await physics_frame
  var grid:Dictionary=patch.get_meta(&"sole_height_grid")
  for index in 400:
   var local:=Vector3(sin(index*2.399963)*2.999,0,cos(index*1.618034)*3.999)
   var sample:=Patch.sample_grid(grid,local)
   var point:Vector3=patch.position+local
   var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2)
   var hit:=patch.get_world_3d().direct_space_state.intersect_ray(query)
   if sample.y<=0:
    check(hit.is_empty(),"Cached grid filled an omitted collision triangle")
   else:
    check(not hit.is_empty(),"Cached grid has no matching collision")
    if hit.is_empty():continue
    var error:float=absf(hit.position.y-(sample.w+patch.position.y))
    maximum_height_error=maxf(maximum_height_error,error)
    # Ray and plane calculations follow different single-precision paths;
    # allow 0.1 mm, well below the existing 3 mm sole margin.
    check(error<.0001,"Height grid differs from collider triangles")
    check(hit.normal.dot(Vector3(sample.x,sample.y,sample.z))>.9999,"Surface normal differs from collider")
  patch.free();await physics_frame
 var scene=load("res://scenes/prototype_3d/aren_terrain_test.tscn").instantiate()
 root.add_child(scene);scene.automated=true;scene.test_input=Vector2(0,-1)
 var fast_checks:=0;var positive_lifts:=0;var box_checks:=0
 for style in ["normal","cautious","tired"]:
  scene.actor.change_style(style)
  for sprint in [false,true]:
   for terrain in ["dirt","forest","bumps"]:
    var at:=Vector3(19 if terrain=="forest" else -17,.8,-2) if terrain!="bumps" else Vector3(-7,.3,-3)
    scene.reset_at(at);scene.test_run=sprint
    for frame in 90:await physics_frame
    for frame in 12:
     await physics_frame
     if frame%3!=0:continue
     var actor=scene.actor;var support=actor.foot_support
     # Check an actual articulated skin pose with a deliberate penetration.
     var transform:Transform3D=actor.global_transform.translated(Vector3.DOWN*.008)
     for side in 2:
      if not support.may_penetrate(actor.native,side,transform,scene.body.get_world_3d().direct_space_state):continue
      if not support.grid_valid and not support.boxes_valid:continue
      var fast:float=support.grid_lift(actor.native,side,transform) if support.grid_valid else support.boxes_lift(actor.native,side,transform)
      if fast<0:continue
      if support.boxes_valid:box_checks+=1
      fast_checks+=1
      if fast>.0001:positive_lifts+=1
      var reference:=0.0
      for point in support.skinned_points(actor.native,side):
       var world:Vector3=transform*point
       var hit:Dictionary=actor.probe(world)
       if not hit.is_empty():reference=maxf(reference,hit.position.y+.003-world.y)
      var error:=absf(fast-reference);maximum_lift_error=maxf(maximum_lift_error,error)
      check(fast>=reference-.0001,"Fast sole query missed a required correction")
      check(error<.004,"Fast sole query changed the sampled skin correction")
 check(fast_checks>30 and positive_lifts>10 and box_checks>3,"Fast grid/box skin query was not exercised")
 # Moving only the camera while stationary must not rotate or bank Aren.
 scene.test_input=Vector2.ZERO
 for frame in 90:await physics_frame
 var heading:float=scene.actor.rotation.y
 for frame in 60:
  scene.yaw+=.03;await physics_frame
  check(absf(wrapf(scene.actor.rotation.y-heading,-PI,PI))<.0001,"Camera-only input rotated Aren")
  check(absf(scene.actor.turn_bank)<deg_to_rad(.1),"Camera-only input banked stationary Aren")
 print("Terrain sampling: ",checks," checks; failures ",failures.size(),"; collider height error ",maximum_height_error*1000," mm; sole correction difference ",maximum_lift_error*1000," mm; fast poses ",fast_checks)
 scene.free();quit(0 if failures.is_empty() else 1)
