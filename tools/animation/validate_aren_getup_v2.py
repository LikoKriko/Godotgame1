"""Blender geometry checks on the original skin, at keys or every baked frame.
Run with the authored .blend loaded. Reports remain local; never saves the file.
"""
import bpy
import math
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

rig = bpy.data.objects['Aren_Native_66_Authoring']
scene = bpy.context.scene
assert len(rig.data.bones) == 66
meshes = [o for o in scene.objects if o.type == 'MESH' and o.name != 'ExportSkin'
          and any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]
regions = ['abdomen', 'right_thigh', 'left_thigh', 'right_arm', 'left_arm']
records = []
for obj in meshes:
    groups = {g.index: g.name for g in obj.vertex_groups}
    hip = rig.matrix_world @ rig.data.bones['smartrig:Hips'].head_local
    hips = [rig.matrix_world @ rig.data.bones['smartrig:' + s + 'UpLeg'].head_local for s in ['Right', 'Left']]
    axes = [((rig.matrix_world @ rig.data.bones['smartrig:' + s + 'Leg'].head_local) - hips[i]).normalized() for i, s in enumerate(['Right', 'Left'])]
    memberships = []
    for vertex in obj.data.vertices:
        p = obj.matrix_world @ vertex.co
        weights = {groups[g.group]: g.weight for g in vertex.groups}
        tags = set()
        if sum(weights.get('smartrig:' + b, 0) for b in ['Hips', 'Spine', 'Spine1']) > .65 and hip.z + .045 < p.z < hip.z + .32:
            tags.add('abdomen')
        for i, side in enumerate(['Right', 'Left']):
            # Exclude the shared hip attachment, where contiguous skin meets.
            if weights.get('smartrig:' + side + 'UpLeg', 0) > .55 and (p - hips[i]).dot(axes[i]) > .10:
                tags.add(side.lower() + '_thigh')
            if sum(w for n, w in weights.items() if n.startswith('smartrig:' + side) and ('ForeArm' in n or 'Hand' in n)) > .7:
                tags.add(side.lower() + '_arm')
        memberships.append(tags)
    obj.data.calc_loop_triangles()
    faces = {tag: [tuple(t.vertices) for t in obj.data.loop_triangles
                   if all(tag in memberships[i] for i in t.vertices)] for tag in regions}
    records.append((obj, faces))

keys_only = '--keys-only' in sys.argv
frames = list(rig['whole_body_keys']) if keys_only else range(scene.frame_start, scene.frame_end + 1)
failures = []
lowest = 1.0
previous = {}
worst = (0, '', 0)
# Nonadjacent surface patches: abdomen/thighs, arms/body, arms/opposite limb.
pairs = [('abdomen', r) for r in regions[1:]] + [('right_thigh', 'left_thigh')]
pairs += [(a, b) for a in regions[3:] for b in regions[1:3]]
for frame in frames:
    scene.frame_set(frame)
    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    patches = {tag: [] for tag in regions}
    for obj, faces in records:
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        start = len(points)
        points.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
        for tag in regions:
            patches[tag].extend(tuple(start + j for j in face) for face in faces[tag])
        evaluated.to_mesh_clear()
    floor = min(p.z for p in points)
    lowest = min(lowest, floor)
    if floor < -.002:
        failures.append((frame, 'skin below floor', round(floor, 5)))
    trees = {tag: BVHTree.FromPolygons(points, patches[tag], all_triangles=True) for tag in regions}
    for left, right in pairs:
        crossing = False
        for a, b in trees[left].overlap(trees[right]):
            triangles = [[points[i] for i in patches[tag][face]] for tag, face in [(left, a), (right, b)]]
            for triangle, other in [triangles, list(reversed(triangles))]:
                for edge in range(3):
                    origin = triangle[edge]
                    delta = triangle[(edge + 1) % 3] - origin
                    if delta.length_squared < 1e-14:
                        continue
                    hit = intersect_ray_tri(*other, delta, origin, True)
                    if hit is not None and .000001 < (hit - origin).dot(delta) / delta.length_squared < .999999:
                        crossing = True
            if crossing:
                break
        if crossing:
            failures.append((frame, 'skin intersection', left, right))
    for bone in rig.pose.bones:
        q = bone.matrix_basis.to_quaternion()
        if bone.name in previous and not keys_only:
            angle = math.degrees(previous[bone.name].rotation_difference(q).angle)
            angle = min(angle, 360 - angle)
            if angle > worst[0]:
                worst = (angle, bone.name, frame)
            if angle > 12:
                failures.append((frame, 'joint discontinuity', bone.name, round(angle, 2)))
        previous[bone.name] = q
print('GETUP GEOMETRY:', len(list(frames)), 'frames; floor', lowest, '; worst step', worst)
print('FAILURES:', failures)
assert not failures, 'Inspect the real mesh and correct the whole-body pose/trajectory before exporting'
