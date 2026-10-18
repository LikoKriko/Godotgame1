"""Blender -b --python tools/meshy/build_composite.py -- body.fbx approved.glb output.glb.
Keep the supplied T-pose skin and rig; replace its head and bridge both neck loops.
Sources stay untouched. Coordinates remain in the new rig's original metres.
"""
import bpy,bmesh,sys,math,json,struct
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
body_file,head_file,dest=[str(Path(value).resolve())for value in sys.argv[sys.argv.index('--')+1:]]
Path(dest).parent.mkdir(parents=True,exist_ok=True)
repo=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=body_file)
body=next(o for o in bpy.data.objects if o.type=='MESH');rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
original_bones=[b.name for b in rig.data.bones]
body.name='SurvivorComposite';body.data.materials[0].name='BodySource'
body_image=next(n.image for n in body.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
body_image.filepath_raw=str(Path(dest).with_name('body_albedo.png'));body_image.file_format='PNG';body_image.save()
body_samples=[(body.data.vertices[loop.vertex_index].co.copy(),body.data.uv_layers.active.data[loop.index].uv.copy(),body.data.corner_normals[loop.index].vector.copy())for loop in body.data.loops]
body_tree=KDTree(len(body_samples))
for i,(point,uv,normal)in enumerate(body_samples):body_tree.insert(point,i)
body_tree.balance()
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(Path(dest).with_name('body_reference.glb')),export_format='GLB',use_selection=True,export_materials='NONE',export_animations=False,export_all_influences=True)


bpy.ops.import_scene.gltf(filepath=head_file)
head=next(o for o in bpy.context.selected_objects if o.type=='MESH');head.name='ApprovedHead'
for vertex in head.data.vertices:vertex.co=(head.matrix_world@vertex.co+Vector((0,2.6,0)))*(1.7/64)
head.matrix_world.identity()
# Cache the approved normals, colors and UVs before any neck editing.
head.data.calc_loop_triangles()
original_head=[(head.data.vertices[loop.vertex_index].co.copy(),head.data.uv_layers.active.data[loop.index].uv.copy(),head.data.corner_normals[loop.index].vector.copy())for loop in head.data.loops]
head_tree=KDTree(len(original_head))
for i,(point,uv,normal)in enumerate(original_head):head_tree.insert(point,i)
head_tree.balance()
head.data.materials.clear();hm=bpy.data.materials.new('ApprovedHead');head.data.materials.append(hm)
# Clip each source above the shoulders and below the approved jaw/beard.
for obj,cut,inner,outer in [(body,52.5*1.7/64,False,True),(head,53*1.7/64,True,False)]:
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,cut),plane_no=(0,0,1),clear_inner=inner,clear_outer=outer,dist=1e-7)
 ring=[v for v in bm.verts if abs(v.co.z-cut)<1e-6]
 bmesh.ops.remove_doubles(bm,verts=ring,dist=1e-7)
 bm.to_mesh(obj.data);bm.free()
# A short neck transition leaves all approved facial geometry intact.
head_shift=Vector((0,0,1.7/64))
for v in head.data.vertices:v.co+=head_shift
for name in original_bones:head.vertex_groups.new(name=name)
for v in head.data.vertices:
 t=max(0,min(1,(v.co.z-54*1.7/64)/(1.5*1.7/64)))
 head.vertex_groups['smartrig:Neck'].add([v.index],(1-t)*.7,'REPLACE')
 head.vertex_groups['smartrig:Head'].add([v.index],.3+.7*t,'REPLACE')
# Preserve only approved source colors on the head. Body/bridge get separate materials.
for attr in list(body.data.color_attributes):body.data.color_attributes.remove(attr)
for attr in list(head.data.color_attributes):head.data.color_attributes.remove(attr)
# Join by native group names, keeping every original native bone and its axes.
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.join()
neck=bpy.data.materials.new('NeckTransition');body.data.materials.append(neck);neck_index=len(body.data.materials)-1
bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table()
low_z=52.5*1.7/64;high_z=54*1.7/64
loops=[]
for height in [low_z,high_z]:
 ring=[v for v in bm.verts if abs(v.co.z-height)<1e-6 and any(e.is_boundary for e in v.link_edges)]
 assert len(ring)>16,(height,len(ring))
 center=sum((v.co for v in ring),Vector())/len(ring)
 ring.sort(key=lambda v:math.atan2(v.co.y-center.y,v.co.x-center.x))
 loops.append(ring)
# Resolve neck color per boundary vertex from the adjacent source UV, with an
# inward sample to avoid atlas padding. This is vertex shading, not a new atlas.
uv=bm.loops.layers.uv.active
color_layer=bm.loops.layers.float_color.get('SurfaceMask')or bm.loops.layers.float_color.new('SurfaceMask')
head_image=bpy.data.images.load(str(repo/'assets/characters/prototype_3d/meshy/albedo.png'))
images=[body_image,head_image]
pixels=[np.array(im.pixels[:],dtype=np.float32).reshape(im.size[1],im.size[0],4)for im in images]
colors={}
for ring in loops:
 for v in ring:
  samples=[]
  for loop in v.link_loops:
   if loop.face.material_index>1:continue
   center=sum((l[uv].uv for l in loop.face.loops),Vector((0,0)))/len(loop.face.loops)
   tex=loop[uv].uv.lerp(center,.025);image=images[loop.face.material_index];data=pixels[loop.face.material_index]
   c=data[min(image.size[1]-1,max(0,int(tex.y*image.size[1]))),min(image.size[0]-1,max(0,int(tex.x*image.size[0]))),:3]
   if c[0]>.35 and c[0]>c[2]*1.1:samples.append(c)
  c=np.mean(samples,axis=0)if samples else np.array([.88,.59,.43])
  colors[v]=tuple(c)+(1,)
# Angular zipper supports different loop tessellations without T-junctions.
a,b=loops;i=j=0
angles=[]
for ring in loops:
 center=sum((v.co for v in ring),Vector())/len(ring)
 angles.append([math.atan2(v.co.y-center.y,v.co.x-center.x)+math.pi for v in ring]+[2*math.pi])
while i<len(a)or j<len(b):
 if i<len(a)and(j==len(b)or angles[0][i+1]<=angles[1][j+1]):
  vertices=[a[i%len(a)],a[(i+1)%len(a)],b[j%len(b)]];i+=1
 else:
  vertices=[a[i%len(a)],b[(j+1)%len(b)],b[j%len(b)]];j+=1
 face=bm.faces.new(vertices);face.material_index=neck_index;face.smooth=True
 for loop in face.loops:loop[color_layer]=colors[loop.vert]
# Every neck-ring edge now has exactly two incident faces.
for ring in loops:
 for v in ring:
  assert all(not e.is_boundary for e in v.link_edges if all(abs(w.co.z-v.co.z)<1e-6 for w in e.verts)),'Open neck seam'
for face in bm.faces:
 if face.material_index!=neck_index:continue
 face.normal_update();center=face.calc_center_median()
 if face.normal.dot(Vector((center.x,center.y-.025,0)))<0:face.normal_flip()
bm.to_mesh(body.data);bm.free();body.data.update()
# Smooth only the new transition; retain the approved source's facial normals.
custom=[]
for loop in body.data.loops:
 custom.append(body.data.vertices[loop.vertex_index].normal.copy())
for polygon in body.data.polygons:
 for loop_index in polygon.loop_indices:
  v=body.data.vertices[body.data.loops[loop_index].vertex_index]
  if polygon.material_index==0 and v.co.z<low_z-.0001:
   candidates=body_tree.find_range(v.co,1e-6)
   if candidates:
    tex=body.data.uv_layers.active.data[loop_index].uv
    index=min((entry[1]for entry in candidates),key=lambda i:(body_samples[i][1]-tex).length_squared)
    custom[loop_index]=body_samples[index][2]
  if polygon.material_index==1 and v.co.z>high_z+.0001:
   candidates=head_tree.find_range(v.co-head_shift,1e-6)
   if candidates:
    tex=body.data.uv_layers.active.data[loop_index].uv
    index=min((entry[1]for entry in candidates),key=lambda i:(original_head[i][1]-tex).length_squared)
    custom[loop_index]=original_head[index][2]
body.data.normals_split_custom_set(custom)
# Export vertex masks and neck colors in separate named attributes. Godot selects
# the appropriate attribute per material when importing the derived geometry.
body.data.color_attributes.active_color=body.data.color_attributes.get('SurfaceMask')or body.data.color_attributes[0]
assert [b.name for b in rig.data.bones]==original_bones
for polygon in body.data.polygons:polygon.use_smooth=True
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=dest,export_format='GLB',use_selection=True,export_animations=False,export_tangents=True,export_attributes=True,export_all_vertex_colors=True,export_vertex_color='ACTIVE',export_all_influences=True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(dest).with_suffix('.blend')))
Path(dest).with_suffix('.json').write_text(json.dumps({'native_bones':original_bones,'neck_loops':[len(r)for r in loops],'neck_closed':True,'head_shift':list(head_shift),'native_height':max(v.co.z for v in body.data.vertices)},indent=2))

# Blender reserves COLOR_0 for a material fallback when exporting unused
# attributes. Godot consumes COLOR_0 only: select the authored neck colors.
blob=Path(dest).read_bytes();json_size=struct.unpack_from('<I',blob,12)[0]
document=json.loads(blob[20:20+json_size]);binary=blob[20+json_size:]
for item in document['meshes']:
 for primitive in item['primitives']:
  attributes=primitive['attributes']
  if 'COLOR_1'in attributes:attributes['COLOR_0']=attributes.pop('COLOR_1')
encoded=json.dumps(document,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
Path(dest).write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+binary)
