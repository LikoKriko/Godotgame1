extends RefCounted
## Offline native-rig baking. Never edits the imported mesh, skin or rest pose.
const Request=preload("res://scripts/animation/authoring/aren_request.gd")
const Actor=preload("res://scripts/prototype_3d/survivor_model.gd")
const Solver=preload("res://scripts/continuous_body_pose.gd")
const Torso=preload("res://scripts/animation/authoring/aren_torso_flow.gd")
const MODEL="res://assets/characters/prototype_3d/composite/model.scn"
const PROFILE="res://data/animation/characters/survivor_native.tres"
const CATALOG="res://data/animation/authoring/aren_clips.json"
const SCALE=1.75/64.0
const SAMPLES=120
const CACHE="res://data/animation/characters/aren_rig_cache.json"
var actor:Node3D
var fingerprint:Dictionary={}
var source_kind:="unavailable"
var arm_references:Dictionary={}
var torso_reference:Dictionary={}
func configure(parent:Node) -> bool:
 actor=Actor.new();parent.add_child(actor)
 actor.family_override=&"";actor.steering_is_physical=true
 if actor.native.skeleton.get_bone_count()!=66:return false
 var sources=[MODEL,PROFILE,CATALOG,"res://assets/characters/prototype_3d/composite/source.json","res://scripts/animation/characters/native_survivor.gd","res://scripts/prototype_3d/survivor_model.gd","res://scripts/prototype_3d/humanoid_rig.gd","res://scripts/prototype_3d/survivor_animation.gd","res://scripts/prototype_3d/human_kinematics.gd","res://scripts/continuous_body_pose.gd","res://scripts/animation/characters/native_hand_grip.gd","res://scripts/animation/shared/rig_binding.gd","res://scripts/animation/characters/gait_parameters.gd","res://scripts/animation/authoring/aren_generator.gd","res://scripts/animation/authoring/aren_request.gd","res://scripts/animation/authoring/aren_validator.gd","res://tools/animation/generate_aren.gd"]
 sources.append_array(["res://scripts/animation/authoring/aren_torso_flow.gd","res://scripts/animation/authoring/aren_playback.gd","res://scripts/animation/characters/hip_skin.gd"])
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
 if not catalog is Dictionary or not catalog.get("clips") is Array:return false
 for entry in catalog.clips:
  if entry.authorization=="existing_project_authoring_only" and entry.kind=="contact_controls" and entry.rig=="survivor_native" and entry.path=="res://assets/characters/prototype_3d/motion/controls.res" and entry.source=="res://tools/animation/characters/motion_source.gd" and ResourceLoader.exists(entry.path):
   sources.append(entry.path);sources.append(entry.source);source_kind="authorized_project_controls";break
 if source_kind=="unavailable":return false
 for path in sources:fingerprint[path]=FileAccess.get_sha256(path)
 return true
func profile() -> Dictionary:
 if FileAccess.file_exists(CACHE):
  var cached=JSON.parse_string(FileAccess.get_file_as_string(CACHE))
  if cached is Dictionary and cached.get("hashes",{})==fingerprint and cached.get("bones",[]).size()==66:return cached
 var bones:Array=[]
 var native=actor.native
 for i in native.rest.size():
  var value:Transform3D=native.binding.locals[i]
  bones.append({"name":str(native.skeleton.get_bone_name(i)),"parent":native.parents[i],"length":value.origin.length(),"origin":[value.origin.x,value.origin.y,value.origin.z],"axes":[[value.basis.x.x,value.basis.x.y,value.basis.x.z],[value.basis.y.x,value.basis.y.y,value.basis.y.z],[value.basis.z.x,value.basis.z.y,value.basis.z.z]]})
 return {"schema":1,"actor":"Aren","rig":"survivor_native","hashes":fingerprint,"bones":bones,"roles":native.PROFILE.bones,"chains":native.PROFILE.chains,"game_height_m":1.75,"source_kind":source_kind}
func set_animation_style(character:String,clip:String,parameters:Dictionary,skeleton_path:NodePath,mesh_path:NodePath) -> Animation:
 if character.to_lower()!="aren" or clip not in ["idle","walk","run"]:return null
 var checked:=Request.parameters("natural",parameters)
 if not checked.ok:return null
 return bake(clip,checked.values,skeleton_path,mesh_path)
func cycle_info(motion:String,p:Dictionary) -> Dictionary:
 var running:=motion=="run"
 var support:float=(0.22 if running else 0.25)+p.caution*0.04
 var half:float=(12.33375 if running else 8.8)*p.stride
 var duration:float=(0.6844 if running else 0.9625)/p.cadence
 var distance:=2*half/support*SCALE
 return {"duration":duration,"distance_m":distance,"speed_mps":distance/duration,"support":support,"half":half}
static func smooth5(t:float) -> float:
 t=clampf(t,0,1)
 return t*t*t*(t*(t*6-15)+10)
func foot(phase:float,info:Dictionary,lift:float) -> Vector3:
 var t:=fposmod(phase,1.0)
 if t<info.support:return Vector3(0,0,lerpf(info.half,-info.half,t/info.support))
 var u:float=(t-info.support)/(1-info.support)
 # Hermite velocities meet the support speed on both sides of the seam.
 var velocity:float=-2*info.half/info.support*(1-info.support)
 var z:float
 var release:=.10;var landing:=.14
 if u<release:
  var q:=u/release
  z=-info.half+velocity*release*(q-(pow(q,6)-3*pow(q,5)+2.5*pow(q,4)))
 elif u>1-landing:
  var q:float=(1-u)/landing
  z=info.half-velocity*landing*(q-(pow(q,6)-3*pow(q,5)+2.5*pow(q,4)))
 else:z=lerpf(-info.half+velocity*release*.5,info.half-velocity*landing*.5,smooth5((u-release)/(1-release-landing)))
 return Vector3(0,64*pow(u,3)*pow(1-u,3)*lift,z)
func sample(motion:String,phase:float,p:Dictionary) -> void:
 var native=actor.native
 if motion!="idle":capture_arm_reference(motion)
 actor.animate(StringName(motion),phase,false,0,phase,Vector3.BACK if motion!="idle" else Vector3.ZERO)
 if motion=="idle":return
 if motion=="walk":Torso.apply(native,phase,p,torso_reference)
 var info:=cycle_info(motion,p)
 var hip:int=native.binding.bone(&"root")
 var pivot:Vector3=native.posed[hip].origin
 var lower:float=0.8+p.fatigue*0.5+p.caution*0.4
 var rotation:=Basis(Vector3.RIGHT,p.lean)
 var shift:=Vector3(sin(phase*TAU)*p.caution*0.12,-lower,0)
 var transform:=Transform3D(rotation,pivot+shift-rotation*pivot)
 # Coherent pelvis/spine/shoulder layer. Legs are solved from final hip sockets.
 for i in native.posed.size():native.posed[i]=transform*native.posed[i]
 # Fatigue is an articulated posture, not just a slower playback clock.
 for item in [[native.spine[1],p.fatigue*.10],[native.neck,p.fatigue*.07]]:
  var bone:int=item[0]
  var centre:Vector3=native.posed[bone].origin
  var bend:=Basis(Vector3.RIGHT,float(item[1]))
  rotate_subtree(bone,Transform3D(bend,centre-bend*centre))
 # Guarantee the whole planted interval fits the native legs. Solve once for
 # its extreme endpoints, instead of clamping a planted foot and making it slide.
 var reach_lowering:=0.0
 for side in 2:
  var leg:Dictionary=native.legs[side]
  var hip_position:Vector3=native.posed[leg.ids[0]].origin
  var ankle:Vector3=native.rest[leg.ids[2]].origin+Vector3.UP*.30
  var horizontal:float=pow(info.half+absf(hip_position.z),2)+pow(hip_position.x-ankle.x,2)
  var allowed:float=ankle.y+sqrt(maxf(.1,pow(leg.a+leg.b-.08,2)-horizontal))
  reach_lowering=maxf(reach_lowering,hip_position.y-allowed)
 if reach_lowering>0:
  for i in native.posed.size():native.posed[i].origin.y-=reach_lowering
 for side in 2:
  var chain:Dictionary=native.arms[side]
  var shoulder:int=chain.ids[1]
  var arm_pivot:Vector3=native.posed[shoulder].origin
  var reference:Dictionary=arm_references[motion][side]
  var current:=arm_angle(side)
  var base_angle:=current
  if p.anticipation>0:
   var at:float=fposmod(phase+p.anticipation,1.0)*SAMPLES
   base_angle=lerp_angle(reference.samples[floori(at)],reference.samples[floori(at)+1],at-floorf(at))
  var desired:float=reference.centre+(base_angle-reference.centre)*p.arms+p.tension*.04
  var axis:Vector3=torso_basis().x.normalized()
  var arm_rotation:=Basis(axis,current-desired)
  rotate_subtree(shoulder,Transform3D(arm_rotation,arm_pivot-arm_rotation*arm_pivot))
  chain=native.legs[side]
  var ids:Array=chain.ids
  var target:Vector3=foot(phase+side*.5,info,(4.5 if motion=="run" else 2.8)*(1-p.fatigue*0.18))
  target.x=native.rest[ids[2]].origin.x
  target.y+=native.rest[ids[2]].origin.y+0.30
  var solved:=Solver.joint(native.posed[ids[0]].origin,target,chain.a,chain.b,Vector3.BACK)
  native.untwisted_chain(ids,0,solved,Basis.IDENTITY)
  # Flat planted soles; children retain their native local transforms.
  var old:Transform3D=native.posed[ids[2]]
  var new_pose:=Transform3D(native.rest[ids[2]].basis,solved.end)
  rotate_subtree(ids[2],new_pose*old.affine_inverse())
  var cosine:float=clampf((solved.joint-solved.root).normalized().dot((solved.end-solved.joint).normalized()),-1,1)
  native.mesh.set_blend_shape_value(native.knee_shapes[side],.5*(1-cosine)*(1-smoothstep(deg_to_rad(115),deg_to_rad(145),acos(cosine))))
 for i in native.posed.size():native.local_globals[i]=native.inverse_frame*native.posed[i]
 native.writer.apply(native.skeleton,native.local_globals)
func torso_basis() -> Basis:
 var native=actor.native
 return (native.posed[native.spine[2]].basis*native.inverse_rest[native.spine[2]].basis).orthonormalized()
func arm_angle(side:int) -> float:
 var native=actor.native
 var ids:Array=native.arms[side].ids
 var direction:Vector3=torso_basis().inverse()*(native.posed[ids[2]].origin-native.posed[ids[1]].origin)
 return atan2(direction.z,-direction.y)
func capture_arm_reference(motion:String) -> void:
 if arm_references.has(motion):return
 var values:Array=[[],[]]
 var torso_frames:Array=[]
 for frame in SAMPLES+1:
  var phase:=frame/float(SAMPLES)
  actor.animate(StringName(motion),phase,false,0,phase,Vector3.BACK)
  if motion=="walk":torso_frames.append(Torso.capture(actor.native))
  for side in 2:values[side].append(arm_angle(side))
 var references:Array=[]
 for side in 2:references.append({"samples":values[side],"centre":(values[side].min()+values[side].max())*.5})
 arm_references[motion]=references
 if motion=="walk":torso_reference=Torso.summarize(torso_frames)
func rotate_subtree(bone:int,change:Transform3D) -> void:
 var native=actor.native
 for i in native.posed.size():
  var ancestor:int=i
  while ancestor>=0 and ancestor!=bone:ancestor=native.parents[ancestor]
  if ancestor==bone:native.posed[i]=change*native.posed[i]
func bake(motion:String,p:Dictionary,skeleton_path:NodePath,mesh_path:NodePath) -> Animation:
 var native=actor.native
 var clip:=Animation.new();clip.length=cycle_info(motion,p).duration if motion!="idle" else 1.0;clip.loop_mode=Animation.LOOP_LINEAR
 for i in native.posed.size():
  for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
   var track:=clip.add_track(type);clip.track_set_path(track,NodePath(str(skeleton_path)+":"+str(native.skeleton.get_bone_name(i))))
 for side in 2:
  var track:=clip.add_track(Animation.TYPE_BLEND_SHAPE);clip.track_set_path(track,NodePath(str(mesh_path)+":KneeFold"+("Right" if side==0 else "Left")))
 for frame in SAMPLES+1:
  sample(motion,frame/float(SAMPLES),p)
  var t:float=frame/float(SAMPLES)*clip.length
  for i in native.posed.size():
   var local:Transform3D=native.skeleton.get_bone_pose(i)
   clip.position_track_insert_key(i*3,t,local.origin)
   clip.rotation_track_insert_key(i*3+1,t,local.basis.orthonormalized().get_rotation_quaternion())
   clip.scale_track_insert_key(i*3+2,t,local.basis.get_scale())
  for side in 2:clip.blend_shape_track_insert_key(198+side,t,native.mesh.get_blend_shape_value(native.knee_shapes[side]))
 clip.set_meta("cycle",cycle_info(motion,p) if motion!="idle" else {"speed_mps":0.0})
 clip.set_meta("parameters",p);clip.set_meta("source_hashes",fingerprint);clip.set_meta("source_kind",source_kind)
 return clip
