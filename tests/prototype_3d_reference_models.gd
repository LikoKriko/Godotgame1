extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Settings=preload("res://scripts/prototype_3d/settings_panel.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var human=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(human)
 var young=load("res://scripts/prototype_3d/young_model.gd").new();root.add_child(young)
 require(FileAccess.get_sha256("res://assets/characters/prototype_3d/reference_front.png")==FileAccess.get_sha256("res://entregables/personajes/personaje1_frente.png"),"Runtime front painting preserves the supplied reference exactly")
 require(FileAccess.get_sha256("res://assets/characters/prototype_3d/reference_back.png")==FileAccess.get_sha256("res://entregables/personajes/personaje1_espaldas.png"),"Runtime back painting preserves the supplied reference exactly")
 for actor in [human,young]:
  var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var skeleton:Skeleton3D=actor.rig.skeleton if actor==human else actor.skeleton
  var finite:=true;var normalized:=true;var valid_ids:=true
  for i in vertices.size():
   finite=finite and vertices[i].is_finite()
   var total:=0.0
   for j in 4:
    var index:=i*4+j;total+=weights[index]
    valid_ids=valid_ids and bones[index]>=0 and bones[index]<skeleton.get_bone_count()
   normalized=normalized and absf(total-1)<0.0001
  require(finite and normalized and valid_ids,"All rebuilt skin vertices have finite geometry and valid normalized bindings")
  var mesh:Mesh=actor.mesh_node.mesh
  var states:Array=Clips.STATES if actor==human else preload("res://scripts/prototype_3d/animation_review.gd").YOUNG_STATES
  for state in states:
   for frame in 12:
    if actor==human:actor.family_override=&"axe";actor.animate(state,frame/11.0,true,0,frame/11.0,Vector3.BACK)
    else:actor.animate(state,frame/11.0,frame%2==0)
    var posed:Array=actor.rig.posed if actor==human else actor.posed
    var finite_pose:=true
    for transform:Transform3D in posed:finite_pose=finite_pose and transform.is_finite() and absf(transform.basis.determinant())>0.1
    require(finite_pose and actor.mesh_node.mesh==mesh,"Every clip deforms the new bind mesh without rebuilding or collapsing it")
 require(absf(Settings.hud_scale(1)-sqrt(0.4*1.4))<0.00001,"New HUD level 1 equals former level 3")
 for level in range(1,6):
  require(absf(pow(Settings.hud_scale(level)/Settings.hud_scale(1),2)-(1+0.1*(level-1)))<0.00001,"Each HUD step adds ten percent of the new base surface")
 require(Settings.hud_scale(0)==Settings.hud_scale(1) and Settings.hud_scale(6)==Settings.hud_scale(5),"HUD clamps obsolete and out-of-range settings")
 human.free();young.free();print("%s: %d reference mesh, animation skin and HUD checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
