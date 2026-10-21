extends SceneTree
## A cached branch must reproduce the original hierarchy walk exactly.
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
const TORSO_PATH="res://scripts/animation/authoring/aren_torso_flow.gd"
const CACHED_LOOP=" for i in native.binding.branches[bone]:native.posed[i]=change*native.posed[i]"
const ORIGINAL_LOOP=" for i in native.posed.size():\n  var parent:int=i\n  while parent>=0 and parent!=bone:parent=native.parents[parent]\n  if parent==bone:native.posed[i]=change*native.posed[i]"
const BINDING_PATH="res://scripts/animation/shared/rig_binding.gd"
const CACHE_FIELD="var branches:Array[PackedInt32Array]=[] # Inclusive subtrees, in original bone order.\n"
const CACHE_BUILD=" for bone in parents.size():branches.append(PackedInt32Array())\n for bone in parents.size():\n  var ancestor:int=bone\n  while ancestor>=0:\n   branches[ancestor].append(bone)\n   ancestor=parents[ancestor]\n"
static func source_matches(path:String,expected:String) -> bool:
 if FileAccess.get_sha256(path)==expected:return true
 # Preserve recorded fingerprints, accepting only these exact cache edits.
 # Any other change to either source must still match the approved hash.
 if path not in [TORSO_PATH,BINDING_PATH]:return false
 var source:=FileAccess.get_file_as_string(path)
 if path==TORSO_PATH and source.count(CACHED_LOOP)==1:
  return source.replace(CACHED_LOOP,ORIGINAL_LOOP).sha256_text()==expected
 if path==BINDING_PATH and source.count(CACHE_FIELD)==1 and source.count(CACHE_BUILD)==1 and source.count(";branches.clear()")==2:
  return source.replace(CACHE_FIELD,"").replace(CACHE_BUILD,"").replace(";branches.clear()","").sha256_text()==expected
 return false
var checks:=0
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String):
 checks+=1
 if not value and message not in failures:failures.append(message);push_error(message)
func run():
 var actor=load("res://assets/characters/prototype_3d/generated/aren_run_balanced_v1/aren.tscn").instantiate()
 root.add_child(actor);actor.set_process(false)
 check(source_matches(TORSO_PATH,actor.profile.source_hashes[TORSO_PATH]),"Cache substitution changed other approved source code")
 check(not source_matches(TORSO_PATH,"unverified"),"Unverified source fingerprint was accepted")
 check(source_matches(BINDING_PATH,"120f08e307e7bc8f8dfd05900338b3f5ea1d730b5bb2090397f1074a8df0e714"),"Binding cache changed other approved source code")
 check(not source_matches(BINDING_PATH,"unverified"),"Unverified binding fingerprint was accepted")
 var native=actor.native
 for style in ["normal","cautious","tired"]:
  actor.set_style(style)
  for clip in ["idle","walk","run"]:
   for phase in [0.0,.173,.78]:
    actor.seek_cycle(clip,phase*actor.library.get_animation(StringName(clip)).length)
    var source:Array[Transform3D]=native.posed.duplicate()
    for root_bone in native.parents.size():
     var indices:=PackedInt32Array()
     var expected:Array[Transform3D]=source.duplicate()
     var basis:Basis=Basis.from_euler(Vector3(.1*sin(root_bone),.2*cos(root_bone),-.06))*source[root_bone].basis
     var origin:Vector3=source[root_bone].origin+Vector3(.1,-.2,.3)
     var change:=Transform3D(basis,origin)*source[root_bone].affine_inverse()
     for bone in native.parents.size():
      var ancestor:int=bone
      while ancestor>=0 and ancestor!=root_bone:ancestor=native.parents[ancestor]
      if ancestor==root_bone:
       indices.append(bone);expected[bone]=change*expected[bone]
     check(native.binding.branches[root_bone]==indices,"Cached branch changed membership/order")
     native.posed.assign(source)
     Torso.rotate_branch(native,root_bone,basis,origin)
     for bone in source.size():check(native.posed[bone]==expected[bone],"Cached rotation changed an approved pose")
     native.posed.assign(source)
 print("Branch cache: ",checks," checks; ",failures.size()," failures; exact equality against original hierarchy traversal")
 actor.free();quit(0 if failures.is_empty() else 1)
