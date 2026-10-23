"""Blender 4.3: complete native-rig poses for the review-only extreme fall.
Reuse the pilot rig, reference, contact controls and native glTF bake workflow.
Run: blender -b -t 4 --python tools/animation/author_aren_extreme_blender.py
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion
ROOT=Path(__file__).resolve().parents[2]
PILOT=ROOT/'assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1'
OUT=ROOT/'assets/characters/prototype_3d/generated/aren_extreme_blender_v1'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'authoring').mkdir(exist_ok=True)
(OUT/'authoring/.gdignore').touch()
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_native_export import export_native
if '--bake-only' in sys.argv:
 export_native(bpy.data.objects['Aren_Native_66_Authoring'],OUT,'extreme',385,'ArenExtreme_Baked')
 print('EDITED EXTREME BAKED; authoring blend left untouched')
 raise SystemExit(0)
bpy.ops.wm.open_mainfile(filepath=str(PILOT/'authoring/aren_landing_3m.blend'))
bpy.context.preferences.filepaths.save_version=0
for marker in list(bpy.context.scene.timeline_markers):bpy.context.scene.timeline_markers.remove(marker)
rig=bpy.data.objects['Aren_Native_66_Authoring'];rig.hide_set(False)
# Retain the source rig/skin, discarding only copied pilot animation and controls.
for obj in list(bpy.data.objects):
 if obj.name in ['Aren_Baked_66','ExportSkin']:bpy.data.objects.remove(obj,do_unlink=True)
for obj in bpy.data.objects:
 obj.animation_data_clear()
for bone in rig.pose.bones:
 for constraint in list(bone.constraints):bone.constraints.remove(constraint)
ref=json.loads((PILOT/'authoring/reference_pose.json').read_text())
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def matrix(r):return Matrix(([*r[0],0],[*r[1],0],[*r[2],0],[*r[3],1])).transposed()
records={b['name'].replace('smartrig_','smartrig:'):b for b in ref['bones']}
offsets={n:(C@matrix(r['rest'])).inverted()@rig.matrix_world@rig.data.bones[n].matrix_local for n,r in records.items()}
neutral={n:rig.matrix_world.inverted()@C@matrix(r['neutral'])@offsets[n] for n,r in records.items()}
def locals_of(pose):return {b.name:pose[b.parent.name].inverted()@pose[b.name] if b.parent else pose[b.name] for b in rig.data.bones}
neutral_local=locals_of(neutral)
peak={n:rig.matrix_world.inverted()@C@matrix(r['peak'])@offsets[n] for n,r in records.items()}
peak_local=locals_of(peak)
# Reuse the pilot's complete open-palm finger pose, mirrored anatomically for
# the other hand. Keep each original local translation/bone length unchanged.
D=Matrix.Diagonal(Vector((-1,1,1,1)))
left_open={}
for bone in rig.data.bones:
 if not bone.name.startswith('smartrig:Left'):continue
 right=bone.name.replace('Left','Right',1)
 if right not in records:continue
 align=(D@matrix(records[right]['rest'])).inverted()@matrix(records[bone.name]['rest'])
 left_open[bone.name]=rig.matrix_world.inverted()@C@D@matrix(records[right]['peak'])@align@offsets[bone.name]
open_fingers={}
for bone in rig.data.bones:
 ancestor=bone.parent
 while ancestor and not ancestor.name.endswith('Hand'):ancestor=ancestor.parent
 if not ancestor:continue
 if bone.name.startswith('smartrig:Right'):local=peak_local[bone.name].copy()
 else:local=left_open[bone.parent.name].inverted()@left_open[bone.name]
 local.translation=neutral_local[bone.name].translation
 open_fingers[bone.name]=local
right_flat=(rig.matrix_world@peak['smartrig:RightHand']).to_quaternion()
right_idle=(rig.matrix_world@neutral['smartrig:RightHand']).to_quaternion()
flat_delta=(right_flat@right_idle.inverted()).to_matrix()
mirror=Matrix.Diagonal(Vector((-1,1,1)))
left_flat=(mirror@flat_delta@mirror).to_quaternion()@(rig.matrix_world@neutral['smartrig:LeftHand']).to_quaternion()
def gb(v):return Vector((v[0],-v[2],v[1]))
controls={}
for name in ['Foot_R','Foot_L','Palm_R','Hand_L','Knee_R','Knee_L','Elbow_R','Elbow_L']:
 obj=bpy.data.objects.get(name);obj.rotation_mode='QUATERNION';controls[name]=obj
for side,letter in [('Right','R'),('Left','L')]:
 for mid,end,ctrl,pole in [('Leg','Foot','Foot','Knee'),('ForeArm','Hand','Palm' if letter=='R' else 'Hand','Elbow')]:
  bone=rig.pose.bones['smartrig:'+side+mid]
  con=bone.constraints.new('IK');con.name='Extreme_contact';con.target=controls[ctrl+'_'+letter];con.pole_target=controls[pole+'_'+letter];con.chain_count=2;con.use_stretch=False;con.iterations=128
  con=rig.pose.bones['smartrig:'+side+end].constraints.new('COPY_ROTATION');con.target=controls[ctrl+'_'+letter];con.owner_space='WORLD';con.target_space='WORLD'
# Atomic whole-body decisions. Positions are game metres (+Y up, +Z forward).
# The airborne body is root-motion-free; gameplay ballistics will own translation.
# Complete coordinated decisions, in game metres (+Y up, +Z forward).
poses=[
 dict(f=1,label='Loss of support',tilt=0,hip=(0.004, 0.987, 0.061),feet=[(-0.131, 0.119, 0.022), (0.138, 0.119, 0.022)],hands=[(-0.267, 0.895, 0.058), (0.268, 0.895, 0.058)]),
 dict(f=9,label='Alarm reach R',tilt=2,hip=(0, 0.97, 0.05),feet=[(-0.14, 0.2, 0.13), (0.14, 0.11, -0.08)],hands=[(-0.4, 1.17, 0.35), (0.42, 1.35, -0.22)],roll=-3),
 dict(f=19,label='Alternating balance L',tilt=-3,hip=(0, 0.98, 0.05),feet=[(-0.15, 0.1, -0.08), (0.15, 0.25, 0.15)],hands=[(-0.42, 1.57, 0.08), (0.43, 0.87, 0)],roll=4),
 dict(f=28,label='Balance circle R',tilt=3,hip=(0, 0.97, 0.05),feet=[(-0.14, 0.25, 0.18), (0.14, 0.12, -0.1)],hands=[(-0.43, 1.12, -0.28), (0.43, 1.2, 0.33)],roll=-3),
 dict(f=34,label='19 percent descent - begin forward tilt',tilt=3,hip=(0, 0.97, 0.05),feet=[(-0.15, 0.18, 0.1), (0.15, 0.2, 0.02)],hands=[(-0.46, 0.9, 0.12), (0.44, 1.5, 0.1)]),
 dict(f=46,label='Whole-body forward loss',tilt=35,hip=(0, 0.86, 0.05),feet=[(-0.16, 0.28, -0.33), (0.17, 0.42, -0.12)],hands=[(-0.46, 0.9, 0.55), (0.49, 0.85, 0.32)],roll=3),
 dict(f=58,label='Horizontal approach',tilt=66,hip=(0, 0.72, 0.02),feet=[(-0.17, 0.48, -0.53), (0.16, 0.58, -0.32)],hands=[(-0.44, 0.63, 0.64), (0.44, 0.55, 0.4)],roll=-2),
 dict(f=70,label='Brace for body impact',tilt=86,hip=(0, 0.36, 0),feet=[(-0.18, 0.28, -0.68), (0.19, 0.28, -0.65)],hands=[(-0.42, 0.16, 0.56), (0.43, 0.18, 0.54)]),
 dict(f=78,label='Physical impact',tilt=88,hip=(0, 0.1, 0),feet=[(-0.19, 0.12, -0.82), (0.2, 0.12, -0.8)],hands=[(-0.42, 0.045, 0.54), (0.43, 0.045, 0.53)]),
 dict(f=81,label='Compression',tilt=90,hip=(0, 0.07, 0),feet=[(-0.2, 0.12, -0.82), (0.21, 0.12, -0.8)],hands=[(-0.43, 0.04, 0.54), (0.44, 0.04, 0.53)],spine=3),
 dict(f=85,label='Damped whole-body rebound',tilt=86,hip=(0, 0.15, -0.006),feet=[(-0.2, 0.18, -0.82), (0.21, 0.18, -0.8)],hands=[(-0.43, 0.085, 0.54), (0.44, 0.085, 0.53)],spine=-2),
 dict(f=91,label='Rebound absorbed',tilt=90,hip=(0, 0.085, 0),feet=[(-0.2, 0.12, -0.82), (0.21, 0.12, -0.8)],hands=[(-0.44, 0.04, 0.52), (0.45, 0.04, 0.51)]),
 dict(f=100,label='Limbs settle',tilt=90,hip=(0, 0.075, 0),feet=[(-0.23, 0.12, -0.82), (0.24, 0.12, -0.8)],hands=[(-0.48, 0.04, 0.48), (0.49, 0.04, 0.47)]),
 dict(f=109,label='Prone rest',tilt=90,hip=(0, 0.075, 0),feet=[(-0.24, 0.12, -0.82), (0.25, 0.12, -0.8)],hands=[(-0.49, 0.04, 0.47), (0.5, 0.04, 0.46)]),
 dict(f=145,label='Survival decision - begin getup',tilt=90,hip=(0, 0.075, 0),feet=[(-0.24, 0.12, -0.82), (0.25, 0.12, -0.8)],hands=[(-0.49, 0.04, 0.47), (0.5, 0.04, 0.46)]),
 dict(f=154,label='Hand placement arc',tilt=88,hip=(0, 0.08, 0),feet=[(-0.24, 0.12, -0.82), (0.25, 0.12, -0.8)],hands=[(-0.4, 0.09, 0.435), (0.41, 0.09, 0.43)]),
 dict(f=163,label='Both palms planted',tilt=86,hip=(0, 0.09000000000000001, 0),feet=[(-0.23, 0.12, -0.82), (0.24, 0.12, -0.8)],hands=[(-0.31, 0.04, 0.4), (0.32, 0.04, 0.4)]),
 dict(f=175,label='Feet placement begins +0.20s',tilt=82,hip=(0, 0.11, 0),feet=[(-0.22, 0.12, -0.82), (0.23, 0.12, -0.8)],hands=[(-0.31, 0.04, 0.4), (0.32, 0.04, 0.4)]),
 dict(f=196,label='Arm-led chest push',tilt=75,hip=(0, 0.28, -0.03),feet=[(-0.21, 0.17, -0.35), (0.22, 0.17, -0.34)],hands=[(-0.31, 0.04, 0.4), (0.32, 0.04, 0.4)],spine=-5),
 dict(f=217,label='Soles under body',tilt=80,hip=(0, 0.36, -0.04),feet=[(-0.22, 0.119, 0.0), (0.23, 0.119, 0.02)],hands=[(-0.31, 0.04, 0.4), (0.32, 0.04, 0.4)],spine=-4),
 dict(f=241,label='40 percent getup - leg load',tilt=80,hip=(0, 0.385, -0.03),feet=[(-0.22, 0.119, 0.0), (0.23, 0.119, 0.02)],hands=[(-0.31, 0.05, 0.4), (0.32, 0.05, 0.4)]),
 dict(f=271,label='Hands unload',tilt=20,hip=(0, 0.71, -0.02),feet=[(-0.22, 0.119, 0.0), (0.23, 0.119, 0.02)],hands=[(-0.35, 0.25, 0.35), (0.36, 0.25, 0.35)]),
 dict(f=295,label='Left foot recovery arc',tilt=12,hip=(0, 0.83, 0),feet=[(-0.22, 0.119, 0), (0.16, 0.18, 0.03)],hands=[(-0.33, 0.55, 0.2), (0.34, 0.55, 0.2)]),
 dict(f=307,label='Heavy hip and knee extension',tilt=9,hip=(0, 0.88, 0.01),feet=[(-0.22, 0.119, 0), (0.138, 0.119, 0.022)],hands=[(-0.32, 0.62, 0.17), (0.33, 0.62, 0.17)]),
 dict(f=319,label='Right foot recovery arc',tilt=7,hip=(0, 0.91, 0.02),feet=[(-0.16, 0.18, 0.025), (0.138, 0.119, 0.022)],hands=[(-0.31, 0.71, 0.13), (0.32, 0.71, 0.13)]),
 dict(f=343,label='Recover neutral balance',tilt=2,hip=(0.004, 0.97, 0.05),feet=[(-0.131, 0.119, 0.022), (0.138, 0.119, 0.022)],hands=[(-0.28, 0.85, 0.08), (0.28, 0.85, 0.08)]),
 dict(f=385,label='Approved Idle',tilt=0,hip=(0.004, 0.987265, 0.060904),feet=[(-0.131, 0.119, 0.022), (0.138, 0.119, 0.022)],hands=[(-0.267, 0.895, 0.058), (0.268, 0.895, 0.058)]),
]
# Root/torso FK and four simultaneous contact targets define each whole pose.
def set_pose(p):
 for bone in rig.data.bones:
  local=open_fingers.get(bone.name,neutral_local[bone.name]) if 70<=p['f']<=271 else neutral_local[bone.name]
  rest=bone.parent.matrix_local.inverted()@bone.matrix_local if bone.parent else bone.matrix_local
  rig.pose.bones[bone.name].matrix_basis=rest.inverted()@local
 hips=rig.pose.bones['smartrig:Hips']
 world=rig.matrix_world@neutral[hips.name]
 rotation=Matrix.Rotation(math.radians(p['tilt']),4,'X')@Matrix.Rotation(math.radians(p.get('roll',0)),4,'Y')
 world=rotation@world;world.translation=gb(p['hip'])
 hips.matrix=rig.matrix_world.inverted()@world
 for name in ['Spine','Spine1','Spine2']:
  bone=rig.pose.bones['smartrig:'+name]
  bone.rotation_quaternion=Quaternion((1,0,0),math.radians(p.get('spine',0)/3))@bone.rotation_quaternion
 if 78<=p['f']<=241:
  head=rig.pose.bones['smartrig:Head']
  turn=70*max(0,1-max(0,p['f']-175)/66)
  head.rotation_quaternion=Quaternion((1,0,0),math.radians(-30*turn/70))@Quaternion((0,1,0),math.radians(turn))@head.rotation_quaternion
 for side,letter,i in [('Right','R',0),('Left','L',1)]:
  if p['f']<70:
   flex={1:0,9:8,19:-6,28:4,34:0,46:-6,58:4}.get(p['f'],0)*(1 if i==0 else -1)
   wrist=rig.pose.bones['smartrig:'+side+'Hand']
   wrist.rotation_quaternion=Quaternion((1,0,0),math.radians(flex))@wrist.rotation_quaternion
  for con in rig.pose.bones['smartrig:'+side+'Hand'].constraints:
   con.influence=1.0 if 70<=p['f']<=241 else 0.0
  for name,end,points in [('Foot','Foot',p['feet']),('Palm' if i==0 else 'Hand','Hand',p['hands'])]:
   obj=controls[name+'_'+letter];obj.location=gb(points[i])
   q=(rig.matrix_world@neutral['smartrig:'+side+end]).to_quaternion()
   # Upright support soles; prone feet follow the leg rather than twisting ankles.
   turn=min(140,p['tilt']*1.6) if p['f']<78 else (140 if p['f']<196 else 0)
   if name=='Foot':obj.rotation_quaternion=Quaternion((1,0,0),math.radians(turn))@q
   elif 70<=p['f']<=241:obj.rotation_quaternion=right_flat if i==0 else left_flat
   else:obj.rotation_quaternion=Quaternion((1,0,0),math.radians(min(p['tilt'],75)))@q
  sign=-1 if i==0 else 1
  controls['Knee_'+letter].location=gb((sign*.30,p['hip'][1]-.2,p['hip'][2]+.6))
  controls['Elbow_'+letter].location=gb((sign*.75,max(.10,p['hip'][1]),p['hip'][2]+.35))
 bpy.context.view_layer.update()
# Calibrate native IK bend planes from the existing rig at each full-pose key.
# Keyed pole angles prevent solver-dependent limb flips; there is no game retarget.
previous_angles={}
whole_snapshots={}
for p in poses:
 bpy.context.scene.frame_set(p['f']);set_pose(p)
 for side,letter in [('Right','R'),('Left','L')]:
  for mid,pole in [('Leg','Knee'),('ForeArm','Elbow')]:
   bone=rig.pose.bones['smartrig:'+side+mid];con=next(c for c in bone.constraints if c.type=='IK')
   desired=controls[pole+'_'+letter].location
   best=(1e9,previous_angles.get((side,mid),0))
   if (side,mid) not in previous_angles:
    for degree in range(-180,180,6):
     con.pole_angle=math.radians(degree);bpy.context.view_layer.update()
     score=((rig.matrix_world@bone.head)-desired).length_squared
     if score<best[0]:best=(score,con.pole_angle)
   angle=best[1]
   # Unwrap keyed angular channels to take the shortest route between poses.
   previous=previous_angles.get((side,mid),angle)
   while angle-previous>math.pi:angle-=2*math.pi
   while angle-previous< -math.pi:angle+=2*math.pi
   con.pole_angle=angle;previous_angles[side,mid]=angle;con.keyframe_insert('pole_angle',frame=p['f'])
 bpy.context.view_layer.update()
 evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
 whole_snapshots[p['f']]={bone.name:bone.matrix.copy() for bone in evaluated.pose.bones}
 for bone in rig.pose.bones:
  for path in ['location','rotation_quaternion','scale']:bone.keyframe_insert(path,frame=p['f'],group=bone.name)
 for obj in controls.values():
  for path in ['location','rotation_quaternion']:obj.keyframe_insert(path,frame=p['f'])
 bpy.context.scene.timeline_markers.new(p['label'],frame=p['f'])
# Freeze the solved whole poses as editable FK keys. Continuous IK can flip
# at an arm singularity between keys; the exported body must interpolate full
# poses instead. Godot retains the existing contact IK for support adaptation.
rig.animation_data.action.use_fake_user=True
rig.animation_data.action=bpy.data.actions.new('ArenExtreme_WholePoses_FK')
for bone in rig.pose.bones:
 for con in bone.constraints:con.mute=True
previous_quaternions={}
for p in poses:
 scene=bpy.context.scene;scene.frame_set(p['f']);snapshot=whole_snapshots[p['f']]
 for bone in rig.data.bones:
  local=snapshot[bone.parent.name].inverted()@snapshot[bone.name] if bone.parent else snapshot[bone.name]
  rest=bone.parent.matrix_local.inverted()@bone.matrix_local if bone.parent else bone.matrix_local
  pb=rig.pose.bones[bone.name];pb.matrix_basis=rest.inverted()@local
  q=pb.rotation_quaternion.copy()
  if bone.name in previous_quaternions and q.dot(previous_quaternions[bone.name])<0:q.negate()
  pb.rotation_quaternion=q;previous_quaternions[bone.name]=q
  for path in ['location','rotation_quaternion','scale']:pb.keyframe_insert(path,frame=p['f'],group=bone.name)
for action in bpy.data.actions:
 for curve in action.fcurves:
  for key in curve.keyframe_points:key.interpolation='BEZIER';key.handle_left_type=key.handle_right_type='AUTO_CLAMPED'
scene=bpy.context.scene;scene.render.fps=60;scene.frame_start=1;scene.frame_end=385
rig.animation_data.action.name='ArenExtreme_WholeBodyPoses'
rig['scope']='Review only; automatic >=8m; all five phases; approved 66-bone rig'
rig['whole_body_keys']=[p['f'] for p in poses]
rig['phase_frames']=[1,34,78,109,145,385]
# Same fixed native-joint bake/export as the approved pilot.
baked=export_native(rig,OUT,'extreme',385,'ArenExtreme_Baked')
scene.frame_set(109)
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_extreme.blend'),compress=True)
(OUT/'timing.json').write_text(json.dumps({'fps':60,'frames':385,'keys':[p['f'] for p in poses],'tilt_start':33/60,'impact':77/60,'prone':108/60,'getup':144/60,'palms':162/60,'feet':174/60,'leg_load':240/60,'end':384/60},indent=2)+'\n')
print('EXTREME_BAKED',len(rig.data.bones),'bones;',len(poses),'complete poses')
