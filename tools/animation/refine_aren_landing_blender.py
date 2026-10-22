"""Edit the existing pilot's complete poses; never regenerate the FBX authoring.

blender -b .../authoring/aren_landing_3m.blend -t 4 --python tools/animation/refine_aren_landing_blender.py
Run once on the original pilot. Subsequent manual edits use --bake-only.
--heavy-only explicitly regenerates the heavy authoring from corrected 3 m;
it overwrites any existing heavy authoring edits, so it is not a bake command.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Quaternion

OUT = Path(__file__).resolve().parents[2] / 'assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/authoring'
rig = bpy.data.objects['Aren_Native_66_Authoring']
heavy_only = '--heavy-only' in sys.argv
if rig.get('reception_revision') and not heavy_only:
    raise RuntimeError('Already refined: preserve manual edits and use --bake-only')
if heavy_only and rig.get('reception_revision') != 'balanced_3m_v2':
    raise RuntimeError('--heavy-only requires the corrected 3 m authoring file')
bpy.context.preferences.filepaths.save_version = 0
frames = [1, 17, 37, 48, 60, 71, 87, 104, 156]

def edit_poses(heavy=False):
    # Snapshot every complete pose before inserting keys into any action.
    snapshots = []
    controls = [bpy.data.objects[n] for n in ['Foot_R','Foot_L','Palm_R','Hand_L','Knee_R','Knee_L','Elbow_R','Elbow_L']]
    for frame in frames:
        bpy.context.scene.frame_set(frame)
        snapshots.append((frame, {b.name: b.matrix_basis.copy() for b in rig.pose.bones},
                          {o.name: (o.location.copy(), o.rotation_quaternion.copy()) for o in controls}))
    weights = [0, .18, .55, .85, 1, .98, .72, .28, 0]
    for (frame, bones, targets), weight in zip(snapshots, weights):
        bpy.context.scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.matrix_basis = bones[bone.name]
        # Redistribute the complete spine pose while external IK retains supports.
        for name in ['Spine','Spine1','Spine2']:
            bone = rig.pose.bones['smartrig:'+name]
            bone.rotation_quaternion = Quaternion((1,0,0), math.radians((1.0 if heavy else -4.0)*weight)) @ bone.rotation_quaternion
        for obj in controls:
            obj.location, obj.rotation_quaternion = targets[obj.name]
        # Free hand remains outside the front thigh, rather than cutting across it.
        bpy.data.objects['Hand_L'].location.x += (.012 if heavy else .025)*weight
        bpy.data.objects['Hand_L'].location.y -= (.015 if heavy else .025)*weight
        if frame == 87:
            # Whole-body transfer key: lift the palm along its exit arc as the
            # torso rises; do not drag it backwards through the forward knee.
            palm = bpy.data.objects['Palm_R']
            palm.location.x = -.27
            palm.location.y = -.43
            palm.location.z = .43
        if heavy and frame in [37,48]:
            rig.pose.bones['smartrig:Hips'].location.z += .6*weight
        for bone in rig.pose.bones:
            for path in ['location','rotation_quaternion','scale']:
                bone.keyframe_insert(path, frame=frame, group=bone.name)
        for obj in controls:
            for path in ['location','rotation_quaternion']:
                obj.keyframe_insert(path, frame=frame)
    # Retain the existing contact plateaux and authored foot recovery arcs.
    for obj in [rig]+controls:
        for curve in obj.animation_data.action.fcurves:
            for key in curve.keyframe_points:
                if key.co.x == 87:
                    key.interpolation='BEZIER'
                    key.handle_left_type=key.handle_right_type='AUTO_CLAMPED'
    bpy.context.scene.timeline_markers.new('Whole-body support transfer', frame=87)

if not heavy_only:
    edit_poses()
    rig['reception_revision']='balanced_3m_v2'
    rig['whole_body_keys']=frames
    bpy.context.scene.frame_set(60)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'aren_landing_3m.blend'), compress=True)
# A second complete authored endpoint; runtime blends complete native poses by
# impact speed. The original rig, skin and all approved locomotion stay intact.
edit_poses(heavy=True)
rig['reception_revision']='heavy_under_8m_v2'
rig.animation_data.action.name='ArenLandingHeavy_WholePoses'
bpy.context.scene.frame_set(60)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'aren_landing_heavy.blend'), compress=True)
