extends SceneTree
const Profile=preload("res://scripts/terrain_profile.gd")
const Biome=preload("res://scripts/world/biome_definition.gd")
const Sampler=preload("res://scripts/terrain_sampler.gd")
const Layout=preload("res://scripts/prototype_3d/stream_layout.gd")
const Random=preload("res://scripts/world/world_random.gd")
const Surface=preload("res://scripts/world/terrain_surface.gd")
const Recipe=preload("res://scripts/world/terrain/terrain_recipe.gd")
const Builder=preload("res://scripts/world/terrain/terrain_module_builder.gd")
var checks:=0
var failures:=0
func require(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var profile:Resource=load("res://data/world/terrain/temperate.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
 require(profile.valid(),"Current terrain preset validates")
 var bad:Resource=profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);bad.biome.rock_threshold=.1
 require(not bad.valid(),"Unordered population probabilities cannot be activated")
 bad=profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);bad.biome.density_noise_scale=NAN
 require(not bad.valid(),"Non-finite biome settings are rejected")
 var sampler:=Sampler.new();sampler.configure(73129,profile)
 for y in range(-20,21,2):
  for x in range(-20,21,2):
   var point:=Vector2(x,y)*137.0;var w:Vector4=sampler.weights_at(point)
   var expected:=clampf((w.x*.30+w.z*.85+w.y*.12)*(.5+sampler.noise_at(point/95.0)),0,1)
   require(sampler.vegetation_density(point)==expected,"Default biome preserves exact legacy density")
 for density in [0.0,.2,.8,1.0]:
  for roll in [0.0,.25,.649,.88,.90,.92,.95,1.0]:
   var expected:=2 if roll<density*.65 else (1 if roll>.94 else (4 if roll>.91 else (5 if roll>.88 else 0)))
   require(profile.biome.resource_kind(roll,density)==expected,"Default population classification preserves its probabilities")
 var copy=sampler.copy_for_worker();var before:float=copy.profile.biome.tree_fraction
 profile.biome.tree_fraction=.1;sampler.influences.append({"id":&"test","type":&"dirt","rect":Rect2(0,0,10,10),"strength":1.0})
 require(copy.profile.biome.tree_fraction==before and copy.influences.is_empty(),"Worker snapshots own their editable resources and influences")
 var sparse:=Sampler.new();var sparse_profile:Resource=profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
 sparse_profile.biome.density_normal=0;sparse_profile.biome.density_dark=0;sparse_profile.biome.density_vegetation=0;sparse_profile.biome.tree_fraction=0;sparse_profile.biome.plant_threshold=1;sparse_profile.biome.sapling_threshold=1;sparse_profile.biome.rock_threshold=1
 sparse.configure(73129,sparse_profile)
 var layout:=Layout.new();layout.configure(73129,sparse)
 var empty:Dictionary=layout.chunk(Vector2i(24,-17))
 require(empty.resources.is_empty() and empty.grass.is_empty(),"An alternate biome actually changes distant generation without editing the generator")
 var builder_worker=preload("res://scripts/prototype_3d/chunk_builder.gd").new();builder_worker.configure(layout);builder_worker.request(Vector2i(24,-17))
 var ready:Dictionary={};var timeout:=Time.get_ticks_msec()+5000
 while ready.is_empty() and Time.get_ticks_msec()<timeout:ready=builder_worker.collect();await process_frame
 require(not ready.is_empty() and ready.data.resources==empty.resources and ready.data.grass==empty.grass,"Worker uses the selected biome consistently")
 builder_worker.finish()
 for key in [Vector2i(-900,551),Vector2i.ZERO,Vector2i(5,-8)]:
  require(Random.chunk_seed(73129,key)==((73129 ^ (key.x*73856093) ^ (key.y*19349663))&0xffffffff),"Existing resource random stream stays compatible")
  require(Random.chunk_seed(73129,key,"settlements")!=Random.chunk_seed(73129,key,"trees"),"New generator channels have separate stable streams")
 var game=preload("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;game.terrain_configuration=sparse_profile
 root.add_child(game);game.paused=true
 require(game.terrain.sampler.profile.biome.tree_fraction==0 and game.terrain.sampler.profile.biome.get_instance_id()!=sparse_profile.biome.get_instance_id(),"Playable scene accepts a selected terrain preset as an independent configuration")
 game.free()
 var height:=func(p:Vector2)->float:return p.x*.1+p.y*.03
 var a:=Surface.build_mesh(Rect2(0,0,4,4),height,1);var b:=Surface.build_mesh(Rect2(4,0,4,4),height,1)
 var av:PackedVector3Array=a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var bv:PackedVector3Array=b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for z in 5:require((av[z*5+4]+Vector3(2,0,2)).distance_to(bv[z*5]+Vector3(6,0,2))<.000001,"Reusable height surfaces share exact chunk seams")
 require(Surface.build_mesh(Rect2(0,0,4,4),height,0)==null,"Invalid terrain grid is rejected")
 var recipe:Resource=load("res://data/world/recipes/initial_relief.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
 require(recipe.valid(),"Initial world is expressed as a valid editable recipe")
 var mound=preload("res://scripts/world/terrain/mound_feature.gd").new();mound.center=Vector2.ZERO;mound.radius=4;mound.height=2
 recipe.bounds=Rect2(-8,-8,16,16);recipe.edge_blend=2;recipe.features.assign([mound]);recipe.recipe_id=&"module_test"
 var cube:=Node3D.new();var visual:=MeshInstance3D.new();visual.mesh=BoxMesh.new();cube.add_child(visual);visual.owner=cube
 var scene:=PackedScene.new();scene.pack(cube);cube.free()
 var stamp=preload("res://scripts/world/terrain/scene_stamp.gd").new();stamp.stamp_id=&"existing_model";stamp.scene=scene;stamp.position=Vector2(4,3);stamp.footprint=Vector2(1,2);stamp.rotation_degrees=45
 recipe.stamps.assign([stamp])
 require(stamp.reserved_area(.05).size.x>2,"Stamp reservation includes rotated footprint and five percent margin")
 var module_builder:=Builder.new();var catalogue=preload("res://scripts/prototype_3d/story_zone_catalog.gd").new()
 var part:Node3D=module_builder.build(recipe,load("res://data/world/terrain/temperate.tres"),catalogue,Layout.BOUNDS)
 require(part!=null,"World modeller builds a reusable part with existing materials and scenes")
 if part!=null:
  root.add_child(part);await physics_frame;await physics_frame
  for mesh in part.find_children("*","MeshInstance3D",true,false):
   if mesh.has_meta("streamed_terrain"):require(mesh.material_override.get_shader_parameter("trial_path_widths").distance_to(Vector2(recipe.path.inner_width,recipe.path.outer_width))<.000001,"CPU recipe and terrain material use the same editable path widths")
  var hit:=part.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,6,0),Vector3(0,-1,0)))
  require(not hit.is_empty() and absf(hit.position.y-2)<.01,"Modelled terrain has matching physical relief")
  var packed:=PackedScene.new();require(packed.pack(part)==OK,"Generated terrain part can be packed as a reusable scene")
  var restored:=packed.instantiate();root.add_child(restored)
  require(restored.get_children().any(func(node):return node.get_meta("terrain_stamp_id",&"")==&"existing_model"),"Packed parts retain stable model stamp identifiers")
  restored.free();part.free()
 var protected:Resource=recipe.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);protected.bounds=Rect2(180,-140,24,24)
 require(module_builder.build(protected,profile,catalogue,Layout.BOUNDS)==null,"World modeller refuses the complete footprint of protected story zones")
 recipe.stamps.append(stamp)
 require(module_builder.build(recipe,profile,catalogue,Layout.BOUNDS)==null,"Repeated stamp IDs are rejected before scene construction")
 print("%s: %d reusable world, biome and modelling checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
