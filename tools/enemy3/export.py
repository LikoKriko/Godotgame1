"""Blender 4.3+: --background --python tools/enemy3/export.py -- /abs/rig.glb.
Keep the supplied rig, triangles and UVs. Materials are linked by bake.gd.
Godot supports eight weights per vertex: retain the eight largest influences.
"""
import bpy, json, sys
from pathlib import Path
repo = Path(__file__).resolve().parents[2]
source = repo / 'entregables/enemigos/enemigo3/modelo_enemigo3.fbx'
output = Path(sys.argv[sys.argv.index('--') + 1])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(source))
bpy.ops.object.select_all(action='DESELECT')
report = {'discarded_weight_max': 0.0, 'vertices_over_eight_weights': 0}
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE' or (obj.type == 'MESH' and obj.data.polygons):
        obj.select_set(True)
    if obj.type != 'MESH' or not obj.data.polygons:
        continue
    for vertex in obj.data.vertices:
        weights = sorted(vertex.groups, key=lambda group: group.weight, reverse=True)
        if len(weights) > 8:
            dropped = sum(group.weight for group in weights[8:])
            report['discarded_weight_max'] = max(report['discarded_weight_max'], dropped)
            report['vertices_over_eight_weights'] += 1
            for group in weights[8:]:
                obj.vertex_groups[group.group].remove([vertex.index])
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
    export_materials='NONE', export_animations=False, export_cameras=False,
    export_lights=False, export_influence_nb=8)
output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
print(report)
