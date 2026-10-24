"""Eye-only likeness pass on the dense Aren head, pending visual approval.

Blender: open the current primary_volumes_02 source and run with --output <blend>.
The facial shell keeps its topology; changes outside the orbital envelope are
forbidden. Hair, auricles, oral/nasal anatomy and the jaw are retained.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

REVISION = 'eye_likeness_01'
Z0 = 1.44
OLD_X, OLD_Z, OLD_Y = .0345, .128, -.046
CX, CZ, CY = .0328, .1287, -.0448
RADIUS, HALF_WIDTH, IRIS_RADIUS = .0175, .0164, .0070
GAZE = math.radians(1.0)


def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)


def gauss(x,c,w):
    return np.exp(-((x-c)/w)**2)


def coords(obj):
    a=np.empty(len(obj.data.vertices)*3,np.float32)
    obj.data.vertices.foreach_get('co',a)
    return a.reshape(-1,3).astype(float)


def assign(obj,values):
    obj.data.vertices.foreach_set('co',np.asarray(values,dtype=np.float32).ravel())
    obj.data.update()


def tree_for(head):
    return BVHTree.FromPolygons([v.co for v in head.data.vertices],
                               [tuple(p.vertices)for p in head.data.polygons])


def surface_y(tree,x,z):
    hit=tree.ray_cast(Vector((float(x),-1,float(z))),Vector((0,1,0)))[0]
    if hit is None:
        raise RuntimeError('Brow projection missed the orbital surface')
    return hit.y


def eyelid(a,side):
    u=np.cos(a);v=side*u;s=np.sin(a)
    z=.0004+.0021*v
    z+=np.where(s>=0,.0044*np.maximum(0,s)**2.0*(1-.12*v),
                -.0045*np.maximum(0,-s)**1.80*(1+.08*v))
    return HALF_WIDTH*u,z


def gaze_points(local,side):
    points=np.asarray(local,dtype=float).copy()
    theta=-side*GAZE;c,s=math.cos(theta),math.sin(theta)
    x=points[:,0].copy();y=points[:,1].copy()
    points[:,0]=c*x-s*y+side*CX
    points[:,1]=s*x+c*y+CY
    points[:,2]+=Z0+CZ
    return points


def mesh_object(name,vertices,faces,material,collection,colors=None):
    obj=bpy.data.objects.get(name)
    if obj is None:
        me=bpy.data.meshes.new(name);obj=bpy.data.objects.new(name,me)
        collection.objects.link(obj)
    else:
        me=bpy.data.meshes.new(name+' refined surface');obj.data=me
    me.from_pydata(vertices,[],faces);me.update();me.materials.append(material)
    for p in me.polygons:p.use_smooth=True
    if colors is not None:
        layer=me.color_attributes.new(name='Tone',type='FLOAT_COLOR',domain='POINT')
        for item,color in zip(layer.data,colors):item.color=color
        me.color_attributes.active_color=layer
    return obj


def signature(head,collection):
    digest=hashlib.sha256()
    for obj in sorted(bpy.data.objects,key=lambda o:o.name):
        if obj.type!='MESH' or obj==head or obj.name in collection.objects:
            continue
        digest.update(obj.name.encode());digest.update(coords(obj).astype(np.float32).tobytes())
        digest.update(np.array(obj.matrix_world).tobytes())
    return digest.hexdigest()


def refine_eye_likeness(head):
    if head.get('eye_revision'):
        raise RuntimeError('Eye revision already applied; open the unmodified baseline.')
    if head.get('volume_revision')!='primary_volumes_02':
        raise RuntimeError('Eye review requires the current primary volume source.')
    eyes=bpy.data.collections['03 · HIGH · eyes and brows']
    locked=signature(head,eyes)
    before=coords(head);old_tree=tree_for(head)
    normals=np.empty(len(before)*3,np.float32);head.data.vertices.foreach_get('normal',normals)
    normals=normals.reshape(-1,3)
    x,y,z=before[:,0],before[:,1],before[:,2]-Z0
    delta=np.zeros_like(before);affected=np.zeros(len(before),dtype=bool)
    fair=np.zeros(len(before))
    for side in [-1,1]:
        dx=x-side*OLD_X;dz=z-OLD_Z
        rho=np.sqrt((dx/.032)**2+(dz/.027)**2)
        weight=(1-smooth(.60,1.0,rho))*(1-smooth(-.025,.020,y))
        affected|=weight>0
        u=dx/.0158;v=(dz-side*.0018*u)/np.where(dz-side*.0018*u>=0,.005,.0045)
        v=np.sign(v)*np.abs(v)**np.where(v>=0,1/.65,1/.90)
        a=np.arctan2(v,u)
        radial=np.sqrt(u*u+v*v)
        ox=.0158*np.cos(a)
        oz=np.where(np.sin(a)>=0,.005*np.maximum(0,np.sin(a))**.65,
                    -.0045*np.maximum(0,-np.sin(a))**.90)+side*.0018*np.cos(a)
        nx,nz=eyelid(a,side)
        old_edge=OLD_Y-np.sqrt(np.maximum(1e-6,RADIUS**2-ox*ox-oz*oz))-.00018
        new_edge=CY-np.sqrt(np.maximum(1e-6,RADIUS**2-nx*nx-nz*nz))-.00055
        d=np.column_stack((side*(CX-OLD_X)+nx-ox,new_edge-old_edge,CZ-OLD_Z+nz-oz))
        # Curve the visible lid, but translate the hidden cavity coherently.
        # Applying the angular lid mapping to every depth layer twists canthi.
        old_sphere=OLD_Y-np.sqrt(np.maximum(0,RADIUS**2-dx*dx-dz*dz))
        skin_weight=1-smooth(.001,.005,y-old_sphere)
        fair=np.maximum(fair,smooth(1.08,1.55,radial)*(1-smooth(2.8,3.4,radial))*weight*skin_weight)
        affine=np.column_stack((side*(CX-OLD_X)+dx*(HALF_WIDTH/.0158-1),
                                np.full(len(x),CY-OLD_Y),
                                np.full(len(x),CZ-OLD_Z)+.0003*side*dx/.0158))
        d=d*skin_weight[:,None]+affine*(1-skin_weight)[:,None]
        # Support a hooded upper lid and a soft lower orbital rim.
        d[:,1]-=.0016*gauss(dx,0,.025)*gauss(z,.143,.010)*skin_weight
        d[:,1]-=.0007*gauss(dx,0,.024)*gauss(z,.116,.007)*skin_weight
        delta+=d*weight[:,None]
    after=before+delta
    # Keep the visible lids in front of the globe, without projecting cavity walls.
    for side in [-1,1]:
        dx=after[:,0]-side*CX;dz=after[:,2]-Z0-CZ
        rad=dx*dx+dz*dz
        old_rad=(x-side*OLD_X)**2+(z-OLD_Z)**2
        old_sphere=OLD_Y-np.sqrt(np.maximum(0,RADIUS**2-old_rad))
        skin=(y<=old_sphere+.001)&(normals[:,1]<.30)&affected&(rad<RADIUS**2)
        v=np.clip(side*dx/HALF_WIDTH,-1,1)
        sine=np.sqrt(np.maximum(0,1-v*v))
        upper=.0004+.0021*v+.0044*sine**2.0*(1-.12*v)
        lower=.0004+.0021*v-.0045*sine**1.80*(1+.08*v)
        outside=(np.abs(dx)>=HALF_WIDTH)|(dz>=upper-.00010)|(dz<=lower+.00010)
        covered=skin&outside
        sphere=CY-np.sqrt(np.maximum(0,RADIUS**2-rad))-.00055
        a,b=after[:,1],sphere;k=.00035
        fitted=np.minimum(a,b)-k/4*np.maximum(0,1-np.abs(a-b)/k)**2
        after[covered,1]=fitted[covered]
    # Fair the sewn outer annulus while pinning the actual lid opening. Unequal
    # grid and rim edge spacing otherwise leaves tiny scalloped surface marks.
    edges=np.empty(len(head.data.edges)*2,dtype=np.int32)
    head.data.edges.foreach_get('vertices',edges);edges=edges.reshape(-1,2)
    edges=edges[(fair[edges]>0).any(axis=1)];ea,eb=edges[:,0],edges[:,1]
    degree=np.maximum(1,np.bincount(ea,minlength=len(before))+np.bincount(eb,minlength=len(before)))
    for _ in range(24):
        mean=(np.bincount(ea,weights=after[eb,1],minlength=len(before))
              +np.bincount(eb,weights=after[ea,1],minlength=len(before)))/degree
        after[:,1]+=.15*fair*(mean-after[:,1])
    assign(head,after)
    assert np.array_equal(before[~affected].astype(np.float32),coords(head)[~affected].astype(np.float32))
    new_tree=tree_for(head)

    # Lower and shape brows; preserve hair elsewhere through independent material copies.
    brow_mat=bpy.data.materials['Hair · dark umber'].copy();brow_mat.name='Brows · warm umber'
    brow_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.030,.019,.012,1)
    for side in [-1,1]:
        foundation=bpy.data.objects['Brow · dense tapered foundation '+str(side)]
        vv=[]
        for i in range(65):
            t=i/64;xx=side*(.012+.048*t)
            zz=.1426+.0017*math.sin(math.pi*t)+.0018*t
            half=.0021*math.sin(math.pi*t)**.45
            for zz2 in [zz-half,zz+half]:
                vv.append((xx,surface_y(new_tree,xx,Z0+zz2)-.0004,Z0+zz2))
        assign(foundation,vv);foundation.data.materials[0]=brow_mat
        for i in range(34):
            obj=bpy.data.objects['Brow strand %d %02d'%(side,i)]
            t=i/33
            ox=side*(.014+.045*t);oz=.1495+.0015*math.sin(math.pi*t)+.0025*t
            nx=side*(.013+.046*t);nz=.1426+.0017*math.sin(math.pi*t)+.0018*t
            vv=coords(obj)
            for p in vv:
                old_y=surface_y(old_tree,p[0],p[2])
                offset=p[1]-old_y
                p[0]+=nx-ox;p[2]+=nz-oz
                p[1]=surface_y(new_tree,p[0],p[2])+offset
            assign(obj,vv);obj.data.materials[0]=brow_mat

    sclera=bpy.data.materials['Sclera · ivory grey']
    sclera.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.38,.385,.36,1)
    iris_mat=bpy.data.materials['Iris · layered slate blue'];pupil_mat=bpy.data.materials['Pupil']
    lash_mat=brow_mat
    tear_mat=bpy.data.materials.new('Tear line · muted warm skin');tear_mat.use_nodes=True
    tear_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.25,.10,.067,1)
    tear_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.38
    cornea=bpy.data.materials.new('Cornea · transparent wet highlight');cornea.use_nodes=True
    nodes=cornea.node_tree.nodes;links=cornea.node_tree.links;nodes.clear()
    output=nodes.new('ShaderNodeOutputMaterial');mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.26
    transparent=nodes.new('ShaderNodeBsdfTransparent');glass=nodes.new('ShaderNodeBsdfGlass')
    glass.inputs['IOR'].default_value=1.376;glass.inputs['Roughness'].default_value=.065
    links.new(transparent.outputs[0],mix.inputs[1]);links.new(glass.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],output.inputs[0])
    for side in [-1,1]:
        globe=bpy.data.objects['Ocular globe '+str(side)];globe.location=(side*CX,CY,Z0+CZ)
        pupil=bpy.data.objects['Pupil '+str(side)]
        pupil.location=tuple(gaze_points([(0,-RADIUS-.00034,0)],side)[0])
        pupil.scale=(.0026,.00022,.0026);pupil.rotation_euler[2]=-side*GAZE
        # Curved slate-blue iris, radial fibers and limbus; no flat colored disc.
        n,nr=128,28;vv=[(0,-RADIUS-.00023,0)];colors=[(.015,.025,.030,1)];ff=[]
        for row in range(1,nr+1):
            r=IRIS_RADIUS*row/nr
            for j in range(n):
                a=j*2*math.pi/n;xx=r*math.cos(a);zz=r*math.sin(a)
                yy=-math.sqrt(RADIUS**2-r*r)-.00023
                fiber=.82+.13*math.sin(a*91+math.sin(r*2300))+.05*math.sin(a*47-r*1800)
                edge=1-.76*smooth(.82,1,r/IRIS_RADIUS)
                inner=1-.65*(1-smooth(.31,.49,r/IRIS_RADIUS))
                value=fiber*edge*inner
                colors.append((.064*value,.098*value,.120*value,1));vv.append((xx,yy,zz))
        for j in range(n):ff.append((0,1+j,1+(j+1)%n))
        for row in range(nr-1):
            for j in range(n):ff.append((1+row*n+j,1+row*n+(j+1)%n,1+(row+1)*n+(j+1)%n,1+(row+1)*n+j))
        mesh_object('Radial iris '+str(side),gaze_points(vv,side).tolist(),ff,iris_mat,eyes,colors)
        # Transparent corneal cap; its rim remains behind the surrounding eyelids.
        vv=[(0,-RADIUS-.00063,0)];ff=[];n,nr=128,32;cap_radius=.0085
        for row in range(1,nr+1):
            r=cap_radius*row/nr
            for j in range(n):
                a=j*2*math.pi/n
                yy=-math.sqrt(RADIUS**2-r*r)-.00023-.0004*(1-(r/cap_radius)**2)**2
                vv.append((r*math.cos(a),yy,r*math.sin(a)))
        for j in range(n):ff.append((0,1+j,1+(j+1)%n))
        for row in range(nr-1):
            for j in range(n):ff.append((1+row*n+j,1+row*n+(j+1)%n,1+(row+1)*n+(j+1)%n,1+(row+1)*n+j))
        mesh_object('Corneal wet surface '+str(side),gaze_points(vv,side).tolist(),ff,cornea,eyes)
        for upper in [True,False]:
            vv=[];ff=[]
            for i in range(129):
                a=i*math.pi/128 if upper else math.pi+i*math.pi/128
                dx,dz=eyelid(np.array(a),side);width=(.00034 if upper else .00018)*max(0,math.sin(math.pi*i/128))**.35
                for offset in [0,width if upper else -width]:
                    old_dx=.0158*math.cos(a)
                    old_dz=(.005*max(0,math.sin(a))**.65 if upper else -.0045*max(0,-math.sin(a))**.90)+side*.0018*math.cos(a)
                    hood=.0016*math.exp(-(old_dx/.025)**2)*math.exp(-((OLD_Z+old_dz-.143)/.010)**2)
                    hood+=.0007*math.exp(-(old_dx/.024)**2)*math.exp(-((OLD_Z+old_dz-.116)/.007)**2)
                    yy=CY-math.sqrt(max(1e-6,RADIUS**2-float(dx)**2-(float(dz)+offset)**2))-.00080-hood
                    vv.append((side*CX+float(dx),yy,Z0+CZ+float(dz)+offset))
            for i in range(128):ff.append((2*i,2*i+1,2*i+3,2*i+2))
            name=('Upper ciliary edge ' if upper else 'Lower tear meniscus ')+str(side)
            mesh_object(name,vv,ff,lash_mat if upper else tear_mat,eyes)
    assert signature(head,eyes)==locked
    # A saved bilateral close-up supports approval without changing the studio lights.
    camera_data=bpy.data.cameras.new('Eye review · frontal detail')
    camera=bpy.data.objects.new('Head review · EyesFront',camera_data)
    bpy.data.collections['99 · neutral portrait studio'].objects.link(camera)
    camera.location=(0,-1.2,Z0+.136)
    camera.rotation_euler=(Vector((0,0,Z0+.136))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO';camera_data.ortho_scale=.155
    head['eye_revision']=REVISION
    head['eye_scope']='Eyes, eyelids, brows and local orbital integration only; pending approval'
    bpy.context.scene['eye_revision']=REVISION
    bpy.context.scene['eye_review_status']='pending_visual_approval'
    result=dict(revision=REVISION,head_vertices=len(before),head_faces=len(head.data.polygons),
                head_topology_unchanged=True,nonorbital_vertices_unchanged=int((~affected).sum()),
                protected_meshes_unchanged=True,remesh_applied=False)
    print('EYE_REVIEW',json.dumps(result),flush=True)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    args=sys.argv[sys.argv.index('--')+1:] if '--'in sys.argv else []
    options=parser.parse_args(args)
    refine_eye_likeness(bpy.data.objects['Aren · dense facial sculpt'])
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(options.output.resolve()),compress=True)
