extends SceneTree
const Layout=preload("res://scripts/prototype_3d/stream_layout.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate()
 game.use_test_layout=true;root.add_child(game);game.paused=true
 game.set_physics_process(false);game.player.set_physics_process(false);game.distance_optimization.set_process(false)
 var rig=game.camera_rig;var camera:Camera3D=rig.camera
 var viewport:=SubViewport.new();game.add_child(viewport)
 var portrait:=Camera3D.new();viewport.add_child(portrait);var portrait_far:=portrait.far
 var visual:=MeshInstance3D.new();visual.mesh=SphereMesh.new();visual.material_override=StandardMaterial3D.new()
 visual.position=game.player.position+Vector3(0,0,-20);game.add_child(visual)
 var source:Mesh=visual.mesh;var paint:Material=visual.material_override
 await process_frame
 game.day_cycle.hour=13;game.settings.values.lighting_finish_trial=true
 var ranges:Dictionary={}
 for radius in [200,400,100,200]:
  game.settings.values.world_generation=radius;game.settings.changed.emit()
  ranges[radius]=camera.far
  require(camera.far==rig.aim_camera.far,"Rendered and aiming cameras share the live world coverage")
  require(portrait.far==portrait_far,"World coverage does not modify inventory cameras")
  require(is_equal_approx(game.world_ambient.fog_depth_begin,35),"The nearby haze-free zone stays at 35 metres")
  require(is_equal_approx(game.world_ambient.fog_depth_end,minf(220,radius)),"Active haze ends within the selected loading radius, including while paused")
  game.distance_optimization.update_quality(.1)
  require(visual.mesh==source and visual.material_override==paint,"Changing coverage preserves the exact nearby mesh and material")
  require(game.distance_optimization.entries[visual.get_instance_id()].quality==100,"Nearby detail stays at full quality for every radius")
  # Check the old window contract on both sides of positive/negative cell edges.
  for point in [Vector3(-32.001,0,31.999),Vector3(-.001,0,.001),Vector3(31.999,8,-32.001)]:
   var center:=Layout.rect(Layout.coordinate(Vector2(point.x,point.z))).get_center()
   var old_area:=Rect2(center-Vector2.ONE*(radius+16),Vector2.ONE*(radius*2+32))
   require(Layout.window(point,radius)==old_area,"Shared coverage preserves the generated chunks and story reservations")
   var area:=old_area.grow(Layout.CHUNK_SIZE)
   var first:=Layout.coordinate(area.position);var last:=Layout.coordinate(area.end)
   for key in [first,last,Vector2i(first.x,last.y),Vector2i(last.x,first.y)]:
    var rect:=Layout.rect(key)
    for corner in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
     for y in [0.,32.]:
      var target:=Vector3(corner.x,y,corner.y)
      camera.global_position=point+Vector3(0,1.45,3.7);camera.look_at(target)
      require(camera.is_position_in_frustum(target),"Even retained chunk corners and elevated visuals fit before the far plane")
  # The same camera clips all world geometry, including graphics created later.
  var batch:=MultiMeshInstance3D.new();game.add_child(batch)
  var grass:=MeshInstance3D.new();grass.set_meta("quality_bucket",true);grass.mesh=PlaneMesh.new();game.add_child(grass)
  var particles:=CPUParticles3D.new();particles.emitting=false;game.add_child(particles)
  camera.global_position=Vector3.ZERO;camera.look_at(Vector3.FORWARD)
  for node in [batch,grass,particles]:
   node.position=Vector3.FORWARD*(camera.far+20)
   require(not camera.is_position_in_frustum(node.global_position),"Late world batches, grass and effects share the same far plane")
  batch.free();grass.free();particles.free()
 require(ranges[100]<ranges[200] and ranges[200]<ranges[400],"All three options change the render coverage")
 game.settings.values.lighting_finish_trial=false;game.settings.changed.emit()
 for property in game.lighting_finish.ENVIRONMENT_PROPERTIES:
  require(game.world_ambient.get(property)==game.lighting_finish.original[property],"Disabling the finish restores its original environment")
 game.settings.values.world_generation=400;game.settings.changed.emit()
 require(not game.lighting_finish.active and camera.far==ranges[400],"Coverage still updates when the atmospheric finish is disabled")
 game.free();await process_frame
 print("%s: %d world coverage, nearby detail, atmosphere and live graphics checks"%["PASS" if failures==0 else "FAIL",checks])
 quit(1 if failures else 0)
