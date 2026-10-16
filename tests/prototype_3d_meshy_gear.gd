extends SceneTree
## Verify real rendered geometry, not just logical animation sockets.
var failures:=0
var checks:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var other=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(other)
 require(actor.leaf_armor.shell.mesh==other.leaf_armor.shell.mesh,"All wearers share immutable garment geometry")
 require(actor.leaf_armor.shell.skin!=other.leaf_armor.shell.skin and actor.leaf_armor.skeleton!=other.leaf_armor.skeleton,"World and portrait own separate garment skins/poses")
 var original:Transform3D=other.leaf_armor.skeleton.get_bone_pose(4)
 actor.family_override=&"bow";actor.nock_visible=true
 var prop=actor.held_props[&"bow"];var mesh:ArrayMesh=prop.imported_bow.mesh
 var base:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var shapes:Array=mesh.surface_get_blend_shape_arrays(0)
 for phase in [0.,.5,1.]:
  actor.aim_contact=Vector3(0,42,80);actor.animate(&"draw",phase,true)
  var nearest:=INF;var fixed_tips:=0
  for i in base.size():
   if base[i].z> -4:continue
   if (shapes[2][Mesh.ARRAY_VERTEX] as PackedVector3Array)[i].z>.95:
    var point:=base[i]
    for shape in 4:point+=(shapes[shape][Mesh.ARRAY_VERTEX] as PackedVector3Array)[i]*prop.imported_bow.get_blend_shape_value(shape)
    nearest=minf(nearest,point.distance_to(prop.nocked.position))
   if absf(base[i].y)>11 and (shapes[2][Mesh.ARRAY_VERTEX] as PackedVector3Array)[i].length()<.03:fixed_tips+=1
  require(nearest<.6,"Original rope vertices reach the visible arrow nock throughout the draw")
  require(fixed_tips>0,"String ends remain tied to the stave")
 require(other.leaf_armor.skeleton.get_bone_pose(4).is_equal_approx(original),"Animating armor cannot change another actor")
 for family:StringName in [&"axe",&"pickaxe"]:
  var native:Mesh=load("res://assets/models/meshy/"+String(family)+"/model.res")
  var profile:Dictionary=preload("res://scripts/prototype_3d/held_profiles.gd").profile(family)
  require(is_equal_approx(native.get_aabb().size.y,19.2 if family==&"axe" else 21.6),"Held tool is exactly forty percent shorter")
  require(is_equal_approx(profile.support,4.95),"Supporting palm scales with the shortened handle")
  var dropped=preload("res://scripts/prototype_3d/item_models.gd").create({"id":family})
  var size:Vector3=preload("res://scripts/prototype_3d/item_models.gd").bounds(dropped).size
  require(absf(size[size.max_axis_index()]-native.get_aabb().size.y*1.75/64)<.001,"Dropped tool keeps the resized held tool's physical dimensions")
  dropped.free()
  var tip:Vector3=preload("res://scripts/prototype_3d/held_profiles.gd").profile(family).tip
  var closest:=INF
  for point:Vector3 in native.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:closest=minf(closest,point.distance_to(tip))
  require(closest<.001,"Impact anchor lies on the actual imported cutting tip")
  actor.family_override=family
  var points:PackedVector3Array=native.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for phase in [0.,.28,.5,.65,.84,1.]:
   actor.aim_contact=Vector3(0,30,32);actor.animate(&"action",phase,true)
   var body_inverse:Transform3D=actor.last_pose.body.affine_inverse()
   var skull_inverse:Transform3D=actor.rig.posed[3].affine_inverse()
   var rib_clear:=true;var head_clear:=true
   for p in points:
    var position:Vector3=actor.grip_socket.transform*p
    var local:Vector3=body_inverse*position
    if local.y>31 and local.y<51:
     var section:Vector4=preload("res://scripts/prototype_3d/meshy_body_profile.gd").section(local.y)
     rib_clear=rib_clear and Vector2(local.x/section.y,(local.z-(section.z+section.w)*.5)/((section.w-section.z)*.5)).length()>=.95
    var head:Vector3=skull_inverse*position-Vector3(0,.5,2.2)
    head_clear=head_clear and (head/Vector3(5.1,6.2,6.2)).length()>=.95
   require(rib_clear,"Complete source mesh stays outside torso interior during the stroke")
   require(head_clear,"Complete source mesh stays outside skull interior during the stroke")
 var rock=load("res://scripts/prototype_3d/rock.gd").new();root.add_child(rock);rock.configure(1)
 var visual:MeshInstance3D=rock.visual.get_child(0)
 require(visual.mesh==load("res://assets/models/meshy/rock1/model.res"),"World outcrop uses the supplied rock geometry")
 require(absf(visual.mesh.get_aabb().size.y*visual.scale.y-rock.height)<.001,"Rock height preserves the resource's physical scale")
 var hitbox:CollisionShape3D=rock.get_child(0)
 require(hitbox.shape.size.x>rock.height*2 and hitbox.shape.size.z>rock.height*2,"Physical footprint follows the wide imported outcrop")
 rock.free();actor.free();other.free()
 print("%s: %d imported gear geometry, draw-string, independent armor and rock volume checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
