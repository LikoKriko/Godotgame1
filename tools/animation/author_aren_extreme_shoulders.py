"""Fresh shoulder-led first phase on Aren's original Blender rig.
Run on aren_extreme.blend; no prior arm samples/curves feed frames 1..34.
The existing full body is retained, with a C1 arm-only bridge in 35..45.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_native_export import export_native
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/characters/prototype_3d/generated/aren_extreme_blender_v1'
rig=bpy.data.objects['Aren_Native_66_Authoring'];scene=bpy.context.scene
bpy.context.preferences.filepaths.save_version=0
BASE='ArenExtreme_BodyBase_fc492dc8';ACTIVE='ArenExtreme_ShoulderCircles_WholeBodyPoses'
base=bpy.data.actions.get(BASE)
if base is None:
 base=rig.animation_data.action
 assert base.name=='ArenExtreme_Refined_WholeBodyPoses', 'Open the fc492dc8 authoring source'
 base.name=BASE
base.use_fake_user=True;rig.animation_data.action=base
for pb in rig.pose.bones:
 for con in pb.constraints:con.mute=True
NAMES={side:['smartrig:'+side+part for part in ['Shoulder','Arm','ForeArm','Hand']] for side in ['Right','Left']}
ARMS={n for names in NAMES.values() for n in names}
BODY={b.name for b in rig.data.bones}-ARMS
# Copy the approved body and later phases. Deliberately exclude every old arm
# channel during phase 1, rather than reducing or blending previous movement.
samples={}
for f in range(1,386):
 scene.frame_set(f)
 samples[f]={b.name:b.matrix_basis.copy() for b in rig.pose.bones if f>34 or b.name in BODY}
rest_world={b.name:rig.matrix_world@b.matrix_local for b in rig.data.bones}
spine='smartrig:Spine2'

def update():bpy.context.view_layer.update()
def apply(pose):
 for name,mat in pose.items():rig.pose.bones[name].matrix_basis=mat
 update()
def world(name):return rig.matrix_world@rig.pose.bones[name].matrix

def set_rotation(name,q):
 pb=rig.pose.bones[name];mat=world(name)
 pb.matrix=rig.matrix_world.inverted()@Matrix.LocRotScale(mat.translation,q,mat.to_scale())
 update()
def bone_axis(name):
 pb=rig.pose.bones[name]
 return (rig.matrix_world.to_3x3()@(pb.tail-pb.head)).normalized()
def fresh_pose(frame):
 apply({n:samples[frame][n] for n in BODY})
 for name in ARMS:
  pb=rig.pose.bones[name];pb.matrix_basis=Matrix.Identity(4)
  if name.endswith('Hand'):pb.scale=Vector((.9,.9,.9)) # Approved native hand proportion.
 update()
 body_delta=world(spine).to_quaternion()@rest_world[spine].to_quaternion().inverted()
 for side,sign,lag in [('Right',-1,0),('Left',1,.45)]:
  clavicle,upper,forearm,wrist=NAMES[side]
  phase=-.60*math.pi+2*math.pi*(frame-1)/33+lag
  # Small scapular accompaniment; glenohumeral circumduction drives the arc.
  q=Quaternion(body_delta@Vector((0,-sign,0)),math.radians(1.8)*math.sin(phase))
  q=Quaternion(body_delta@Vector((0,0,1)),sign*math.radians(1.4)*math.cos(phase))@q
  set_rotation(clavicle,q@world(clavicle).to_quaternion())
  axis=Vector((sign*math.sin(math.radians(47)),-.12,-math.cos(math.radians(47)))).normalized()
  front=Vector((0,-1,0));a=(front-axis*front.dot(axis)).normalized()
  # Mirror the anatomical circle plane so .45 rad is a small bilateral lag,
  # rather than making the arms rise and fall in opposite half-cycles.
  b=-sign*axis.cross(a).normalized()
  radius=math.radians(15)
  direction=(axis*math.cos(radius)+(a*math.cos(phase)+b*math.sin(phase))*math.sin(radius)).normalized()
  rest_axis=(rest_world[forearm].translation-rest_world[upper].translation).normalized()
  aim=(body_delta@rest_axis).rotation_difference(body_delta@direction)
  set_rotation(upper,aim@body_delta@rest_world[upper].to_quaternion())
  # The elbow is a passive, almost rigid 20-degree bend carried by the shoulder.
  # Its native hinge plane follows the humerus; it never chases a hand target.
  u=bone_axis(upper);bend=aim@body_delta@front
  bend=(bend-u*bend.dot(u)).normalized()
  flex=math.radians(20+1.2*math.sin(phase+.7))
  target=(u*math.cos(flex)+bend*math.sin(flex)).normalized()
  delta=bone_axis(forearm).rotation_difference(target)
  set_rotation(forearm,delta@world(forearm).to_quaternion())
  # Rest wrist, constant local orientation: no independent wrist animation.
  rig.pose.bones[wrist].rotation_quaternion=Quaternion()
  update()
 return {pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones}

fresh={f:fresh_pose(f) for f in range(1,35)}
START=34;JOIN=46;SPAN=JOIN-START

def bezier(a,b,c,d,t):
 ab=a.slerp(b,t);bc=b.slerp(c,t);cd=c.slerp(d,t)
 return ab.slerp(bc,t).slerp(bc.slerp(cd,t),t)
def delta_vector(q,other):
 delta=q.inverted()@other
 if delta.w<0:delta.negate()
 return delta.to_exponential_map()
bridge={}
for name in ARMS:
 q0=fresh[START][name].to_quaternion();q1=samples[JOIN][name].to_quaternion()
 v0=-delta_vector(q0,fresh[START-1][name].to_quaternion())
 v1=delta_vector(q1,samples[JOIN+1][name].to_quaternion())
 # Match the actual baked angular velocities on both sides of the seam.
 # The first and last bridge samples mirror their adjacent approved samples.
 a=q0@Quaternion(v0);d=q1@Quaternion(-v1);inner=SPAN-2
 bridge[name]=(a,a@Quaternion(v0*inner/3),d@Quaternion(-v1*inner/3),d)
 print('JOIN',name,'angle',round(math.degrees(q0.rotation_difference(q1).angle),2))
result={}
for f in range(1,386):
 if f<=START:pose=fresh[f]
 else:
  pose={n:m.copy() for n,m in samples[f].items()}
  if f<JOIN:
   t=(f-START-1)/(SPAN-2)
   for name in ARMS:
    pos,_,scale=pose[name].decompose()
    pose[name]=Matrix.LocRotScale(pos,bezier(*bridge[name],t),scale)
 result[f]=pose
# Confirm the fixed elbow range and constant local wrist before baking.
for f in range(1,35):
 apply(result[f])
 for side in NAMES:
  _,upper,forearm,wrist=NAMES[side]
  angle=math.degrees(bone_axis(upper).angle(bone_axis(forearm)))
  assert 15<=angle<=25, 'First-phase elbow must remain gently flexed'
  assert rig.pose.bones[wrist].rotation_quaternion.angle<.00001
for f,pose in result.items():
 for name,mat in pose.items():
  if name in BODY or f>=JOIN:
   assert max(abs(mat[i][j]-samples[f][name][i][j]) for i in range(4) for j in range(4))<.000005, 'Edit escaped the arms/entry bridge'
old=bpy.data.actions.get(ACTIVE)
if old:bpy.data.actions.remove(old)
action=bpy.data.actions.new(ACTIVE);rig.animation_data.action=action
previous={}
for frame,pose in result.items():
 scene.frame_set(frame)
 for pb in rig.pose.bones:
  pb.matrix_basis=pose[pb.name];q=pb.rotation_quaternion.copy()
  if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
  pb.rotation_quaternion=q;previous[pb.name]=q
  for path in ['location','rotation_quaternion','scale']:pb.keyframe_insert(path,frame=frame,group=pb.name)
for curve in action.fcurves:
 for key in curve.keyframe_points:key.interpolation='LINEAR'
rig['refinement']='Fresh native shoulder circles 1-34; passive 20-degree elbows; fixed wrists; C1 arm-only entry 35-45'
rig['whole_body_keys']=list(range(1,386))
for old in list(bpy.data.actions):
 if old.name.startswith('ArenExtreme_Baked'):bpy.data.actions.remove(old)
baked=export_native(rig,OUT,'extreme',385,'ArenExtreme_Baked')
for old in list(bpy.data.actions):
 if old.users==0 and old not in [base,action,baked.animation_data.action]:bpy.data.actions.remove(old)
timing=json.loads((OUT/'timing.json').read_text())
timing.update(arm_authoring='fresh shoulder FK; no prior phase-one arm curves',arm_phase_frames=[1,34],arm_join_frame=JOIN,elbow_degrees=[18.8,21.2],shoulder_cone_degrees=15,arm_phase_offset_radians=.45)
(OUT/'timing.json').write_text(json.dumps(timing,indent=2)+'\n')
for name,frame in [('New shoulder circles',1),('Arm-only entry bridge',34),('Original arms restored',JOIN)]:
 marker=scene.timeline_markers.get(name)
 if marker:marker.frame=frame
 else:scene.timeline_markers.new(name,frame=frame)
scene.frame_set(17)
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_extreme.blend'),compress=True)
print('FRESH SHOULDER ARMS BAKED: original 66-bone rig; body and later phases preserved')
