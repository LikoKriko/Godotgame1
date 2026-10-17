"""Blender 4.3+: -b --python tools/enemy1/optimize_surface.py -- /abs/work/output.
Derive a reduced mesh and tangent normal from the intact user GLB. Original
head, sole and extreme vertices are protected; the native rig is reused later.
"""
import bpy,json,math
from pathlib import Path
from mathutils.kdtree import KDTree
import sys
repo=Path(__file__).resolve().parents[2]
output=Path(sys.argv[sys.argv.index('--')+1]).resolve();output.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(repo/'entregables/enemigos/enemigo1/source/Meshy_AI_Character_output.glb'))
source=bpy.data.objects['output_unwrapped'];rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
low=source.copy();low.data=source.data.copy();low.name='Mossclaw_Low';bpy.context.collection.objects.link(low)
bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low
# Rejoin the imported per-corner vertices; UVs remain per face-corner.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.000001);bpy.ops.object.mode_set(mode='OBJECT')
original=[v.co.copy()for v in low.data.vertices];names={v.index:v.name for v in low.vertex_groups};protected=[]
original_weights=[[(g.group,g.weight)for g in v.groups]for v in low.data.vertices]
original_tree=KDTree(len(original))
for index,point in enumerate(original):original_tree.insert(point,index)
original_tree.balance()
mins=[min(v.co[i]for v in low.data.vertices)for i in range(3)];maxs=[max(v.co[i]for v in low.data.vertices)for i in range(3)]
vg=low.vertex_groups.new(name='simplification')
for v in low.data.vertices:
 head=sum(g.weight for g in v.groups if names[g.group] in ['Bone_016','Bone_015'])
 foot=sum(g.weight for g in v.groups if names[g.group] in ['Bone_007','Bone_008','Bone_009','Bone_010','Bone_011','Bone_012','Bone_013','Bone_014'])
 bound=any(abs(v.co[i]-limit)<.00001 for i in range(3)for limit in [mins[i],maxs[i]])
 keep=head>.25 or (foot>.4 and v.co.z<.14) or bound
 if keep:protected.append(v.co.copy())
 vg.add([v.index],0.0 if keep else 1.0,'REPLACE')
dec=low.modifiers.new('Surface reduction','DECIMATE');dec.ratio=.55;dec.vertex_group=vg.name;dec.vertex_group_factor=1000;dec.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=dec.name)
for v in low.data.vertices:
 for i in range(3):v.co[i]=min(max(v.co[i],mins[i]),maxs[i])
 # A collapse can keep a protected position but still interpolate its weights.
 # Restore the original skin at every surviving source vertex, including soles.
 _,index,distance=original_tree.find(v.co)
 if distance<.000001:
  for group in low.vertex_groups:group.remove([v.index])
  for group,weight in original_weights[index]:low.vertex_groups[group].add([v.index],weight,'REPLACE')
kd=KDTree(len(low.data.vertices))
for v in low.data.vertices:kd.insert(v.co,v.index)
kd.balance();lost=[(kd.find(p)[2])for p in protected]
assert max(lost)<.000001, 'Protected vertices must survive exactly'
print('LOW',len(low.data.vertices),len(low.data.polygons),'PROTECTED',len(protected),'missing',sum(d>1e-6 for d in lost),'max',max(lost))
(output/'candidate.json').write_text(json.dumps({'vertices':len(low.data.vertices),'triangles':len(low.data.polygons),'protected':len(protected),'protected_missing':sum(d>1e-6 for d in lost),'protected_max_distance':max(lost)},indent=2))
# Source tangent-space normal supplies the fur and stone detail during projection.
mat=source.data.materials[0];bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for node in mat.node_tree.nodes:
 if node.type=='TEX_IMAGE' and node.image:print('IMAGE',node.image.name,node.image.size[:],node.image.colorspace_settings.name)
normal=mat.node_tree.nodes.new('ShaderNodeTexImage');normal.image=bpy.data.images.load(str(repo/'assets/enemies/first/meshy/normal.png'),check_existing=True);normal.image.colorspace_settings.name='Non-Color'
normal_node=mat.node_tree.nodes.new('ShaderNodeNormalMap');mat.node_tree.links.new(normal.outputs['Color'],normal_node.inputs['Color']);mat.node_tree.links.new(normal_node.outputs['Normal'],bsdf.inputs['Normal'])
target=bpy.data.materials.new('Mossclaw baked normal');target.use_nodes=True
low.data.materials.clear();low.data.materials.append(target)
image=bpy.data.images.new('mossclaw_surface_normal',width=2048,height=2048,alpha=False);image.generated_color=(.5,.5,1,1);image.colorspace_settings.name='Non-Color'
node=target.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;target.node_tree.nodes.active=node;node.select=True
bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.device='CPU';bpy.context.scene.cycles.samples=1
bpy.context.scene.render.bake.use_selected_to_active=True;bpy.context.scene.render.bake.cage_extrusion=.045;bpy.context.scene.render.bake.max_ray_distance=.09;bpy.context.scene.render.bake.margin=4
bpy.context.scene.render.bake.normal_space='TANGENT'
# Keep only the supplied rig and the mesh pair in the bake scene.
for obj in list(bpy.data.objects):
 if obj not in [rig,source,low]:bpy.data.objects.remove(obj,do_unlink=True)


bpy.ops.object.select_all(action='DESELECT');source.select_set(True);low.select_set(True);bpy.context.view_layer.objects.active=low
bpy.context.scene.render.bake.use_clear=False
bpy.ops.object.bake(type='NORMAL')
image=bpy.data.images['mossclaw_surface_normal'];image.filepath_raw=str(output/'normal.png');image.file_format='PNG';image.save()
bpy.ops.object.select_all(action='DESELECT');low.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(output/'low.glb'),export_format='GLB',use_selection=True,export_materials='NONE',export_animations=False,export_tangents=True)

