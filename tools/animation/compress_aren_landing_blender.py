"""Edit only frames 48..60 of an existing editable landing .blend.

Run once with --reference <native visible-pose JSON>, then use --bake-only.
No FBX import, retiming, rig/skin changes or new movement outside absorption.
"""
import bpy
import math
import json
import sys
from mathutils import Matrix, Quaternion, Vector

rig = bpy.data.objects['Aren_Native_66_Authoring']
scene = bpy.context.scene
if rig.get('impact_compression_revision'):
    raise RuntimeError('Compression already authored; edit the existing poses instead')
bpy.context.preferences.filepaths.save_version = 0
action = rig.animation_data.action
frames = list(range(48, 61))
if '--reference' not in sys.argv:
    raise RuntimeError('Supply --reference with the native visible-pose reference JSON')
reference = json.load(open(sys.argv[sys.argv.index('--reference')+1]))
C = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def matrix(record):
    return Matrix(([*record[0],0],[*record[1],0],[*record[2],0],[*record[3],1])).transposed()
names = [b['name'] for b in reference['bones']]
assert len(names) == len(rig.data.bones) == 66
offsets = {b['name']:(C@matrix(b['rest'])).inverted()@rig.matrix_world@rig.data.bones[b['name']].matrix_local for b in reference['bones']}
# Keep the previous editable source action. A historical exporter option merged
# all armature actions, so the visible clip can differ from that editable action.
# Round-trip the visible reference to the SAME rig, without inventing movement.
action.use_fake_user = True
rig.animation_data.action = bpy.data.actions.new('Aren_ContactAbsorption_WholePoses')
action = rig.animation_data.action
constraints = [c for b in rig.pose.bones for c in b.constraints]
for constraint in constraints:constraint.influence = 0
for frame, sample in enumerate(reference['samples'], 1):
    scene.frame_set(frame)
    poses = {name:rig.matrix_world.inverted()@C@matrix(sample[i])@offsets[name] for i,name in enumerate(names)}
    for bone in rig.data.bones:
        local = poses[bone.parent.name].inverted()@poses[bone.name] if bone.parent else poses[bone.name]
        rest = bone.parent.matrix_local.inverted()@bone.matrix_local if bone.parent else bone.matrix_local
        pb = rig.pose.bones[bone.name];pb.matrix_basis = rest.inverted()@local
        for path in ['location','rotation_quaternion','scale']:pb.keyframe_insert(path, frame=frame, group=bone.name)
for curve in action.fcurves:
    for key in curve.keyframe_points:key.interpolation='LINEAR'
# Fixed contact controls follow the reference clip. Original control actions are
# retained as editable sources; only the new absorption action uses these keys.
control_names = ['Foot_R','Foot_L','Palm_R','Hand_L','Knee_R','Knee_L','Elbow_R','Elbow_L']
for name in control_names:
    obj=bpy.data.objects[name]
    obj.animation_data.action.use_fake_user=True
    obj.animation_data.action=obj.animation_data.action.copy()
for frame in frames:
    scene.frame_set(frame)
    for side,letter in [('Right','R'),('Left','L')]:
        for end,control in [('Foot','Foot'),('Hand','Palm' if side=='Right' else 'Hand')]:
            obj=bpy.data.objects[control+'_'+letter]
            transform=rig.matrix_world@rig.pose.bones['smartrig:'+side+end].matrix
            obj.location=transform.translation;obj.rotation_quaternion=transform.to_quaternion()
            for path in ['location','rotation_quaternion']:obj.keyframe_insert(path,frame=frame)
        for root,mid,end,pole in [('UpLeg','Leg','Foot','Knee'),('Arm','ForeArm','Hand','Elbow')]:
            a=rig.matrix_world@rig.pose.bones['smartrig:'+side+root].head
            b=rig.matrix_world@rig.pose.bones['smartrig:'+side+mid].head
            c=rig.matrix_world@rig.pose.bones['smartrig:'+side+end].head
            axis=(c-a).normalized();radial=b-a-axis*(b-a).dot(axis)
            obj=bpy.data.objects[pole+'_'+letter];obj.location=b+radial.normalized()*.7
            obj.keyframe_insert('location',frame=frame)
# Calibrate native bend planes at the compression reference before lowering the
# body. Targets stay fixed; the two-bone solver only adapts contacts.
scene.frame_set(52)
desired={b.name:(rig.matrix_world@b.head).copy() for b in rig.pose.bones}
for side in ['Right','Left']:
    for mid in ['Leg','ForeArm']:
        bone=rig.pose.bones['smartrig:'+side+mid]
        con=next(c for c in bone.constraints if c.type=='IK');con.influence=1
        best=(float('inf'),0)
        for degree in range(-180,181,2):
            con.pole_angle=math.radians(degree);bpy.context.view_layer.update()
            score=(rig.matrix_world@bone.head-desired[bone.name]).length_squared
            if score<best[0]:best=(score,con.pole_angle)
        con.pole_angle=best[1];con.influence=0
for constraint in constraints:
    for frame,influence in [(1,0),(48,0),(49,1),(59,1),(60,0),(156,0)]:
        constraint.influence=influence;constraint.keyframe_insert('influence',frame=frame)
# Keep every existing tangent outside the edited interval. AUTO handles would
# otherwise change the approach/recovery when intermediate keys are inserted.
handles = {}
for curve in action.fcurves:
    for key in curve.keyframe_points:
        handles[(curve.data_path, curve.array_index, int(key.co.x))] = (
            key.handle_left.copy(), key.handle_right.copy(), key.interpolation)
        key.handle_left_type = key.handle_right_type = 'FREE'

# Capture full unmodified poses before adding any keys. Contact controllers are
# deliberately read-only: Blender's native IK supplies reactive leg/ankle and
# arm flexion as the body drops against the same fixed support targets.
snapshots = {}
for frame in frames:
    scene.frame_set(frame)
    snapshots[frame] = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
scene.frame_set(60)
hip = rig.pose.bones['smartrig:Hips']
settled_height = (rig.matrix_world @ hip.head).z
scene.frame_set(48)
impact_height = (rig.matrix_world @ hip.head).z
# One controlled compression minimum at +100 ms, then a monotone return to the
# existing absorption pose. The 1.7 mm undershoot avoids a second downward pulse.
height_mix = [0, .18, .50, .80, .97, 1.02, 1.03, 1.025, 1.018, 1.010, 1.005, 1.001, 1]
body_load = [0, .08, .30, .62, .90, 1, .92, .72, .48, .26, .10, .02, 0]
head_load = [0, .02, .12, .35, .66, .90, 1, .88, .65, .38, .16, .04, 0]
for index, frame in enumerate(frames):
    scene.frame_set(frame)
    for bone in rig.pose.bones:
        bone.matrix_basis = snapshots[frame][bone.name]
    bpy.context.view_layer.update()
    target_height = impact_height + (settled_height-impact_height)*height_mix[index]
    delta = target_height-(rig.matrix_world @ hip.head).z
    hip.location += (rig.matrix_world @ hip.bone.matrix_local).to_3x3().inverted() @ Vector((0,0,delta))
    for name, degrees, load in [
        ('Hips', .8, body_load[index]),
        ('Spine', 1.4, body_load[index]),
        ('Spine1', 1.4, body_load[index]),
        ('Spine2', 1.0, body_load[index]),
        ('RightShoulder', .8, body_load[index]),
        ('LeftShoulder', .8, body_load[index]),
        ('Neck', .6, head_load[index]),
        ('Head', 1.8, head_load[index]),
    ]:
        bone = rig.pose.bones['smartrig:'+name]
        bone.rotation_quaternion = Quaternion((1,0,0), math.radians(degrees*load)) @ bone.rotation_quaternion
    for bone in rig.pose.bones:
        for path in ['location','rotation_quaternion','scale']:
            bone.keyframe_insert(path, frame=frame, group=bone.name)

for curve in action.fcurves:
    for key in curve.keyframe_points:
        frame = int(key.co.x)
        if 48 < frame < 60:
            key.interpolation = 'BEZIER'
            key.handle_left_type = key.handle_right_type = 'AUTO_CLAMPED'
        original = handles.get((curve.data_path, curve.array_index, frame))
        if original:
            left, right, interpolation = original
            # Incoming contact and outgoing recovery curves stay exactly intact.
            if frame <= 48 or frame >= 60:
                key.handle_left_type = key.handle_right_type = 'FREE'
                key.handle_left, key.handle_right = left, right
                key.interpolation = interpolation

rig['impact_compression_revision'] = 'contact_pulse_v1'
rig['impact_compression_frames'] = [48,54,60]
rig['whole_body_keys'] = [1,17,37]+frames+[71,87,104,156]
scene.timeline_markers.new('Reactive impact compression', frame=54)
scene.frame_set(54)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
print('ABSORPTION_ONLY', impact_height, settled_height, 'minimum at frame 54; contacts and duration unchanged')
