"""Targeted whole-pose edit of the 9dcd03ed extreme-fall Blender source.
Run on authoring/aren_extreme.blend. Retains the base action for repeatable edits;
only arm branches in frames 2..33 and the getup in 155..240 are corrected.
Use --coordination to retime only the b91fb769 getup; all earlier phases stay fixed.
No skeleton, mesh, weights, toe channels, total duration or gameplay changes.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Matrix
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_native_export import export_native
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/characters/prototype_3d/generated/aren_extreme_blender_v1'
rig=bpy.data.objects['Aren_Native_66_Authoring']
scene=bpy.context.scene
bpy.context.preferences.filepaths.save_version=0
coordination='--coordination' in sys.argv
BASE='ArenExtreme_GetupBase_b91fb769' if coordination else 'ArenExtreme_Base_9dcd03ed'
base=bpy.data.actions.get(BASE)
if base is None:
 base=rig.animation_data.action
 expected='ArenExtreme_Refined_WholeBodyPoses' if coordination else 'ArenExtreme_WholeBodyPoses'
 assert base.name==expected, 'Open the matching extreme authoring blend'
base.name=BASE
base.use_fake_user=True
rig.animation_data.action=base
for bone in rig.pose.bones:
 for con in bone.constraints:con.mute=True

def sample(frame):
 scene.frame_set(int(frame),subframe=frame-int(frame))
 return {b.name:b.matrix_basis.copy() for b in rig.pose.bones}, {b.name:(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones}
# All inputs come from the retained complete-pose action, never the last output.
samples={f:sample(f) for f in range(1,386)}
def smooth(u):
 u=max(0,min(1,u));return u*u*u*(u*(u*6-15)+10)
def curve(frame,keys):
 for (a,x),(b,y) in zip(keys,keys[1:]):
  if frame<=b:return x+(y-x)*smooth((frame-a)/(b-a))
 return keys[-1][1]
def apply_basis(pose):
 for b in rig.pose.bones:b.matrix_basis=pose[b.name]
 bpy.context.view_layer.update()
def set_world(name,world):
 rig.pose.bones[name].matrix=rig.matrix_world.inverted()@world
 bpy.context.view_layer.update()
def rotate_world(name,angle):
 world=rig.matrix_world@rig.pose.bones[name].matrix
 p=world.translation.copy();world=Matrix.Rotation(math.radians(angle),4,'Z')@world;world.translation=p
 set_world(name,world)
def point_world(name):return (rig.matrix_world@rig.pose.bones[name].matrix).translation.copy()

def solve_chain(side,mid,end,target,pole,lock_orientation=True,keep_plane=False):
 """Fixed-length two-bone pose edit in Blender, retaining the bend plane.
 Whole-pose goals include planted wrists, sequential feet, pelvis and spine.
 The solver uses the existing knee/elbow plane, not independent angle curves.
 """
 middle=rig.pose.bones['smartrig:'+side+mid]
 first=middle.parent
 last=rig.pose.bones['smartrig:'+side+end]
 a=point_world(first.name);b=point_world(middle.name);c=point_world(last.name)
 goal=target.translation
 length1=(b-a).length;length2=(c-b).length
 delta=goal-a;distance=max(.000001,min(delta.length,length1+length2-.000001))
 axis=delta.normalized()
 if keep_plane:
  old_axis=(c-a).normalized()
  bend=(b-a)-old_axis*(b-a).dot(old_axis)
  bend=old_axis.rotation_difference(axis)@bend
 else:bend=pole-a
 normal=bend-axis*bend.dot(axis)
 if normal.length<.00001:normal=(b-a)-axis*(b-a).dot(axis)
 normal.normalize()
 along=(length1*length1-length2*length2+distance*distance)/(2*distance)
 knee=a+axis*along+normal*math.sqrt(max(0,length1*length1-along*along))
 # Rotate at the existing joint heads; preserve local translations and lengths.
 world=rig.matrix_world@first.matrix
 q=(b-a).rotation_difference(knee-a)
 world=Matrix.Translation(a)@q.to_matrix().to_4x4()@Matrix.Translation(-a)@world
 set_world(first.name,world)
 b=point_world(middle.name);c=point_world(last.name)
 world=rig.matrix_world@middle.matrix
 q=(c-b).rotation_difference(goal-b)
 world=Matrix.Translation(b)@q.to_matrix().to_4x4()@Matrix.Translation(-b)@world
 set_world(middle.name,world)
 if lock_orientation:
  world=rig.matrix_world@last.matrix
  world=Matrix.LocRotScale(world.translation,target.to_quaternion(),world.to_scale())
  set_world(last.name,world)

right_keys=[(145,0),(154,0),(163,12),(175,8),(190,7),(205,3),(217,0)]
left_keys=[(145,0),(163,0),(170,6),(184,4),(200,3),(217,0)]
yaw_keys=[(145,0),(154,0),(163,3),(175,8),(190,11),(205,7),(217,3),(241,0)]
# Relative timing edits of the current whole-pose getup. The right leg, body
# rise, peak yaw and all endpoint poses remain on their existing clocks.
left_delay=[(145,0),(156,0),(174,-6),(190,-6),(205,-3),(217,0)]
push_yaw=[(145,0),(158,0),(169,5),(190,11),(205,7),(217,3),(241,0)]
torso_follow=[(145,.46),(190,.46),(205,.62),(217,.90),(229,1),(241,1)]
def coordinate_getup(frame,pose,world):
 # Advance the existing left-hand placement arc from 18 to 13 frames. The
 # same palm destination is then held until the original bilateral support.
 hand_time=145+(frame-145)*18/13 if frame<158 else (163 if frame<163 else frame)
 if frame<163:
  hand_basis,hand_world=sample(hand_time)
  left_hand=hand_world['smartrig:LeftHand'].copy()
  left_elbow=hand_world['smartrig:LeftForeArm'].translation.copy()
  pose['smartrig:LeftShoulder']=hand_basis['smartrig:LeftShoulder'].copy()
 else:
  left_hand=world['smartrig:LeftHand'].copy()
  left_elbow=world['smartrig:LeftForeArm'].translation.copy()
 _,left_world=sample(frame+curve(frame,left_delay))
 apply_basis(pose)
 old_yaw=curve(frame,yaw_keys);new_yaw=curve(frame,push_yaw)
 rotate_world('smartrig:Hips',new_yaw-old_yaw)
 # Counter only the relative yaw. Spine curvature and extension stay authored.
 # While the palms still push, progressively remove the counter-rotation so
 # torso and pelvis align before both finish facing forward at frame 241.
 torso_delta=new_yaw*curve(frame,torso_follow)-old_yaw*.46-(new_yaw-old_yaw)
 for spine in ['Spine','Spine1','Spine2']:rotate_world('smartrig:'+spine,torso_delta/3)
 for side,goal,pole in [
  ('Right',world['smartrig:RightFoot'],world['smartrig:RightLeg'].translation),
  ('Left',left_world['smartrig:LeftFoot'],left_world['smartrig:LeftLeg'].translation)]:
  solve_chain(side,'Leg','Foot',goal,pole)
 solve_chain('Right','ForeArm','Hand',world['smartrig:RightHand'],world['smartrig:RightForeArm'].translation)
 solve_chain('Left','ForeArm','Hand',left_hand,left_elbow)

result={}
assert len(rig.data.bones)==66
for frame in range(1,386):
 original,world=samples[frame]
 pose={n:m.copy() for n,m in original.items()}
 apply_basis(pose)
 if not coordination and 1<frame<34:
  u=(frame-1)/33
  _,slower=sample(frame-2.2*math.sin(math.pi*u))
  apply_basis(pose)
  envelope=math.sin(math.pi*u)
  for side in ['Right','Left']:
   hand='smartrig:'+side+'Hand';elbow='smartrig:'+side+'ForeArm'
   guide=samples[1][1][hand].translation.lerp(samples[34][1][hand].translation,smooth(u))
   closed=slower[hand].translation.lerp(guide,.55*envelope)
   target=world[hand].copy();target.translation=world[hand].translation.lerp(closed,envelope)
   pole=world[elbow].translation
   # Edit the coordinated shoulder/elbow/wrist pose through a closed hand arc.
   # Free wrists retain their local authored flex instead of world locking.
   solve_chain(side,'ForeArm','Hand',target,pole,False,True)
 if not coordination and 154<frame<241:
  yaw=curve(frame,yaw_keys)
  # Upper torso follows 46% of the pelvic yaw; curvature stays authored.
  for side,keys in [('Right',right_keys),('Left',left_keys)]:
   time=frame+curve(frame,keys)
   _,shifted=sample(time)
   # Sampling changes scene evaluation; restore this complete pose before IK.
   # Save the coordinated root/torso pose rather than reusing sampled transforms.
   if side=='Right':
    apply_basis(pose);rotate_world('smartrig:Hips',yaw)
    for spine in ['Spine','Spine1','Spine2']:rotate_world('smartrig:'+spine,-yaw*.18)
   else:apply_basis(partial)
   solve_chain(side,'Leg','Foot',shifted['smartrig:'+side+'Foot'],shifted['smartrig:'+side+'Leg'].translation)
   partial={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
  # Keep the approved world-space palm trajectories and orientations while
  # accommodating the new pelvic/torso coordination with the original arms.
  for side in ['Right','Left']:
   solve_chain(side,'ForeArm','Hand',world['smartrig:'+side+'Hand'],world['smartrig:'+side+'ForeArm'].translation)
 if coordination and 145<frame<241:coordinate_getup(frame,pose,world)
 pose={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
 # No animation of toes is introduced by this refinement.
 for n in pose:
  if 'Toe' in n:pose[n]=original[n].copy()
 result[frame]=pose

# Integrity guards against accidentally editing the rig or an approved phase.
arm_branches=set()
for side in ['Right','Left']:
 root=rig.data.bones['smartrig:'+side+'Shoulder']
 arm_branches.add(root.name);arm_branches.update(b.name for b in root.children_recursive)
for frame,pose in result.items():
 for name,mat in pose.items():
  source=samples[frame][0][name]
  assert (mat.translation-source.translation).length<.00001, 'Native joint translation changed'
  preserve=(not (145<frame<241) or 'Toe' in name) if coordination else (not (1<frame<34 or 154<frame<241) or 'Toe' in name or (frame<34 and name not in arm_branches))
  if preserve:assert max(abs(mat[i][j]-source[i][j]) for i in range(4) for j in range(4))<.000005, 'Edit escaped its phase/branch'
# Preserve approved interpolation outside the edited intervals. Dense FK keys
# are the authored whole-pose result, with linear interpolation as in the bake.
for old in list(bpy.data.actions):
 if old.name.startswith('ArenExtreme_Refined_WholeBodyPoses'):bpy.data.actions.remove(old)
action=bpy.data.actions.new('ArenExtreme_Refined_WholeBodyPoses')
rig.animation_data.action=action
previous={}
for frame,pose in result.items():
 scene.frame_set(frame)
 for bone in rig.pose.bones:
  bone.matrix_basis=pose[bone.name]
  q=bone.rotation_quaternion.copy()
  if bone.name in previous and q.dot(previous[bone.name])<0:q.negate()
  bone.rotation_quaternion=q;previous[bone.name]=q
  for path in ['location','rotation_quaternion','scale']:bone.keyframe_insert(path,frame=frame,group=bone.name)
for fc in action.fcurves:
 for key in fc.keyframe_points:key.interpolation='LINEAR'
rig['refinement']='b91fb769: getup timing only; left palm earlier; overlapping right/left legs; progressive torso alignment' if coordination else '9dcd03ed: reduced balance arm circles; right-led overlapping getup; fixed native rig/toes'
rig['whole_body_keys']=list(range(1,386))
# Remove previous generated exports, retaining the source and base actions.
for old in list(bpy.data.actions):
 if old.name.startswith('ArenExtreme_Baked'):bpy.data.actions.remove(old)
baked=export_native(rig,OUT,'extreme',385,'ArenExtreme_Baked')
for old in list(bpy.data.actions):
 if old.users==0 and old not in [base,action,baked.animation_data.action]:bpy.data.actions.remove(old)
timing=json.loads((OUT/'timing.json').read_text())
timing.update(keys=list(range(1,386)),feet=162/60,right_foot_start=162/60,left_foot_start=168/60,pelvis_yaw_degrees=11,torso_yaw_fraction=.46)
if coordination:timing.update(left_palm=157/60,left_foot_start=174/60,torso_align=228/60,torso_forward=240/60)
else:
 for key in ['left_palm','torso_align','torso_forward']:timing.pop(key,None)
(OUT/'timing.json').write_text(json.dumps(timing,indent=2)+'\n')
# Markers describe the revised coordination without moving phase boundaries.
for marker in scene.timeline_markers:
 if marker.name=='Both palms planted':marker.name='Palms planted; right leg begins'
 if marker.name=='Feet placement begins +0.20s':marker.name='Overlapping leg advance'
for name,frame in [('Left leg follows',169),('Pelvis yaw peak',190)]:
 marker=scene.timeline_markers.get(name)
 if marker:marker.frame=frame
 else:scene.timeline_markers.new(name,frame=frame)
if coordination:
 for name,frame in [('Left palm placed',158),('Left leg follows',175),('Torso aligned with pelvis',229)]:
  marker=scene.timeline_markers.get(name)
  if marker:marker.frame=frame
  else:scene.timeline_markers.new(name,frame=frame)
else:
 for name in ['Left palm placed','Torso aligned with pelvis']:
  marker=scene.timeline_markers.get(name)
  if marker:scene.timeline_markers.remove(marker)
scene.frame_set(190)
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_extreme.blend'),compress=True)
print('REFINED: 385 complete poses, original timing and baseline action retained')
