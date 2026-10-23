"""Edit only the existing 653c927f getup, using its complete Blender poses.
Left arm leads; right sole lands before left leg folds; final 1 s becomes .3 s.
Run on aren_extreme.blend. Retains an immutable source action for repeatability.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Matrix, Vector
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_native_export import export_native
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/characters/prototype_3d/generated/aren_extreme_blender_v1'
rig=bpy.data.objects['Aren_Native_66_Authoring'];scene=bpy.context.scene
BASE='ArenExtreme_SupportBase_653c927f';ACTIVE='ArenExtreme_SequentialSupport_WholeBodyPoses'
base=bpy.data.actions.get(BASE)
if base is None:
 base=rig.animation_data.action
 assert base.name=='ArenExtreme_SlowGetup_WholeBodyPoses'
 base.name=BASE
base.use_fake_user=True;rig.animation_data.action=base
assert len(rig.data.bones)==66 and scene.frame_end==625
for bone in rig.pose.bones:
 for constraint in bone.constraints:assert constraint.mute

def smooth(u):
 u=max(0,min(1,u));return u*u*u*(u*(6*u-15)+10)
def blend(t,a,b):return smooth((t-a)/(b-a))
def gb(p):return Vector((p[0],-p[2],p[1]))
def game(p):return Vector((p.x,p.z,-p.y))
def sample(t):
 f=145+max(0,min(8,t))*60;scene.frame_set(int(f),subframe=f-int(f))
 return ({b.name:b.matrix_basis.copy() for b in rig.pose.bones},
         {b.name:(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones})
def apply(pose):
 for b in rig.pose.bones:b.matrix_basis=pose[b.name]
 bpy.context.view_layer.update()
def world(name):return (rig.matrix_world@rig.pose.bones['smartrig:'+name].matrix).copy()
def put(name,m):
 rig.pose.bones['smartrig:'+name].matrix=rig.matrix_world.inverted()@m
 bpy.context.view_layer.update()
def turn(name,axis,angle):
 m=world(name);origin=m.translation.copy();m=Matrix.Rotation(angle,4,axis)@m;m.translation=origin;put(name,m)
def solve(side,mid,end,target,pole):
 middle=rig.pose.bones['smartrig:'+side+mid];first=middle.parent.name.split(':')[1]
 a=world(first).translation;b=world(side+mid).translation;c=world(side+end).translation
 la=(b-a).length;lb=(c-b).length;axis=(target.translation-a).normalized()
 d=min((target.translation-a).length,la+lb-.000001);d=max(.000001,d)
 normal=pole-a;normal-=axis*normal.dot(axis);normal.normalize()
 along=(la*la-lb*lb+d*d)/(2*d)
 joint=a+axis*along+normal*math.sqrt(max(0,la*la-along*along))
 if mid=='Leg':
  # Calibrate axial orientation from the original Idle joint plane. Retaining
  # the old bent-leg twist would introduce fast counter-rotations at the ankle.
  ra=neutral_world['smartrig:'+first].translation
  rb=neutral_world['smartrig:'+side+mid].translation
  rc=neutral_world['smartrig:'+side+end].translation
  rn=(rb-ra).cross(rc-rb);nn=(joint-a).cross(target.translation-joint)
  def frame(direction,normal):
   x=direction.normalized();z=normal.normalized();y=z.cross(x).normalized()
   return Matrix((x,y,z)).transposed()
  for name,p,q,rp,rq in [(first,a,joint,ra,rb),(side+mid,joint,target.translation,rb,rc)]:
   reference=neutral_world['smartrig:'+name]
   canonical=frame(q-p,nn)@frame(rq-rp,rn).inverted()@reference.to_3x3()
   old=world(name);old_direction=world(side+mid).translation-a if name==first else world(side+end).translation-joint
   aligned=(old_direction.rotation_difference(q-p).to_matrix()@old.to_3x3()).to_quaternion()
   orientation=aligned.slerp(canonical.to_quaternion(),blend(t,0,.6))
   put(name,Matrix.LocRotScale(p,orientation,old.to_scale()))
 else:
  m=world(first);m=Matrix.Translation(a)@(b-a).rotation_difference(joint-a).to_matrix().to_4x4()@Matrix.Translation(-a)@m;put(first,m)
  b=world(side+mid).translation;c=world(side+end).translation
  m=world(side+mid);m=Matrix.Translation(b)@(c-b).rotation_difference(target.translation-b).to_matrix().to_4x4()@Matrix.Translation(-b)@m;put(side+mid,m)
 m=world(side+end);put(side+end,Matrix.LocRotScale(m.translation,target.to_quaternion(),m.to_scale()))

def monotone(t,points):
 """Monotone Hermite time mapping: no stops at intermediate pose markers."""
 x=[v[0] for v in points];y=[v[1] for v in points]
 d=[(y[i+1]-y[i])/(x[i+1]-x[i]) for i in range(len(x)-1)]
 slopes=[d[0]]+[0 if d[i-1]*d[i]<=0 else 2/(1/d[i-1]+1/d[i]) for i in range(1,len(d))]+[d[-1]]
 i=next((i for i in range(len(d)) if t<=x[i+1]),len(d)-1)
 u=max(0,min(1,(t-x[i])/(x[i+1]-x[i])));h=x[i+1]-x[i]
 return (2*u**3-3*u*u+1)*y[i]+(u**3-2*u*u+u)*h*slopes[i]+(-2*u**3+3*u*u)*y[i+1]+(u**3-u*u)*h*slopes[i+1]
body_clock=[(0,0),(.6,.6),(1.5,2.4),(3.1,2.8),(4.85,3.2),(5.3,3.35),(5.9,4.3),(6.5,5.0),(7,5.8),(7.7,7),(8,8)]
# Sample input before writing any output. All poses/paths come from this source.
sources={f:sample((f-145)/60) for f in range(145,626)}
neutral,neutral_world=sample(8)
flat={side:neutral_world['smartrig:'+side+'Foot'].to_quaternion() for side in ['Right','Left']}
prone_world=sample(0)[1]
prone_feet={side:prone_world['smartrig:'+side+'Foot'].to_quaternion() for side in ['Right','Left']}
hand_goals={side:sample(.6)[1]['smartrig:'+side+'Hand'].copy() for side in ['Right','Left']}
for goal in hand_goals.values():goal.translation.y-=.15
# Output contact events in elapsed getup seconds, also consumed by review IK.
contacts={'palms':[.6,26/60],'palm_release':[5.0,5.6],'feet':[3.1,4.85],
          'foot_swings':[[6.8,7.4],[6.05,6.65]],'final_settle':[7.7,8.0],
          'leg_starts':[1.1,3.25]}
arc_start=sample(.6)[1];arc_end=sample(2.4)[1]
output={}
for frame in range(1,626):
 t=(frame-145)/60
 if frame<=145:
  scene.frame_set(frame);output[frame]={b.name:b.matrix_basis.copy() for b in rig.pose.bones};continue
 bt=monotone(t,body_clock);pose,original=sample(bt)
 progress=[blend(t,contacts['leg_starts'][i],contacts['feet'][i]) for i in range(2)]
 arcs=[sample(.6+1.8*u)[1] for u in progress]
 hand_time=t if t<=.6 else monotone(t,[(.6,.6),(5,3.2),(5.6,3.55),(6.3,4.6),(7.7,7),(8,8)])
 hand_time=hand_time+(bt-hand_time)*blend(t,5.6,5.9)
 _,hand_source=sample(hand_time)
 apply(pose)
 # Preserve the source's whole-body extension. Lift the pelvis before folding
 # a thigh, and let the chest remain reachable from the supporting palms.
 envelope=blend(t,.55,1.5)*(1-blend(t,5.0,5.7))
 hip=world('Hips');p=game(hip.translation)
 p.y+=.165*envelope;p.x+=.025*math.sin(math.pi*blend(t,.6,4.85))*envelope
 hip.translation=gb(p);put('Hips',hip)
 h=world('Hips').translation;c=world('Spine2').translation;v=game(c-h)
 target_height=min(c.z,.385)
 desired=max(-.6,min(.6,(target_height-h.z)/v.length))
 chest_support=blend(t,.55,1.5)*(1-blend(t,5.4,6.0))
 pitch=(math.atan2(v.y,v.z)-math.asin(desired))*chest_support
 turn('Hips','X',pitch)
 # Open the hip crease and move mass over the fixed palms. Counter the pelvic
 # change through the existing spine, keeping chest height within arm reach.
 chest_height=world('Spine2').translation.z
 turn('Hips','X',-math.radians(20)*envelope)
 turn('Spine','X',math.radians(14)*envelope);turn('Spine1','X',math.radians(6)*envelope)
 shifted=world('Hips');shifted.translation.z-=world('Spine2').translation.z-chest_height
 advance=blend(t,.55,1.5)*(1-blend(t,5.25,6.3))
 shifted.translation.y-=.4*advance;put('Hips',shifted)
 yaw=math.radians(8)*envelope*math.sin(math.pi*blend(t,.65,5.2))
 turn('Hips','Z',yaw)
 turn('Hips','Y',math.radians(-3)*envelope*(1-blend(t,2.5,4.9)))
 # Left shoulder leads; right shoulder initially stays lower as a stabilizer.
 turn('Spine2','Y',math.radians(-7)*blend(t,.6,1.1)*(1-blend(t,1.2,2.2)))
 turn('Spine','Z',-yaw*.15);turn('Spine1','Z',-yaw*.15)
 for side,index,sign in [('Right',0,-1),('Left',1,1)]:
  root=world(side+'UpLeg').translation
  knee=world(side+'Leg').translation;ankle=world(side+'Foot').translation
  length=(knee-root).length+(ankle-knee).length
  rg=game(root);dx=sign*.10;dy=.14-rg.y
  dz=-math.sqrt(max(.01,(length*.997)**2-dx*dx-dy*dy))
  passive=root+gb((dx,dy,dz))
  start=contacts['leg_starts'][index];plant=contacts['feet'][index];u=progress[index]
  destination=gb((sign*.28,.119,.035 if index==0 else .055))
  goal=arcs[index]['smartrig:'+side+'Foot'].translation.copy()
  goal+=(passive-arc_start['smartrig:'+side+'Foot'].translation)*(1-u)+(destination-arc_end['smartrig:'+side+'Foot'].translation)*u
  if t>=plant:goal=destination.copy()
  elif t>=start:goal.z=max(goal.z,.119+.13*math.sin(math.pi*u))
  if t<start:
   initial=sources[145][1]['smartrig:'+side+'Foot'].translation
   goal=initial.lerp(passive,blend(t,0,.6))
  swing_a,swing_b=contacts['foot_swings'][index]
  if t>=swing_a:
   # Preserve the final cleanup step after the transfer of weight.
   step=blend(t,swing_a,swing_b)
   goal=destination.lerp(neutral_world['smartrig:'+side+'Foot'].translation,step)
   goal.z+=.057*math.sin(math.pi*step)
  # Keep the knee over the sole under load, rather than rolling the shin
  # sideways and forcing the ankle into eversion.
  pole=gb((sign*.30,p.y+.25,.10))
  pole=sources[frame][1]['smartrig:'+side+'Leg'].translation.lerp(pole,blend(t,0,.6))
  pole=pole.lerp(original['smartrig:'+side+'Leg'].translation,blend(t,5.7,7.7))
  target=world(side+'Foot');target.translation=goal
  solve(side,'Leg','Foot',target,pole)
  free=prone_feet[side]
  q=free.slerp(flat[side],blend(u,.35,.95))
  if t>=plant:q=flat[side]
  if t<.6:q=sources[frame][1]['smartrig:'+side+'Foot'].to_quaternion().slerp(q,blend(t,0,.6))
  target=world(side+'Foot');put(side+'Foot',Matrix.LocRotScale(target.translation,q,target.to_scale()))
 for side,sign in [('Right',-1),('Left',1)]:
  goal=hand_source['smartrig:'+side+'Hand'].copy()
  if t<=.6:goal.translation.y-=.15*blend(t,0,contacts['palms'][0 if side=='Right' else 1])
  if t>.6:
   goal.translation.y-=.4*advance
   goal.translation=hand_goals[side].translation.lerp(goal.translation,blend(t,*contacts['palm_release']))
   goal=Matrix.LocRotScale(goal.translation,hand_goals[side].to_quaternion().slerp(goal.to_quaternion(),blend(t,*contacts['palm_release'])),goal.to_scale())
  shoulder=game(world(side+'Arm').translation)
  pole=gb((sign*.70,max(.10,shoulder.y-.18),.32))
  pole=pole.lerp(hand_source['smartrig:'+side+'ForeArm'].translation,blend(t,5.7,7.7))
  solve(side,'ForeArm','Hand',goal,pole)
 result={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
 # Retain original finger and toe channels, and the exact approved Idle endpoint.
 for name in result:
  if 'Toe' in name:result[name]=pose[name].copy()
  if t>=7.7:
   a,qa,sa=result[name].decompose();b,qb,sb=pose[name].decompose();u=blend(t,7.7,8)
   result[name]=Matrix.LocRotScale(a.lerp(b,u),qa.slerp(qb,u),sa.lerp(sb,u))
 output[frame]=result
old=bpy.data.actions.get(ACTIVE)
if old:bpy.data.actions.remove(old)
action=bpy.data.actions.new(ACTIVE);rig.animation_data.action=action
previous={}
for frame,pose in output.items():
 scene.frame_set(frame)
 for bone in rig.pose.bones:
  bone.matrix_basis=pose[bone.name]
  q=bone.rotation_quaternion.copy()
  if bone.name in previous and q.dot(previous[bone.name])<0:q.negate()
  bone.rotation_quaternion=q;previous[bone.name]=q
  for path in ['location','rotation_quaternion','scale']:bone.keyframe_insert(path,frame=frame,group=bone.name)
for fc in action.fcurves:
 for key in fc.keyframe_points:key.interpolation='LINEAR'
rig['whole_body_keys']=list(range(1,626));rig['phase_frames']=[1,34,78,109,145,625]
rig['refinement']='653c927f getup only: left-arm lead, right sole before left fold, neutral loaded feet, .3 s final settle'
# Remove only getup markers; keep all four earlier phases and their labels.
for marker in list(scene.timeline_markers):
 if marker.frame>145:scene.timeline_markers.remove(marker)
for name,t in [('Left palm stable',26/60),('Both palms stable',.6),('Left arm leads push',.9),('Right leg advances',1.1),('Right sole planted',3.1),('Left leg advances',3.25),('Both soles planted',4.85),('Palms unload',5),('Palms released',5.6),('Final settle .3 s',7.7),('Approved Idle',8)]:
 scene.timeline_markers.new(name,frame=round(145+t*60))
timing=json.loads((OUT/'timing.json').read_text())
for key in ['getup_time_scale','getup_previous_duration','pelvis_yaw_degrees','torso_yaw_fraction']:timing.pop(key,None)
timing.update(keys=list(range(1,626)),getup_contacts=contacts,getup_support_profile='sequential',final_settle_duration=.3,
              right_foot_start=2.4+1.1,left_foot_start=2.4+3.25,feet=2.4+4.85,leg_load=2.4+4.85,
              palms=3.0,left_palm=2.4+26/60,torso_align=7.6,torso_forward=7.6)
(OUT/'timing.json').write_text(json.dumps(timing,indent=2)+'\n')
for old in list(bpy.data.actions):
 if old.name.startswith('ArenExtreme_Baked'):bpy.data.actions.remove(old)
baked=export_native(rig,OUT,'extreme',625,'ArenExtreme_Baked')
for old in list(bpy.data.actions):
 if old.users==0 and old not in [base,action,baked.animation_data.action]:bpy.data.actions.remove(old)
scene.frame_set(265);bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_extreme.blend'),compress=True)
print('SEQUENTIAL SUPPORT: getup 8 s; first four phases fixed; final second -> .3 s')
