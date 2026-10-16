"""Blender -b --python tools/meshy/convert_source.py -- input.fbx output.glb."""
import sys
from pathlib import Path
import bpy
a = sys.argv[sys.argv.index('--') + 1:]
if len(a) != 2:
    raise SystemExit('Expected input.fbx output.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(Path(a[0]).resolve()))
bpy.ops.export_scene.gltf(filepath=str(Path(a[1]).resolve()), export_format='GLB', export_materials='NONE', export_animations=False, export_yup=True)
