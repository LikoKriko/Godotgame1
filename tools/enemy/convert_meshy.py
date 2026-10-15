"""Blender --background --python tools/enemy/convert_meshy.py -- input.fbx output.glb joints.json.
Preserve source geometry and UVs; add bone-heat weights to the unrigged FBX.
Run export_meshy_bind.gd first, then bind_meshy.gd on the resulting glTF.
"""
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 3:
    raise SystemExit('Expected input.fbx output.glb joints.json')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(Path(args[0]).resolve()))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if len(meshes) != 1:
    raise ValueError('Expected the single mesh in the verified Meshy archive')
mesh = meshes[0]
if len(mesh.data.polygons) != 977782:
    raise ValueError('Unexpected source topology; verify the release SHA-256')
coords = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
low = [min(vertex[axis] for vertex in coords) for axis in range(3)]
high = [max(vertex[axis] for vertex in coords) for axis in range(3)]
scale = 32.0 / (high[2] - low[2])
centre_x = (low[0] + high[0]) / 2

def source_point(point):
    # Godot authoring coordinates -> original Blender FBX world coordinates.
    return Vector((point[0] / scale + centre_x, -point[2] / scale, point[1] / scale + low[2]))

with open(args[2], encoding='utf-8') as stream:
    definitions = json.load(stream)
bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = 'MossclawRig'
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
created = []
for definition in definitions:
    bone = rig.data.edit_bones.new(definition['name'])
    bone.head = source_point(definition['a'])
    bone.tail = source_point(definition['b'])
    if definition['parent'] >= 0:
        bone.parent = created[definition['parent']]
    created.append(bone)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
if any(not vertex.groups for vertex in mesh.data.vertices):
    raise ValueError('Bone heat left unweighted vertices; do not publish')
bpy.ops.export_scene.gltf(
    filepath=str(Path(args[1]).resolve()), export_format='GLB',
    export_materials='NONE', export_animations=False, export_yup=True,
    export_all_influences=False,
)
