"""Blender -b --python tools/meshy/transfer_survivor.py -- input.fbx output.glb joints.json donor_folder.
Transfer the live 24-bone survivor skin onto a user-supplied reduced mesh. Keep its
positions, UVs, normals and topology; interpolate the nearest donor triangle.
"""
import json, sys, math
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector, geometry
from mathutils.bvhtree import BVHTree
args=sys.argv[sys.argv.index('--')+1:]
if len(args)!=4:raise SystemExit('Expected input.fbx output.glb joints.json donor_folder')
source,dest,joints,folder=args;folder=Path(folder)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(Path(source).resolve()))
meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
if len(meshes)!=1:raise ValueError('Expected one supplied mesh')
mesh=meshes[0]
coords=[mesh.matrix_world@vertex.co for vertex in mesh.data.vertices]
low=[min(p[i] for p in coords) for i in range(3)]
high=[max(p[i] for p in coords) for i in range(3)]
scale=64/(high[2]-low[2]);cx=(high[0]+low[0])/2
positions=np.fromfile(folder/'positions.bin',dtype='<f4').reshape((-1,3))
triangles=np.fromfile(folder/'indices.bin',dtype='<i4').reshape((-1,3))
bones=np.fromfile(folder/'bones.bin',dtype='<i4').reshape((-1,4))
weights=np.fromfile(folder/'weights.bin',dtype='<f4').reshape((-1,4))
tree=BVHTree.FromPolygons([Vector(p) for p in positions],triangles.tolist(),all_triangles=True)
with open(joints,encoding='utf-8') as stream:definitions=json.load(stream)
names=[row['name'] for row in definitions]
assert len(names)==24
mesh.vertex_groups.clear()
groups=[mesh.vertex_groups.new(name=name) for name in names]
distances=[]
for vertex,p in zip(mesh.data.vertices,coords):
 point=Vector(((p.x-cx)*scale,(p.z-low[2])*scale,-p.y*scale+2.6))
 nearest,_,face,distance=tree.find_nearest(point)
 if nearest is None:raise ValueError('No donor surface')
 indices=triangles[face];a,b,c=[Vector(positions[i]) for i in indices]
 if (b-a).cross(c-a).length_squared<1e-14:
  closest=min(range(3),key=lambda i:(Vector(positions[indices[i]])-point).length_squared)
  blend=[float(i==closest) for i in range(3)]
 else:blend=geometry.barycentric_transform(nearest,a,b,c,Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)))
 influences={}
 for i,amount in zip(indices,blend):
  for bone,weight in zip(bones[i],weights[i]):
   key=int(bone);influences[key]=influences.get(key,0)+max(0,float(amount))*float(weight)
 largest=sorted(influences.items(),key=lambda pair:pair[1],reverse=True)[:4]
 total=sum(weight for _,weight in largest)
 if total<1e-8:raise ValueError('Unweighted source vertex')
 for bone,weight in largest:
  if weight>0:groups[bone].add([vertex.index],weight/total,'REPLACE')
 distances.append(distance)
with open(joints,encoding='utf-8') as stream:definitions=json.load(stream)

assert [row['name'] for row in definitions]==names
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='SurvivorRig'
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0]);created=[]
def source_point(p):return Vector((p[0]/scale+cx,-(p[2]-2.6)/scale,p[1]/scale+low[2]))
for definition in definitions:
 bone=rig.data.edit_bones.new(definition['name']);bone.head=source_point(definition['a']);bone.tail=source_point(definition['b'])
 if definition['parent']>=0:bone.parent=created[definition['parent']]
 created.append(bone)
bpy.ops.object.mode_set(mode='OBJECT')
world=mesh.matrix_world.copy();mesh.parent=rig;mesh.matrix_world=world
modifier=mesh.modifiers.new('TransferredSkin','ARMATURE');modifier.object=rig
bpy.ops.export_scene.gltf(filepath=str(Path(dest).resolve()),export_format='GLB',export_materials='NONE',export_animations=False,export_yup=True,export_all_influences=False)
stats={'vertices':len(coords),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'max_transfer_distance':max(distances),'rms_transfer_distance':math.sqrt(sum(d*d for d in distances)/len(distances)),'donor':json.loads((folder/'donor.json').read_text())}
Path(dest).with_suffix('.transfer.json').write_text(json.dumps(stats,indent=2)+'\n');print(stats,flush=True)
