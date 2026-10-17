extends RefCounted
## Offline adaptation of bone rotations; meshes, skins and limb lengths stay native.
const Binding=preload("res://scripts/animation/shared/rig_binding.gd")
var source=Binding.new()
var target=Binding.new()
var mapping:Dictionary={}
var errors:Array=[]
var skipped_tracks:Array[String]=[]
var alignment:=Basis.IDENTITY
var root_scale:=1.0
var configured:=false
func configure(source_rig:Skeleton3D,target_rig:Skeleton3D,source_profile:Resource,target_profile:Resource,source_to_target:Basis=Basis.IDENTITY,allow_different_family:bool=false) -> bool:
 configured=false;mapping.clear();errors.clear()
 if not source.configure(source_rig,source_profile):errors=source.errors.duplicate();return false
 if not target.configure(target_rig,target_profile):errors=target.errors.duplicate();return false
 if not source_to_target.is_finite() or source_to_target.determinant()<.000001:errors.append("Alignment must be a finite rotation");return false
 if not allow_different_family and (source_profile.category!=target_profile.category or source_profile.locomotion_family!=target_profile.locomotion_family):errors.append("Different locomotion families need an explicit reviewed override");return false
 alignment=source_to_target.orthonormalized();root_scale=target_profile.reference_height/source_profile.reference_height
 for role in source.roles:
  if not target.roles.has(role):continue
  var a:int=source.roles[role];var b:int=target.roles[role]
  var axes:Basis=target.globals[b].basis.orthonormalized().inverse()*alignment*source.globals[a].basis.orthonormalized()
  mapping[source_rig.get_bone_name(a)]={"source":a,"target":b,"name":target_rig.get_bone_name(b),"axes":axes.get_rotation_quaternion()}
 if mapping.is_empty():errors.append("No shared semantic bones");return false
 configured=true;return true
func retarget_animation(clip:Animation,source_path:NodePath,target_path:NodePath,include_root_motion:bool=false) -> Animation:
 skipped_tracks.clear()
 if not configured or clip==null:return null
 var result:=Animation.new();result.length=clip.length;result.loop_mode=clip.loop_mode;result.step=clip.step;result.resource_name=clip.resource_name
 for track in clip.get_track_count():
  var path:=clip.track_get_path(track);var type:=clip.track_get_type(track)
  var label:=path.get_subname(0) if path.get_subname_count()==1 else StringName()
  if path.get_concatenated_names()!=source_path.get_concatenated_names() or not mapping.has(label):skipped_tracks.append(String(path));continue
  var entry:Dictionary=mapping[label];var a:int=entry.source;var b:int=entry.target
  var rotation:bool=type==Animation.TYPE_ROTATION_3D
  var translation:bool=type==Animation.TYPE_POSITION_3D and include_root_motion and source.parents[a]<0 and target.parents[b]<0
  if not rotation and not translation:skipped_tracks.append(String(path));continue
  var destination:=result.add_track(type);result.track_set_path(destination,NodePath(String(target_path)+":"+entry.name))
  result.track_set_interpolation_type(destination,clip.track_get_interpolation_type(track))
  result.track_set_interpolation_loop_wrap(destination,clip.track_get_interpolation_loop_wrap(track));result.track_set_enabled(destination,clip.track_is_enabled(track))
  for key in clip.track_get_key_count(track):
   var value=clip.track_get_key_value(track,key);var time:=clip.track_get_key_time(track,key)
   if rotation:
    var source_rest:Quaternion=source.locals[a].basis.orthonormalized().get_rotation_quaternion()
    var target_rest:Quaternion=target.locals[b].basis.orthonormalized().get_rotation_quaternion()
    var relative:Quaternion=source_rest.inverse()*value
    var adapted:Quaternion=(target_rest*entry.axes*relative*entry.axes.inverse()).normalized()
    result.rotation_track_insert_key(destination,time,adapted)
   else:
    var adapted:Vector3=target.locals[b].origin+alignment*(value-source.locals[a].origin)*root_scale
    result.position_track_insert_key(destination,time,adapted)
   result.track_set_key_transition(destination,key,clip.track_get_key_transition(track,key))
 return result
