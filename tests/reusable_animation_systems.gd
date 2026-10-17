extends SceneTree
const Binding=preload("res://scripts/animation/shared/rig_binding.gd")
const Adapter=preload("res://scripts/animation/shared/animation_retargeter.gd")
const EnemyProfile=preload("res://scripts/animation/enemies/enemy_profile.gd")
var checks:=0
var failures:=0
func require(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func make_rig(prefix:String,length:float,orientation:Basis=Basis.IDENTITY) -> Skeleton3D:
 var rig:=Skeleton3D.new();root.add_child(rig)
 for i in 3:
  rig.add_bone(prefix+str(i))
  if i>0:rig.set_bone_parent(i,i-1)
  var frame:=Transform3D(orientation if i==0 else Basis.IDENTITY,Vector3(0,length,0) if i>0 else Vector3.ZERO)
  rig.set_bone_rest(i,frame);rig.set_bone_pose(i,frame)
 return rig
func make_profile(prefix:String,height:float) -> Resource:
 var profile:=EnemyProfile.new();profile.rig_id=StringName(prefix);profile.locomotion_family=&"test_biped";profile.reference_height=height
 profile.bones={"root":prefix+"0","middle":prefix+"1","end":prefix+"2"};profile.chains={"leg":["root","middle","end"]};return profile
func run():
 var a:=make_rig("Source",1);var b:=make_rig("Target",2,Basis(Vector3.UP,PI*.5))
 var source:=make_profile("Source",2);var target:=make_profile("Target",4)
 var binding:=Binding.new();require(binding.configure(b,target),"Renamed target rig binds from a semantic profile")
 require(binding.chains.leg.a==2 and binding.chains.leg.b==2,"Target limb lengths are measured rather than copied from the source")
 var invalid:Resource=target.duplicate(true);invalid.bones["middle"]="missing"
 require(not binding.configure(b,invalid) and binding.roles.is_empty(),"Missing bones invalidate and clear a binding")
 var adapter:=Adapter.new();require(adapter.configure(a,b,source,target),"Compatible anatomy profiles enable adaptation")
 var clip:=Animation.new();clip.length=2;clip.loop_mode=Animation.LOOP_LINEAR
 for index in [0,1]:
  var track:=clip.add_track(Animation.TYPE_ROTATION_3D);clip.track_set_path(track,NodePath("Rig:Source"+str(index)))
  clip.rotation_track_insert_key(track,0,Quaternion.IDENTITY);clip.rotation_track_insert_key(track,1,Quaternion(Vector3.RIGHT,.6))
 var root_track:=clip.add_track(Animation.TYPE_POSITION_3D);clip.track_set_path(root_track,NodePath("Rig:Source0"));clip.position_track_insert_key(root_track,0,Vector3.ZERO);clip.position_track_insert_key(root_track,1,Vector3(0,0,1))
 var stretch_track:=clip.add_track(Animation.TYPE_POSITION_3D);clip.track_set_path(stretch_track,NodePath("Rig:Source1"));clip.position_track_insert_key(stretch_track,0,Vector3(0,9,0))
 var adapted:Animation=adapter.retarget_animation(clip,NodePath("Rig"),NodePath("Body/Rig"))
 require(adapted!=null and adapted.get_track_count()==2,"Default adaptation copies rotations and excludes limb translations")
 require(adapted.length==clip.length and adapted.loop_mode==clip.loop_mode,"Clip duration and loop timing are preserved")
 require(String(adapted.track_get_path(1))=="Body/Rig:Target1","Tracks use the target skeleton and its original names")
 var turn:Quaternion=adapted.track_get_key_value(1,1)
 var expected:=Quaternion(Vector3.BACK,.6)
 require(absf(turn.dot(expected))> .99999,"Rest axes redirect source rotations into target anatomy")
 var with_root:Animation=adapter.retarget_animation(clip,NodePath("Rig"),NodePath("Body/Rig"),true)
 require(with_root.get_track_count()==3,"Root motion is an explicit option, while limb translation remains excluded")
 var root_value:Vector3=with_root.track_get_key_value(2,1)
 require(root_value.distance_to(Vector3(0,0,2))<.000001,"Root travel adapts to reference height without changing limb offsets")
 require(b.get_bone_pose_position(1).distance_to(Vector3(0,2,0))<.000001,"Adaptation never mutates the target bind pose")
 var other:Resource=target.duplicate(true);other.locomotion_family=&"quadruped"
 require(not adapter.configure(a,b,source,other),"Unrelated enemy shapes cannot inherit locomotion automatically")
 require(adapter.configure(a,b,source,other,Basis.IDENTITY,true),"A reviewed explicit override remains available for partial pose transfer")
 var wrong_category:Resource=target.duplicate(true);wrong_category.category=&"character"
 require(not adapter.configure(a,b,source,wrong_category),"Character and enemy animation categories stay separate")
 var solved:=Binding.solve_metres(Vector3.ZERO,Vector3(1,0,0),.7,.7,Vector3.RIGHT)
 require(solved.joint.is_finite() and absf(solved.joint.length()-.7)<.00001 and absf(solved.joint.distance_to(solved.end)-.7)<.00001,"Shared IK handles a pole parallel to the limb without stretching")
 require(Binding.solve_metres(Vector3.ZERO,Vector3.ONE,0,.7,Vector3.UP).is_empty(),"Invalid limb dimensions are refused")
 var survivor=preload("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(survivor)
 var character_profile:Resource=load("res://data/animation/characters/survivor.tres")
 require(character_profile.resolve(survivor.rig.skeleton).ok and survivor.rig.anatomy.roles.size()==24,"Actual survivor uses the character humanoid profile with its native rig")
 var wider:Resource=character_profile.duplicate(true);wider.reference_width*=1.2;wider.reference_height*=1.1
 require(character_profile.adapt_contact(Vector3.ONE,wider).distance_to(Vector3(1.2,1.1,1))<.00001,"Character contact offsets adapt height and width independently")
 var broken_character:Resource=character_profile.duplicate(true);broken_character.bones.erase("arm_end_l")
 require(not broken_character.resolve(survivor.rig.skeleton).ok,"Humanoid profiles require their shared anatomical roles")
 survivor.free()
 for species in ["enemy1","enemy3"]:
  var scene=load("res://assets/enemies/first/rig/model.scn" if species=="enemy1" else "res://assets/enemies/third/sprout/model.scn").instantiate();root.add_child(scene)
  var rig:Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
  var profile:Resource=load("res://data/animation/enemies/"+species+".tres")
  require(profile.resolve(rig).ok,"Existing enemy anatomy is described without renaming bones")
  var map:=Binding.new();require(map.configure(rig,profile),"Existing enemy uses the shared measured binding")
  for chain:Dictionary in map.chains.values():require(chain.a>0 and chain.b>0,"All declared chains have measured lengths")
  scene.free()
 a.free();b.free();await process_frame
 print("%s: %d character/enemy profile, IK and animation adaptation checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
