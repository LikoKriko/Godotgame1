extends RefCounted
## Read-only sampling of the baked native cycles. No copies of animation keys.
var clips:Dictionary={}
var tracks:Dictionary={}
var skeleton:Skeleton3D
var foot_chains:Array=[]
func configure(library:AnimationLibrary,rig:Skeleton3D) -> void:
 skeleton=rig;foot_chains.clear()
 for side in ["Right","Left"]:
  var chain:Array[int]=[];var bone:=skeleton.find_bone("smartrig_"+side+"Foot")
  while bone>=0:chain.push_front(bone);bone=skeleton.get_bone_parent(bone)
  foot_chains.append(chain)
 for name in ["idle","walk","run"]:
  var clip:Animation=library.get_animation(StringName(name));clips[name]=clip
  var bindings:Array=[]
  for track in clip.get_track_count():
   var path:=clip.track_get_path(track)
   var bone:=skeleton.find_bone(str(path.get_subname(0))) if path.get_subname_count()>0 else -1
   bindings.append(bone)
  tracks[name]=bindings
func sample(name:String,time:float) -> Dictionary:
 var clip:Animation=clips[name];var t:=fposmod(time,clip.length)
 var poses:Array[Transform3D]=[];var shapes:Dictionary={}
 for bone in skeleton.get_bone_count():poses.append(skeleton.get_bone_rest(bone))
 for track in clip.get_track_count():
  var bone:int=tracks[name][track]
  match clip.track_get_type(track):
   Animation.TYPE_POSITION_3D:poses[bone].origin=clip.position_track_interpolate(track,t)
   Animation.TYPE_ROTATION_3D:poses[bone].basis=Basis(clip.rotation_track_interpolate(track,t))
   Animation.TYPE_SCALE_3D:poses[bone].basis=poses[bone].basis.scaled_local(clip.scale_track_interpolate(track,t))
   Animation.TYPE_BLEND_SHAPE:
    shapes[str(clip.track_get_path(track).get_subname(0))]=clip.blend_shape_track_interpolate(track,t)
 var feet:Array[Transform3D]=[]
 for chain in foot_chains:
  var global_pose:=Transform3D.IDENTITY
  for bone in chain:global_pose=global_pose*poses[bone]
  feet.append(global_pose)
 return {"poses":poses,"shapes":shapes,"feet":feet}
