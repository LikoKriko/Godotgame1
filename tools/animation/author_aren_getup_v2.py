"""New whole-body getup: 12 designed poses, using only allowed prone/Idle states.
CMU 140_01/140_02 are studied as references, never retargeted or sampled here.
--keys-only builds the editable blocking for validation before interpolation.
--bake-only exports the currently active manually edited Blender action.
"""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Matrix,Vector
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_native_export import export_native
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/characters/prototype_3d/generated/aren_getup_blender_v2'
FPS=60;DURATION=6.25;LAST=376
if '--bake-only' in sys.argv:
 export_native(bpy.data.objects['Aren_Native_66_Authoring'],OUT,'getup_v2',bpy.context.scene.frame_end,'ArenGetupV2_Baked')
 raise SystemExit(0)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/authoring/aren_landing_3m.blend'))
rig=bpy.data.objects['Aren_Native_66_Authoring'];scene=bpy.context.scene
# The new source has no preceding getup actions, curves, controls or trajectories.
for obj in list(bpy.data.objects):
 if obj.name in ['Aren_Baked_66','ExportSkin'] or obj.type=='EMPTY':bpy.data.objects.remove(obj,do_unlink=True)
 else:obj.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
for bone in rig.pose.bones:
 for constraint in list(bone.constraints):bone.constraints.remove(constraint)
for marker in list(scene.timeline_markers):scene.timeline_markers.remove(marker)
ref=json.loads((OUT/'authoring/endpoints.json').read_text());records={b['name']:b for b in ref['bones']}
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def matrix(rows):return Matrix(([*rows[0],0],[*rows[1],0],[*rows[2],0],[*rows[3],1])).transposed()
offsets={n:(C@matrix(r['rest'])).inverted()@rig.matrix_world@rig.data.bones[n].matrix_local for n,r in records.items()}
def bone_name(name):return name if name in rig.pose.bones else 'smartrig:'+name
def set_world(name,m):
 rig.pose.bones[bone_name(name)].matrix=rig.matrix_world.inverted()@m;bpy.context.view_layer.update()
def world(name):return (rig.matrix_world@rig.pose.bones[bone_name(name)].matrix).copy()
def state(key):
 for bone in rig.pose.bones:set_world(bone.name,C@matrix(records[bone.name][key])@offsets[bone.name])
 return {b.name:b.matrix_basis.copy() for b in rig.pose.bones},{b.name:(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones}
initial,initial_world=state('prone');neutral,neutral_world=state('idle')
assert len(initial)==66

def smooth(u):u=max(0,min(1,u));return u*u*u*(u*(6*u-15)+10)
def mix(a,b,u):return a+(b-a)*u
def gb(p):return Vector((p[0],-p[2],p[1]))
def game(p):return Vector((p.x,p.z,-p.y))
def apply(pose):
 for b in rig.pose.bones:b.matrix_basis=pose[b.name]
 bpy.context.view_layer.update()
def turn(name,axis,angle):
 m=world(name);p=m.translation.copy();m=Matrix.Rotation(math.radians(angle),4,axis)@m;m.translation=p;set_world(name,m)
def limb_frame(direction,normal):
 x=direction.normalized();z=normal.normalized();return Matrix((x,z.cross(x).normalized(),z)).transposed()
def solve(side,mid,end,target,pole,reference=None):
 rest=neutral_world if reference is None else reference
 middle=rig.pose.bones['smartrig:'+side+mid];first=middle.parent.name.split(':')[1]
 a=world(first).translation;b=world(side+mid).translation;c=world(side+end).translation
 la=(b-a).length;lb=(c-b).length;delta=target.translation-a;distance=delta.length
 if distance>la+lb+.0005:raise ValueError('Unreachable '+side+end+': '+str(distance)+' / '+str(la+lb)+' root '+str(tuple(game(a)))+' target '+str(tuple(game(target.translation))))
 d=max(.000001,min(distance,la+lb-.000001));axis=delta.normalized();normal=pole-a;normal-=axis*normal.dot(axis)
 assert normal.length>.00001,'Ambiguous joint plane'
 normal.normalize();along=(la*la-lb*lb+d*d)/(2*d);joint=a+axis*along+normal*math.sqrt(max(0,la*la-along*along))
 ra=rest['smartrig:'+first].translation;rb=rest['smartrig:'+side+mid].translation;rc=rest['smartrig:'+side+end].translation
 rn=(rb-ra).cross(rc-rb);nn=(joint-a).cross(target.translation-joint)
 for name,p,q,rp,rq in [(first,a,joint,ra,rb),(side+mid,joint,target.translation,rb,rc)]:
  orientation=limb_frame(q-p,nn)@limb_frame(rq-rp,rn).inverted()@rest['smartrig:'+name].to_3x3()
  set_world(name,Matrix.LocRotScale(p,orientation.to_quaternion(),world(name).to_scale()))
 m=world(side+end);set_world(side+end,Matrix.LocRotScale(m.translation,target.to_quaternion(),m.to_scale()))

def designed(t,label,height,pitch,spine,**kw):
 return dict(t=t,label=label,height=height,pitch=pitch,spine=spine,x=kw.get('x',0),z=kw.get('z',0),yaw=kw.get('yaw',0),roll=kw.get('roll',0),lead=kw.get('lead',0),neck=kw.get('neck',-8),knee=kw.get('knee',0),rknee=kw.get('rknee',0),hands=kw.get('hands',1),rhand=kw.get('rhand',kw.get('hands',1)),lhand=kw.get('lhand',kw.get('hands',1)),rfoot=kw.get('rfoot'),lfoot=kw.get('lfoot'),arm_open=kw.get('arm_open',[0,0]),rflat=kw.get('rflat',0),lflat=kw.get('lflat',0))
# Fresh full-body decisions, not samples/warps of an earlier getup.
POSES=[
 designed(0,'Prone approved endpoint',.137,90,[0,0,0]),
 designed(.7,'Palms close to chest; legs relaxed',.17,85,[0,0,0],lead=-1),
 designed(1.3,'Left arm leads chest lift',.20,65,[5,3,0],z=-.02,yaw=-4,lead=-5),
 designed(1.9,'Pelvis clears both extended legs',.46,90,[20,10,5],z=-.06,lead=-2,neck=-22),
 designed(2.4,'Both knees support; palms ready to unload',.42,75,[25,15,5],knee=1,rknee=1,hands=1,neck=-16),
 designed(3.2,'Tall kneel clears abdomen; hands free',.50,0,[2,1,0],knee=1,rknee=1,hands=0,arm_open=[6,6]),
 designed(3.85,'Right sole stable; left knee anchors',.50,10,[5,3,0],knee=1,hands=0,arm_open=[6,8],rfoot=[-.22,.1273,.25],rflat=1),
 designed(4.4,'Right leg lifts; left knee releases and foot advances',.68,10,[5,3,0],x=-.18,z=.17,hands=0,arm_open=[8,14],rfoot=[-.22,.1273,.25],rflat=1,lfoot=[.10,.28,-.05],lflat=.6),
 designed(4.95,'Both soles carry weight',.82,8,[10,8,4],x=-.05,z=-.03,hands=0,arm_open=[6,10],rfoot=[-.22,.1273,.25],rflat=1,lfoot=[.138,.1273,.022],lflat=1),
 designed(5.4,'Weight on left; right foot closes stance',.93,4,[2,1,0],x=.11,z=.05,roll=3,hands=0,arm_open=[4,6],rfoot=[-.185,.20,.13],rflat=1,lfoot=[.138,.1273,.022],lflat=1),
 designed(5.8,'Balanced stance; fast controlled final rise',.97,1,[1,0,0],x=.035,z=.06,hands=0,arm_open=[1,2],rfoot=[-.131,.1273,.0223],rflat=1,lfoot=[.138,.1273,.022],lflat=1),
 designed(6.25,'Approved Idle endpoint',.988,0,[0,0,0],hands=0),
]
KNEE=gb((.15,.043,.10))
flat_feet={s:neutral_world['smartrig:'+s+'Foot'].to_quaternion() for s in ['Right','Left']}
free_feet={s:initial_world['smartrig:'+s+'Foot'].to_quaternion() for s in ['Right','Left']}
flat_hands={s:initial_world['smartrig:'+s+'Hand'].to_quaternion() for s in ['Right','Left']}

def pose_at(p):
 if p['t']==0:apply(initial);return initial.copy()
 if p['t']>=DURATION:apply(neutral);return neutral.copy()
 apply(neutral)
 # Original native joint translations/scales, new coherent body orientations.
 q=(Matrix.Rotation(math.radians(p['roll']),4,'Y')@Matrix.Rotation(math.radians(p['yaw']),4,'Z')@Matrix.Rotation(math.radians(p['pitch']),4,'X')@neutral_world['smartrig:Hips']).to_quaternion()
 h=world('Hips');set_world('Hips',Matrix.LocRotScale(gb((p['x'],p['height'],p['z'])),q,h.to_scale()))
 if p['knee']>=.999999:
  root=world('LeftUpLeg').translation;leglen=(neutral_world['smartrig:LeftLeg'].translation-neutral_world['smartrig:LeftUpLeg'].translation).length
  delta=game(KNEE-root);squared=leglen*leglen-delta.x*delta.x-delta.y*delta.y
  assert squared>0 or p['knee']<.999,'Loaded knee unreachable at '+str(p['t'])
  if squared>0:
   desired_root_z=game(KNEE).z-math.sqrt(squared)
   h=world('Hips');h.translation.y-=(desired_root_z-game(root).z)*p['knee'];set_world('Hips',h)
 for n,a in zip(['Spine','Spine1','Spine2'],p['spine']):turn(n,'X',a)
 for n in ['Spine','Spine1']:turn(n,'Z',-p['yaw']*.22)
 turn('Spine2','Y',p['lead']);turn('Neck','X',p['neck']*(1-smooth((p['t']-3.85)/2)))
 # Return from the allowed side-facing prone head gradually, not by a snap.
 head=rig.pose.bones['smartrig:Head'];a,qa,sa=initial['smartrig:Head'].decompose();b,qb,sb=neutral['smartrig:Head'].decompose()
 head.matrix_basis=Matrix.LocRotScale(b,qa.slerp(qb,smooth(p['t']/1.9)),sb);bpy.context.view_layer.update()
 for side,i,sign in [('Right',0,-1),('Left',1,1)]:
  root=world(side+'UpLeg').translation;mid=world(side+'Leg').translation;foot=world(side+'Foot').translation
  total=(mid-root).length+(foot-mid).length;rg=game(root);dx=sign*.06;dy=.061-rg.y
  passive=root+gb((dx,dy,-math.sqrt(max(.001,(total*.997)**2-dx*dx-dy*dy))))
  goal=gb(p['rfoot'] if i==0 else p['lfoot']) if (p['rfoot'] if i==0 else p['lfoot']) is not None else passive
  pole=gb((game(goal).x,p['height']-.15,.75))
  support_knee=p['rknee'] if i==0 else p['knee']
  if support_knee>0:
   contact=gb((sign*.15,.043,.10))
   calf=(neutral_world['smartrig:LeftFoot'].translation-neutral_world['smartrig:LeftLeg'].translation).length
   dy=.061-game(contact).y
   kneel_foot=contact+gb((0,dy,-math.sqrt(calf*calf-dy*dy)))
   if not p.get('_baked_goals',False):goal=goal.lerp(kneel_foot,support_knee)
   pole=pole.lerp(contact,support_knee)
  target=world(side+'Foot');target.translation=goal
  target=Matrix.LocRotScale(goal,free_feet[side].slerp(flat_feet[side],p['rflat'] if i==0 else p['lflat']),target.to_scale())
  solve(side,'Leg','Foot',target,pole)
 # Open/relaxed fingers come exclusively from the two allowed endpoint states.
 for b in rig.pose.bones:
  ancestor=b.parent
  while ancestor and not ancestor.name.endswith('Hand'):ancestor=ancestor.parent
  if ancestor:
   a,qa,sa=initial[b.name].decompose();c,qc,sc=neutral[b.name].decompose()
   relax=smooth((p['t']-2.4)/.80)
   b.matrix_basis=Matrix.LocRotScale(c,qa.slerp(qc,relax),sc)
 bpy.context.view_layer.update()
 for side,sign in [('Right',-1),('Left',1)]:
  turn(side+'Arm','Y',-sign*p['arm_open'][0 if side=='Right' else 1])
  support=p['rhand' if side=='Right' else 'lhand']
  free=world(side+'Hand');goal=gb((sign*.24,.045,.25)).lerp(free.translation,1-support)
  relax=smooth((p['t']-2.4)/.80)
  target=Matrix.LocRotScale(goal,flat_hands[side].slerp(free.to_quaternion(),relax),free.to_scale())
  root=world(side+'Arm').translation;axis=(goal-root).normalized()
  support_radial=gb((sign*.55,.20,.12))-root;support_radial-=axis*support_radial.dot(axis)
  free_radial=world(side+'ForeArm').translation-root;free_radial-=axis*free_radial.dot(axis)
  pole=root+support_radial.normalized().slerp(free_radial.normalized(),relax)*.3
  solve(side,'ForeArm','Hand',target,pole)
 return {b.name:b.matrix_basis.copy() for b in rig.pose.bones}

def write_action(name,items):
 action=bpy.data.actions.new(name);rig.animation_data_create();rig.animation_data.action=action;previous={}
 for frame,pose in items:
  scene.frame_set(frame)
  for b in rig.pose.bones:
   b.matrix_basis=pose[b.name];q=b.rotation_quaternion.copy()
   if b.name in previous and q.dot(previous[b.name])<0:q.negate()
   b.rotation_quaternion=q;previous[b.name]=q
   for path in ['location','rotation_quaternion','scale']:b.keyframe_insert(path,frame=frame,group=b.name)
 for fc in action.fcurves:
  for key in fc.keyframe_points:key.interpolation='LINEAR'
 action.use_fake_user=True;return action
# Blocking is produced and checked before any intermediate animation is built.
keys=[]
for p in POSES:
 pose=pose_at(p);keys.append((round(1+p['t']*FPS),pose));print('KEY',p['label'],[round(x,3) for x in game(world('Hips').translation)])
key_action=write_action('ArenGetupV2_TwelveWholeBodyPoses',keys)
scene.frame_start=1;scene.frame_end=LAST;scene.render.fps=FPS
for p in POSES:scene.timeline_markers.new(p['label'],frame=round(1+p['t']*FPS))
rig['whole_body_keys']=[f for f,_ in keys];rig['source_policy']='Only allowed prone/Idle endpoints; no old getup curves, poses or trajectories'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'authoring').mkdir(exist_ok=True);(OUT/'authoring/.gdignore').touch()
(OUT/'authoring/poses.json').write_text(json.dumps(POSES,indent=2)+'\n')
# A separate --animate pass is deliberately required after blocking validation.
if '--animate' in sys.argv:
 def monotone(t,times,values):
  # Shape-preserving cubic: flowing body motion without overshooting contacts.
  secants=[(b-a)/(tb-ta) for a,b,ta,tb in zip(values,values[1:],times,times[1:])]
  slopes=[secants[0]]
  for i in range(1,len(values)-1):
   left,right=secants[i-1:i+1];h0=times[i]-times[i-1];h1=times[i+1]-times[i]
   slopes.append(0 if left*right<=0 else (3*(h0+h1))/((2*h1+h0)/left+(h1+2*h0)/right))
  slopes.append(secants[-1])
  for i in range(len(times)-1):
   if t<=times[i+1]:
    h=times[i+1]-times[i];u=max(0,min(1,(t-times[i])/h))
    return (2*u**3-3*u*u+1)*values[i]+(u**3-2*u*u+u)*h*slopes[i]+(-2*u**3+3*u*u)*values[i+1]+(u**3-u*u)*h*slopes[i+1]
  return values[-1]
 def interpolate(t):
  times=[p['t'] for p in POSES];r={'t':t,'label':'baked','_baked_goals':True}
  for k in POSES[0]:
   if k in ['t','label']:continue
   if k in ['rfoot','lfoot']:
    side='Right' if k=='rfoot' else 'Left'
    values=[list(game(w['smartrig:'+side+'Foot'].translation)) for w in key_worlds]
    r[k]=[monotone(t,times,[v[i] for v in values]) for i in range(3)]
   elif isinstance(POSES[0][k],list):r[k]=[monotone(t,times,[p[k][i] for p in POSES]) for i in range(len(POSES[0][k]))]
   else:r[k]=monotone(t,times,[p[k] for p in POSES])
  r['z']=monotone(t,times,[game(w['smartrig:Hips'].translation).z for w in key_worlds])
  if t<=1.9:r['rfoot']=r['lfoot']=None
  if 3.2<t<3.85:
   arc=math.sin(math.pi*(t-3.2)/.65)**2;r['rfoot'][1]+=.22*arc;r['rfoot'][0]-=.10*arc
  if 3.85<t<4.4:r['lfoot'][1]+=.08*math.sin(math.pi*(t-3.85)/.55)**2
  # Both knees take the load before hands leave; release precedes chest rise.
  if t>=2.4:
   r['hands']=r['rhand']=r['lhand']=1-smooth((t-2.4)/.45)
  return r
 def pose_mix(a,b,u):
  result={}
  for name in a:
   pa,qa,sa=a[name].decompose();pb,qb,sb=b[name].decompose()
   result[name]=Matrix.LocRotScale(pa.lerp(pb,u),qa.slerp(qb,u),sa.lerp(sb,u))
  apply(result);return result
 key_worlds=[]
 for p in POSES:
  pose_at(p);key_worlds.append({b.name:(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones})
 result=[]
 for f in range(1,LAST+1):
  t=(f-1)/FPS
  if t==0:pose=initial.copy()
  elif t<.7:
   u=smooth(t/.7);pose=pose_mix(initial,keys[1][1],u)
   # Unloaded palm placement clears the floor before taking body weight.
   reference={b.name:(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones}
   for side in ['Right','Left']:
    hu=smooth((t-.36)/.34) if side=='Right' else smooth(t/.34)
    target=world(side+'Hand');start=initial_world['smartrig:'+side+'Hand'].translation;end=key_worlds[1]['smartrig:'+side+'Hand'].translation
    target=Matrix.LocRotScale(start.lerp(end,hu)+Vector((0,0,.035*math.sin(math.pi*hu)**2)),flat_hands[side],target.to_scale())
    pole=initial_world['smartrig:'+side+'ForeArm'].translation.lerp(key_worlds[1]['smartrig:'+side+'ForeArm'].translation,hu)+Vector((0,0,.025*math.sin(math.pi*hu)**2))
    solve(side,'ForeArm','Hand',target,pole,reference)
   pose={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
  elif t>5.8:
   u=smooth((t-5.8)/.45);pose=pose_mix(keys[-2][1],neutral,u)
   for side in ['Right','Left']:
    target=world(side+'Foot');start=key_worlds[-2]['smartrig:'+side+'Foot'];end=neutral_world['smartrig:'+side+'Foot']
    target.translation=start.translation.lerp(end.translation,u)
    solve(side,'Leg','Foot',target,world(side+'Leg').translation)
   pose={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
  else:pose=pose_at(interpolate(t))
  result.append((f,pose))
 write_action('ArenGetupV2_ContactBaked',result)
 export_native(rig,OUT,'getup_v2',LAST,'ArenGetupV2_Baked')
(OUT/'timing.json').write_text(json.dumps({'fps':FPS,'frames':LAST,'duration':DURATION,'keys':[f for f,_ in keys],
 'contacts':{'palms':[.7,.34],'palm_release':[2.4,2.4+1/60],'palm_exit':[2.4,2.85],'feet':[3.85,4.95],'foot_swings':[[4.95,5.8],[99,100]],'final_settle':[5.8,6.25],'left_knee':[2.4,3.85],'right_knee':[2.4,3.2]},
 'references':['https://github.com/una-dinosauria/cmu-mocap/blob/master/data/140/140_01.bvh','https://github.com/una-dinosauria/cmu-mocap/blob/master/data/140/140_02.bvh']},indent=2)+'\n')
scene.frame_set(133);bpy.context.preferences.filepaths.save_version=0
rig.hide_set(False);bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_getup_v2.blend'),compress=True)
print('NEW GETUP: 12 independently designed poses; duration',DURATION,'; keys only', '--animate' not in sys.argv)
