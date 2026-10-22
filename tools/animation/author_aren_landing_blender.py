"""Blender 4.3+: eight complete poses, editable limb IK, native 66-bone bake.
blender -b -t 4 --python tools/animation/author_aren_landing_blender.py
The only imported movement reference is one worked reception pose plus idle.
No procedural animation evaluator or sampled procedural sequence is imported.
"""
import bpy, json, math, struct, sys
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1'
AUTHOR=OUT/'authoring'
STEM=sys.argv[sys.argv.index('--output-stem')+1] if '--output-stem' in sys.argv else 'landing_3m'
def bake_native(rig):
 for name in ["Aren_Baked_66","ExportSkin"]:
  old=bpy.data.objects.get(name)
  if old:bpy.data.objects.remove(old,do_unlink=True)
 # Keep the editable original and bake a separate copy for the game.
 baked=rig.copy();baked.data=rig.data.copy();bpy.context.collection.objects.link(baked);baked.name='Aren_Baked_66'
 baked.animation_data.action=rig.animation_data.action.copy()
 bpy.ops.object.select_all(action='DESELECT');baked.select_set(True);bpy.context.view_layer.objects.active=baked
 bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.select_all(action='SELECT')
 bpy.ops.nla.bake(frame_start=1,frame_end=156,step=1,only_selected=False,visual_keying=True,clear_constraints=True,use_current_action=False,bake_types={'POSE'},clean_curves=False)
 bpy.ops.object.mode_set(mode='OBJECT');baked.animation_data.action.name='ArenLanding3m_Baked';baked.animation_data.action.use_fake_user=True
 # A tiny hidden skin ensures glTF retains all 66 native joints without duplicating the character asset.
 mesh=bpy.data.meshes.new('ExportSkin');mesh.from_pydata([(0,0,0),(.001,0,0),(0,.001,0)],[],[(0,1,2)])
 proxy=bpy.data.objects.new('ExportSkin',mesh);bpy.context.collection.objects.link(proxy);proxy.matrix_world=baked.matrix_world.copy();proxy.parent=baked
 vg=proxy.vertex_groups.new(name='smartrig:Hips');vg.add([0,1,2],1,'REPLACE');mod=proxy.modifiers.new('NativeSkin','ARMATURE');mod.object=baked
 bpy.ops.object.select_all(action='DESELECT');baked.select_set(True);proxy.select_set(True);bpy.context.view_layer.objects.active=baked
 bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_anim_single_armature=False,export_frame_range=True,export_force_sampling=True,export_def_bones=False,export_materials='NONE',export_yup=True)
 # Blender's active-action exporter emits identity object tracks for this pose bake.
 # Keep the armature's fixed native normalization in the node, animate bones only.
 path=OUT/(STEM+'.glb');raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
 gltf=json.loads(raw[20:20+length]);binary=raw[20+length:]
 for animation in gltf['animations']:
  animation['name']='ArenLanding3m_Baked'
  animation['channels']=[channel for channel in animation['channels'] if gltf['nodes'][channel['target']['node']].get('name')!='Aren_Baked_66']
 encoded=json.dumps(gltf,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
 path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+binary)
 baked.hide_render=True;baked.hide_set(True);proxy.hide_render=True;proxy.hide_set(True)
 return baked

if "--bake-only" in sys.argv:
 bake_native(bpy.data.objects["Aren_Native_66_Authoring"])
 print("EDITED BLEND BAKED; authoring file left untouched")
 raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.fbx(filepath=str(ROOT/'entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.name='Aren_Native_66_Authoring'
for obj in bpy.data.objects:obj.animation_data_clear()
reference=json.loads((AUTHOR/'reference_pose.json').read_text())
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def matrix(record):
 return Matrix(([*record[0],0],[*record[1],0],[*record[2],0],[*record[3],1])).transposed()
def to_bone(name):return name.replace('smartrig_','smartrig:')
records={to_bone(b['name']):b for b in reference['bones']}
assert len(rig.data.bones)==len(records)==66
# Align the original imported object to the game's existing height/centering.
source=[rig.matrix_world@b.head_local for b in rig.data.bones]
target=[(C@matrix(records[b.name]['rest'])).translation for b in rig.data.bones]
scale=sum((target[i]-target[0]).length for i in range(1,66))/sum((source[i]-source[0]).length for i in range(1,66))
translation=sum((target[i]-source[i]*scale for i in range(66)),Vector())/66
rig.matrix_world=Matrix.Translation(translation)@Matrix.Scale(scale,4)@rig.matrix_world
bpy.context.view_layer.update()
assert max((rig.matrix_world@b.head_local-target[i]).length for i,b in enumerate(rig.data.bones))<.0001
# Per-bone fixed rest-axis alignment only; there is no cross-rig retargeting.
rest_world={b.name:rig.matrix_world@b.matrix_local for b in rig.data.bones}
offsets={name:(C@matrix(r['rest'])).inverted()@rest_world[name] for name,r in records.items()}
def native_pose(which):
 return {name:rig.matrix_world.inverted()@(C@matrix(r[which]))@offsets[name] for name,r in records.items()}
neutral=native_pose('neutral');peak=native_pose('peak')
def locals_of(pose):
 return {b.name:(pose[b.parent.name].inverted()@pose[b.name] if b.parent else pose[b.name]) for b in rig.data.bones}
neutral_local=locals_of(neutral);peak_local=locals_of(peak)
def gb(v):return Vector((v[0],-v[2],v[1]))
def ctrl(name):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.empty_display_type='SPHERE';o.empty_display_size=.035;return o
controls={name:ctrl(name) for name in ['Foot_R','Foot_L','Palm_R','Hand_L','Knee_R','Knee_L','Elbow_R','Elbow_L']}
for side in ['Right','Left']:
 for limb,mid,end,control,pole in [('leg','Leg','Foot','Foot','Knee'),('arm','ForeArm','Hand','Palm' if side=='Right' else 'Hand','Elbow')]:
  suffix='R' if side=='Right' else 'L'
  pb=rig.pose.bones['smartrig:'+side+mid]
  ik=pb.constraints.new('IK');ik.name='Pilot_'+limb+'_contact';ik.target=controls[control+'_'+suffix];ik.pole_target=controls[pole+'_'+suffix];ik.chain_count=2;ik.use_stretch=False;ik.iterations=128
  # Pole angles will be calibrated from the actual solved bend at the peak.
  ik.pole_angle=0
  endpb=rig.pose.bones['smartrig:'+side+end]
  rotation=endpb.constraints.new('COPY_ROTATION');rotation.target=controls[control+'_'+suffix];rotation.owner_space='WORLD';rotation.target_space='WORLD';rotation.mix_mode='REPLACE'
# Eight atomic full-body pose decisions. Positions are in game metres (+Z forward).
# Support points stay fixed across impact/absorption/stabilization; the rear
# foot recovers before the forward foot. The knee remains unloaded.
poses=[
 dict(f=1,name='Air release',mix=.03,hip=(.004,.97,.061),feet=[(-.13,.18,.00),(.14,.18,.04)],hands=[(-.31,.95,.19),(.31,.98,.13)]),
 dict(f=17,name='Air preparation',mix=.25,hip=(.00,.84,.07),feet=[(-.13,.18,-.06),(.18,.15,.23)],hands=[(-.30,.78,.34),(.35,.82,.27)]),
 dict(f=37,name='Before contact',mix=.67,hip=(-.012,.56,.09),feet=[(-.13,.162,-.102),(.22,.1193,.50)],hands=[(-.235,.38,.484),(.40,.54,.40)]),
 dict(f=48,name='Physical impact',mix=.84,hip=(-.016,.43,.098),feet=[(-.13,.162,-.102),(.22,.1193,.50)],hands=[(-.235,.17,.484),(.43,.40,.36)]),
 dict(f=60,name='Impact absorption',mix=1.0,hip=tuple((C.inverted()@rig.matrix_world@peak['smartrig:Hips']).translation),feet=[(-.13,.161905,-.101787),(.22,.119274,.50)],hands=[(-.235032,.038729,.483892),(.46,.36,.31)]),
 dict(f=71,name='Brief stabilization',mix=.98,hip=(-.014,.383,.10),feet=[(-.13,.161905,-.101787),(.22,.119274,.50)],hands=[(-.235032,.038729,.483892),(.46,.37,.31)]),
 dict(f=104,name='Rise and hand withdrawal',mix=.30,hip=(-.003,.76,.07),feet=[(-.13,.1193,.0223),(.22,.119274,.50)],hands=[(-.28,.71,.20),(.31,.75,.25)]),
 dict(f=156,name='Recovered balance',mix=0.0,hip=tuple((C.inverted()@rig.matrix_world@neutral['smartrig:Hips']).translation),feet=[(-.131028,.119335,.022305),(.137825,.119274,.02230)],hands=[tuple((C.inverted()@rig.matrix_world@neutral['smartrig:RightHand']).translation),tuple((C.inverted()@rig.matrix_world@neutral['smartrig:LeftHand']).translation)]),
]
# Calibrate IK poles against the approved single pose, not arbitrary Euler axes.
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
def set_fk(pose):
 mix=pose['mix'];globals_={}
 for b in rig.data.bones:
  local=neutral_local[b.name].lerp(peak_local[b.name],mix)
  globals_[b.name]=(globals_[b.parent.name]@local if b.parent else local)
  rest_local=b.parent.matrix_local.inverted()@b.matrix_local if b.parent else b.matrix_local
  rig.pose.bones[b.name].matrix_basis=rest_local.inverted()@local
 hips=rig.pose.bones['smartrig:Hips'];m=globals_['smartrig:Hips'].copy();m.translation=rig.matrix_world.inverted()@gb(pose['hip']);hips.matrix_basis=rig.data.bones['smartrig:Hips'].matrix_local.inverted()@m
 bpy.context.view_layer.update()
def set_controls(pose):
 mix=pose['mix']
 for side,letter,index in [('Right','R',0),('Left','L',1)]:
  for name,bone,position in [('Foot','Foot',pose['feet'][index]),('Palm' if index==0 else 'Hand','Hand',pose['hands'][index])]:
   n='smartrig:'+side+bone
   orientation=1.0 if 37<=pose['f']<=71 and (name=='Foot' or name=='Palm') else mix
   if name=='Foot' and (side=='Left' or pose['f']>=104):orientation=0.0
   basis=(rig.matrix_world@neutral[n]).to_quaternion().slerp((rig.matrix_world@peak[n]).to_quaternion(),orientation)
   o=controls[name+'_'+letter];o.rotation_mode='QUATERNION';o.rotation_quaternion=basis;o.location=gb(position)
  controls['Knee_'+letter].location=gb((-.13 if index==0 else .25,.13,.85))
  controls['Elbow_'+letter].location=gb((-.75 if index==0 else .72,.35,.25))
 bpy.context.view_layer.update()
set_fk(poses[4]);set_controls(poses[4])
# Search each plane's pole angle using this single full-body reference pose.
for side in ['Right','Left']:
 for mid in ['Leg','ForeArm']:
  pb=rig.pose.bones['smartrig:'+side+mid];con=next(c for c in pb.constraints if c.type=='IK')
  desired=(rig.matrix_world@peak[pb.name]).translation
  if side=='Left' and mid=='ForeArm':desired=gb((.38,.56,.31))
  best=(1e9,0)
  for degree in range(-180,181,2):
   con.pole_angle=math.radians(degree);bpy.context.view_layer.update()
   point=rig.matrix_world@pb.head
   score=(point-desired).length_squared
   if score<best[0]:best=(score,con.pole_angle)
  con.pole_angle=best[1]
  print('POLE',pb.name,best)
# Set keys on all native bones and all controls together at each body pose.
for pose in poses:
 bpy.context.scene.frame_set(pose['f']);set_fk(pose);set_controls(pose)
 for pb in rig.pose.bones:
  for path in ['location','rotation_quaternion','scale']:pb.keyframe_insert(path,frame=pose['f'],group=pb.name)
 for o in controls.values():
  for path in ['location','rotation_quaternion']:o.keyframe_insert(path,frame=pose['f'])
 bpy.context.scene.timeline_markers.new(pose['name'],frame=pose['f'])
rig.animation_data.action.name='ArenLanding3m_EightWholePoses'
for action in bpy.data.actions:
 for curve in action.fcurves:
  for key in curve.keyframe_points:key.interpolation='BEZIER';key.handle_left_type='AUTO_CLAMPED';key.handle_right_type='AUTO_CLAMPED'
# Stabilization ends at rest: body and hands leave the support together.
for action in bpy.data.actions:
 for curve in action.fcurves:
  for key in curve.keyframe_points:
   if key.co.x==71:
    key.handle_right_type='FREE';key.handle_right.y=key.co.y
# Preserve ground contacts and use Bezier handles for the two recovery arcs.
for name,start,end in [('Foot_R',71,104),('Foot_L',104,156)]:
 curve=next(c for c in controls[name].animation_data.action.fcurves if c.data_path=='location' and c.array_index==2)
 a=next(k for k in curve.keyframe_points if k.co.x==start);b=next(k for k in curve.keyframe_points if k.co.x==end)
 a.handle_right_type='FREE';b.handle_left_type='FREE';a.handle_right=(start+(end-start)/3,a.co.y+.065);b.handle_left=(end-(end-start)/3,b.co.y+.065)
scene=bpy.context.scene;scene.render.fps=60;scene.frame_start=1;scene.frame_end=156
rig['pilot_scope']='3 m; eight authored whole-body poses; no mocap and no sampled procedural motion'
rig['contact_frames']='feet 48; palm 60-71; rear foot step 71-104; front step 104-156'
baked=bake_native(rig)
# Renderable authoring scene, retained inside the .blend for visual inspection.
mat=bpy.data.materials.new('PilotFloor');mat.diffuse_color=(.14,.18,.2,1)
bpy.ops.mesh.primitive_plane_add(size=20,location=(0,0,-.001));floor=bpy.context.object;floor.name='PilotGround';floor.data.materials.append(mat)
for name,location in [('Side',(3,-.05,1.05)),('Front',(.0,-3.2,1.1)),('Diagonal',(2.6,-3.2,1.5))]:
 bpy.ops.object.camera_add(location=location);camera=bpy.context.object;camera.name='Review_'+name;camera.rotation_euler=(Vector((0,-.15,.7))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.0
scene.camera=bpy.data.objects['Review_Diagonal'];scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.cycles.use_denoising=False
scene.world=bpy.data.worlds.new('PilotWorld');scene.world.color=(.25,.25,.25)
for location,power in [((2,-3,4),450),((-3,-1,2),250)]:
 bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=4;light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.frame_set(60)
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/'aren_landing_3m.blend'),compress=True)
print('PILOT_BAKED',len(rig.data.bones),'bones',len(poses),'whole poses',len(baked.animation_data.action.fcurves),'curves')
