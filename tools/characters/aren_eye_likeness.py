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
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

BASE_REVISION = 'eye_likeness_01'
SURFACE_REVISION = 'eye_likeness_02'
EXPRESSION_REVISION = 'eye_likeness_03'
REVISION = 'eye_likeness_04'
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


def _refine_eye_likeness_01(head):
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
    head['eye_revision']=BASE_REVISION
    head['eye_scope']='Eyes, eyelids, brows and local orbital integration only; pending approval'
    bpy.context.scene['eye_revision']=BASE_REVISION
    bpy.context.scene['eye_review_status']='pending_visual_approval'
    result=dict(revision=BASE_REVISION,head_vertices=len(before),head_faces=len(head.data.polygons),
                head_topology_unchanged=True,nonorbital_vertices_unchanged=int((~affected).sum()),
                protected_meshes_unchanged=True,remesh_applied=False)
    print('EYE_REVIEW',json.dumps(result),flush=True)
    return result


def _refine_eye_surface_02(head):
    """Fair the local lid seam without changing mesh connectivity or eye centers."""
    eyes=bpy.data.collections['03 · HIGH · eyes and brows']
    locked=signature(head,eyes)
    before=coords(head);after=before.copy();N=len(before)
    norm=np.empty(N*3,np.float32);head.data.vertices.foreach_get('normal',norm);norm=norm.reshape(-1,3)
    old_tree=tree_for(head)
    # Reposition the existing 30 skin rows and six cavity rows.
    # Monotone angular sampling removes backtracking at the stepped grid seam.
    patches=0
    for cap in head.data.polygons:
        if len(cap.vertices)!=188 or abs(cap.center.z-Z0-CZ)>.008:continue
        n=188;first=cap.index-36*n;ids=[]
        for k in range(30):ids.append([head.data.polygons[first+k*n+j].vertices[0] for j in range(n)])
        ids.append([head.data.polygons[first+29*n+j].vertices[3] for j in range(n)])
        ids=np.array(ids);outer=before[ids[0]].copy();side=1 if outer[:,0].mean()>0 else -1
        q=(outer[:,[0,2]]-[side*CX,Z0+CZ])/[.021,.010]
        theta=np.unwrap(np.arctan2(q[:,1],q[:,0]));direction=np.sign(np.median(np.diff(theta)))
        increments=np.linalg.norm(np.roll(q,-1,axis=0)-q,axis=1)
        angle=theta[0]+direction*2*math.pi*np.r_[0,np.cumsum(increments[:-1])]/increments.sum()
        xx,zz=eyelid(angle,side)
        hood=.0016*np.exp(-(.0158*np.cos(angle)/.025)**2)*np.exp(-((.128+.005*np.maximum(0,np.sin(angle))**.65+side*.0018*np.cos(angle)-.143)/.010)**2)
        hood+=.0007*np.exp(-(.0158*np.cos(angle)/.024)**2)*np.exp(-((.128-.0045*np.maximum(0,-np.sin(angle))**.90+side*.0018*np.cos(angle)-.116)/.007)**2)
        inner=np.column_stack((side*CX+xx,CY-np.sqrt(np.maximum(1e-6,RADIUS**2-xx*xx-zz*zz))-.00055-hood,Z0+CZ+zz))
        for k in range(1,31):
            t=k/30;after[ids[k],0]=outer[:,0]*(1-t)+inner[:,0]*t;after[ids[k],2]=outer[:,2]*(1-t)+inner[:,2]*t
            after[ids[k],1]=before[ids[k],1]*(1-t**5)+inner[:,1]*t**5
        # Relax interior parameter rows with both boundary loops pinned. This
        # removes compressed columns beside the canthi without resampling faces.
        patch=after[ids].copy()
        for _ in range(1600):
            radial=(patch[:-2]+patch[2:])*2
            around=(np.roll(patch[1:-1],1,axis=1)+np.roll(patch[1:-1],-1,axis=1))*.5
            patch[1:-1,:,0]=(radial+around)[:,:,0]/5
            patch[1:-1,:,2]=(radial+around)[:,:,2]/5
        after[ids]=patch
        for layer in range(1,7):
            row=np.array([head.data.polygons[first+(29+layer)*n+j].vertices[3] for j in range(n)])
            after[row]=inner
            after[row,0]=side*CX+(inner[:,0]-side*CX)*(1-.22*layer/6)
            after[row,2]=Z0+CZ+(inner[:,2]-Z0-CZ)*(1-.22*layer/6)
            after[row,1]+= .034*layer/6
        patches+=1

    assert patches==2, 'Expected two native 188-column orbital annuli'
    for side in [-1,1]:
        dx=before[:,0]-side*CX;dz=before[:,2]-Z0-CZ
        rho=np.sqrt((dx/.031)**2+(dz/.025)**2)
        sphere=CY-np.sqrt(np.maximum(0,RADIUS**2-dx*dx-dz*dz))
        visible=(before[:,1]<sphere+.0005)&(norm[:,1]<.15)&(rho<1.16)
        source=np.where(visible)[0]
        # Equal-area samples prevent the dense annulus from outweighing the facial grid.
        bins=np.floor(before[source][:,[0,2]]/.00032).astype(int)
        _,inv=np.unique(bins,axis=0,return_inverse=True)
        count=np.bincount(inv);samples=np.column_stack([np.bincount(inv,weights=before[source,j])/count for j in range(3)])
        tree=KDTree(len(samples))
        for i,p in enumerate(samples):tree.insert((p[0],p[2],0),i)
        tree.balance()
        angles=np.linspace(0,2*math.pi,513);ex,ez=eyelid(angles,side)
        curve=KDTree(len(angles))
        for i,(xx,zz)in enumerate(zip(ex+side*CX,ez+Z0+CZ)):curve.insert((xx,zz,0),i)
        curve.balance()
        changed=0
        target=np.where((after[:,1]<sphere+.0015)&(rho<1))[0]
        for idx in target:
            p=after[idx].copy();dist=curve.find((p[0],p[2],0))[2]
            weight=float(smooth(.00025,.0015,dist)*(1-smooth(.76,1.0,rho[idx])))
            if weight==0:continue
            nearby=tree.find_range((p[0],p[2],0),.0048)
            if len(nearby)<12:raise RuntimeError('Insufficient orbital surface samples')
            ids=np.array([v[1]for v in nearby]);q=samples[ids]
            uv=(q[:,[0,2]]-p[[0,2]])/.002
            w=np.exp(-np.sum(uv*uv,axis=1)/1.1**2)
            A=np.column_stack([np.ones(len(q)),uv,uv[:,0]**2,uv[:,0]*uv[:,1],uv[:,1]**2])
            M=A.T@(w[:,None]*A)+np.eye(6)*1e-9;b=A.T@(w*q[:,1])
            fitted=np.linalg.solve(M,b)[0]
            after[idx,1]+=weight*np.clip(fitted-p[1],-.003,.003)
            changed+=1
        print('MLS',side,len(source),len(samples),changed,flush=True)
    assign(head,after)
    # Reattach brows and refine their arch using the enlarged reference.
    # The medial root sits lower; the outer half rises without a rounded high arch.
    new_tree=tree_for(head)
    for obj in bpy.data.collections['03 · HIGH · eyes and brows'].objects:
        if not obj.name.startswith(('Brow strand','Brow · dense')):continue
        vv=coords(obj)
        if obj.name.startswith('Brow strand'):
            t=int(obj.name.split()[-1])/33
            shift=-.0006+.0023*math.sin(math.pi*t)-.0001*t
            for p in vv:
                offset=p[1]-surface_y(old_tree,p[0],p[2]);p[2]+=shift
                p[1]=surface_y(new_tree,p[0],p[2])+offset
        else:
            for i,p in enumerate(vv):
                t=(i//2)/64
                offset=p[1]-surface_y(old_tree,p[0],p[2])
                p[2]+=-.0006+.0023*math.sin(math.pi*t)-.0001*t
                p[1]=surface_y(new_tree,p[0],p[2])+offset
        assign(obj,vv)
    assert signature(head,eyes)==locked
    assert np.array_equal(before[before[:,2]<1.540],coords(head)[before[:,2]<1.540])
    head['eye_revision']=SURFACE_REVISION
    bpy.context.scene['eye_revision']=SURFACE_REVISION
    bpy.context.scene['eye_review_status']='pending_visual_approval'
    result=dict(revision=SURFACE_REVISION,head_topology_unchanged=True,
                protected_meshes_unchanged=True,remesh_applied=False)
    print('EYE_SURFACE',json.dumps(result),flush=True)
    return result


def _refine_eye_expression_03(head):
    """Refine canthal tilt, upper opening and local expression on revision 02."""
    eyes=bpy.data.collections['03 · HIGH · eyes and brows']
    locked=signature(head,eyes)
    before=coords(head);old_tree=tree_for(head)
    def deform(points):
        result=points.copy()
        for side in [-1,1]:
            dx=points[:,0]-side*CX;dz=points[:,2]-Z0-CZ
            rho=np.sqrt((dx/.029)**2+(dz/.025)**2)
            v=np.clip(side*dx/HALF_WIDTH,-1,1);sn=np.sqrt(np.maximum(0,1-v*v))
            upper=dz>=.0004+.0021*v
            old_amp=np.where(upper,.0044*sn**2*(1-.12*v),-.0045*sn**1.8*(1+.08*v))
            new_amp=np.where(upper,.0056*sn**1.6*(1-.22*v),-.0045*sn**1.65*(1+.10*v))
            old_edge=.0004+.0021*v+old_amp
            weight=(1-smooth(.64,1,rho))*(1-smooth(-.010,.020,points[:,1]))*np.exp(-((dz-old_edge)/.010)**2)*(1-smooth(.008,.012,np.abs(dz)))
            delta=(-.00145*v+new_amp-old_amp)*weight
            rad=dx*dx+dz*dz
            sphere=CY-np.sqrt(np.maximum(0,RADIUS**2-rad))
            skin=1-smooth(.0005,.004,points[:,1]-sphere)
            depth=np.sqrt(np.maximum(.000036,RADIUS**2-rad))
            result[:,1]+=np.clip(delta*dz/depth,-.001,.001)*skin*np.exp(-((dz-old_edge)/.0035)**2)*(1-smooth(.88,1.05,rad/RADIUS**2))
            result[:,2]+=delta
        return result
    assign(head,deform(before));new_tree=tree_for(head)
    for obj in eyes.objects:
        if obj.name.startswith(('Brow strand','Brow · dense')):
            vv=coords(obj)
            strand=obj.name.startswith('Brow strand')
            for i,p in enumerate(vv):
                t=int(obj.name.split()[-1])/33 if strand else (i//2)/64
                old_center=.1420+.0040*math.sin(math.pi*t)+.0017*t
                new_center=.1408+.0023*math.sin(math.pi*t)+.0022*t
                offset=p[1]-surface_y(old_tree,p[0],p[2])
                p[2]=Z0+new_center+(p[2]-Z0-old_center)*(1.20-.10*t)
                p[1]=surface_y(new_tree,p[0],p[2])+offset
            assign(obj,vv)
        elif obj.name.startswith(('Upper ciliary edge','Lower tear meniscus')):
            assign(obj,deform(coords(obj)))
    # A small lacrimal caruncle at the medial corner, shaded in muted warm skin.
    mat=bpy.data.materials.get('Lacrimal caruncle · warm muted skin') or bpy.data.materials.new('Lacrimal caruncle · warm muted skin');mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.28,.16,.12,1);bs.inputs['Roughness'].default_value=.38
    for side in [-1,1]:
        dx=-side*.0151;dz=.0004+.00065*(-.0151/HALF_WIDTH)
        center=np.array((side*CX+dx,CY-math.sqrt(RADIUS**2-dx*dx-dz*dz)-.00075,Z0+CZ+dz))
        vv=[];ff=[];n=32;nr=16
        # Closed UV sphere with unique poles.
        vv.append(tuple(center+np.array((0,0,.00035))))
        for row in range(1,nr):
            phi=math.pi*row/nr
            for j in range(n):
                a=2*math.pi*j/n
                vv.append(tuple(center+np.array((.00055*math.sin(phi)*math.cos(a),.00025*math.sin(phi)*math.sin(a),.00035*math.cos(phi)))))
        bottom=len(vv);vv.append(tuple(center+np.array((0,0,-.00035))))
        for j in range(n):ff.append((0,1+j,1+(j+1)%n))
        for row in range(nr-2):
            for j in range(n):ff.append((1+row*n+j,1+(row+1)*n+j,1+(row+1)*n+(j+1)%n,1+row*n+(j+1)%n))
        for j in range(n):ff.append((bottom,1+(nr-2)*n+(j+1)%n,1+(nr-2)*n+j))
        mesh_object('Lacrimal caruncle '+str(side),vv,ff,mat,eyes)
    for side in [-1,1]:
        pupil=bpy.data.objects['Pupil '+str(side)];pupil.scale.x=.00225;pupil.scale.z=.00225
    assert signature(head,eyes)==locked
    assert np.array_equal(before[before[:,2]<1.540],coords(head)[before[:,2]<1.540])
    head['eye_revision']=EXPRESSION_REVISION
    bpy.context.scene['eye_revision']=EXPRESSION_REVISION
    bpy.context.scene['eye_review_status']='pending_visual_approval'
    print('EYE_EXPRESSION',EXPRESSION_REVISION,flush=True)
    return dict(revision=EXPRESSION_REVISION,head_topology_unchanged=True,
                protected_meshes_unchanged=True,remesh_applied=False)


def _refine_eye_style_04(head):
    """Match the enlarged reference's lid drawing, iris coverage and painted finish."""
    eyes=bpy.data.collections['03 · HIGH · eyes and brows']
    bpy.context.view_layer.update()
    locked=signature(head,eyes)
    before=coords(head);old_tree=tree_for(head)
    def curve(x,knots,values):
        k=np.array(knots);v=np.array(values);d=np.diff(v)/np.diff(k);m=np.r_[d[0],(d[:-1]+d[1:])/2,d[-1]]
        m[1:-1]=np.where(d[:-1]*d[1:]<=0,0,m[1:-1]);i=np.clip(np.searchsorted(k,x)-1,0,len(k)-2)
        h=k[i+1]-k[i];t=np.clip((x-k[i])/h,0,1)
        return (2*t**3-3*t*t+1)*v[i]+(t**3-2*t*t+t)*h*m[i]+(-2*t**3+3*t*t)*v[i+1]+(t**3-t*t)*h*m[i+1]
    def edge(v,upper):
        if upper:return curve(v,[-1,-.72,-.35,.10,.55,.85,1],[-.00025,.0032,.00525,.00555,.0039,.00185,.00105])-.0013
        return curve(v,[-1,-.65,-.1,.45,.8,1],[-.00025,-.0027,-.0037,-.0028,-.0009,.00105])-.0013
    def deform(points):
        result=points.copy()
        for side in [-1,1]:
            dx=points[:,0]-side*CX;dz=points[:,2]-Z0-CZ
            rho=np.sqrt((dx/.029)**2+(dz/.025)**2);v=np.clip(side*dx/HALF_WIDTH,-1,1);sn=np.sqrt(np.maximum(0,1-v*v))
            upper=dz>=.0004+.00065*v
            old_edge=.0004+.00065*v+np.where(upper,.0056*sn**1.6*(1-.22*v),-.0045*sn**1.65*(1+.10*v))
            target=np.where(upper,edge(v,True),edge(v,False))
            w=(1-smooth(.64,1,rho))*(1-smooth(-.010,.020,points[:,1]))*np.exp(-((dz-old_edge)/.010)**2)*(1-smooth(.008,.012,np.abs(dz)))
            delta=(target-old_edge)*w
            rad=dx*dx+dz*dz;sphere=CY-np.sqrt(np.maximum(0,RADIUS**2-rad));skin=1-smooth(.0005,.004,points[:,1]-sphere)
            result[:,1]+=np.clip(delta*dz/np.sqrt(np.maximum(.000036,RADIUS**2-rad)),-.001,.001)*skin*np.exp(-((dz-old_edge)/.0035)**2)*(1-smooth(.88,1.05,rad/RADIUS**2))
            result[:,2]+=delta
        return result
    assign(head,deform(before));new_tree=tree_for(head)
    # Paint only the immediate lid planes and one subtle upper crease.
    points=coords(head);layer=head.data.color_attributes['Tone'];col=np.empty(len(points)*4,np.float32);layer.data.foreach_get('color',col);col=col.reshape(-1,4)
    for side in [-1,1]:
        dx=points[:,0]-side*CX;dz=points[:,2]-Z0-CZ;v=np.clip(side*dx/HALF_WIDTH,-1,1);sn=np.sqrt(np.maximum(0,1-v*v))
        rho=np.sqrt((dx/.030)**2+(dz/.023)**2);mask=(1-smooth(.70,1,rho))*(1-smooth(-.030,-.005,points[:,1]))
        crease=np.exp(-((dz-edge(v,True)-.00135)/.00032)**2)*sn**1.3*mask
        tint=np.array((.26,.135,.080,1));col[:,:3]=col[:,:3]*(1-.30*crease[:,None])+tint[:3]*(.30*crease[:,None])
        lower=np.exp(-((dz-edge(v,False)+.0017)/.0015)**2)*sn**1.5*mask
        col[:,:3]+=lower[:,None]*np.array((.011,.004,-.001))
    layer.data.foreach_set('color',col.ravel())
    # Varied brow tufts, with angular foundation and a fuller medial root.
    def brow_z(t):return curve(t,[0,.22,.60,.80,1],[.1403,.1412,.1437,.1440,.1416])
    base=bpy.data.materials['Brows · warm umber']
    shade=[]
    for j,color in enumerate([(.025,.016,.010,1),(.038,.024,.014,1),(.030,.019,.011,1)]):
        m=base.copy();m.name='Brow tuft · painted umber '+str(j);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=color;shade.append(m)
    for side in [-1,1]:
        foundation=bpy.data.objects['Brow · dense tapered foundation '+str(side)];vv=[]
        for i in range(65):
            t=i/64;x=side*(.012+.048*t);z=float(brow_z(t));half=(.00115+.0016*math.sin(math.pi*t)**.6)*(1-float(smooth(.68,1,t)))
            for row,zz in enumerate([z-half,z+half]):
                xx=x+side*(.00045 if row==0 else -.00035)*(1-float(smooth(0,.16,t)))
                vv.append((xx,surface_y(new_tree,xx,Z0+zz)-.00040,Z0+zz))
        assign(foundation,vv)
        m=base.copy();m.name='Brow foundation · painted umber '+str(side)
        node=m.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='BrowTone'
        m.node_tree.links.new(node.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
        foundation.data.materials[0]=m
        layer=foundation.data.color_attributes.new(name='BrowTone',type='FLOAT_COLOR',domain='POINT');tone=[]
        for i in range(65):
            t=i/64;value=.91+.065*math.sin(t*71)+.025*math.sin(t*27)
            tone.extend([( .020*value,.012*value,.007*value,1),(.037*value,.022*value,.012*value,1)])
        layer.data.foreach_set('color',np.array(tone,np.float32).ravel())
        for i in range(34):
            obj=bpy.data.objects['Brow strand %d %02d'%(side,i)];vv=coords(obj);t=i/33
            nt=np.clip(((i//4)*4+1.5)/33+(i%4-1.5)*.014,0,1)
            oldx=side*(.013+.046*t);oldz=Z0+.1408+.0023*math.sin(math.pi*t)+.0022*t
            nx=side*(.013+.046*nt);nz=Z0+float(brow_z(nt));theta=side*(.08+.52*t+.16*math.sin(i*2.3));c,s=math.cos(theta),math.sin(theta)
            length=(.78+.35*math.sin(i*.97+.3)**2)*(1-.65*float(smooth(.75,1,t)))
            for p in vv:
                offset=p[1]-surface_y(old_tree,p[0],p[2]);x,z=p[0]-oldx,(p[2]-oldz)*length
                p[0]=nx+c*x+s*z;p[2]=nz-s*x+c*z;p[1]=surface_y(new_tree,p[0],p[2])+offset
            if i<3:
                vv[:,0]-=side*.001
                for p in vv:p[1]=surface_y(new_tree,p[0],p[2])-.00065
            extent=np.max(side*vv[:,0])
            if extent>.060:
                vv[:,0]-=side*(extent-.060+.0001)
                for p in vv:p[1]=surface_y(new_tree,p[0],p[2])-.00062
            assign(obj,vv);obj.data.materials[0]=shade[(i//4)%3]
    # Eyelid line: tapered, darker and thicker over the outer half.
    lash=base.copy();lash.name='Upper lid · painted warm charcoal';p=lash.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.022,.014,.010,1);p.inputs['Roughness'].default_value=.78
    for side in [-1,1]:
        for upper in [True,False]:
            vv=[];ff=[]
            for i in range(129):
                a=i*math.pi/128 if upper else math.pi+i*math.pi/128;dx=HALF_WIDTH*math.cos(a);v=side*dx/HALF_WIDTH;z=float(edge(v,upper))
                width=(.00057*(.85+.25*v) if upper else .00014)*max(0,math.sin(math.pi*i/128))**.5
                if upper:width+=.00032*float(smooth(.55,1,v))
                for off in [0,width if upper else -width]:
                    zz=Z0+CZ+z+off
                    xx=side*CX+dx
                    hit,normal,_,_=new_tree.ray_cast(Vector((xx,-1,zz)),Vector((0,1,0)))
                    sphere=CY-math.sqrt(max(1e-6,RADIUS**2-dx*dx-(z+off)**2))-.0008
                    # Follow the full skin normal so the painted edge also clears
                    # the lid in profile, rather than offsetting only toward front.
                    if hit is not None and hit.y<=sphere+.001:
                        point=hit+normal*(.00016 if upper else .00008)
                        vv.append(tuple(point))
                    else:
                        vv.append((xx,sphere,zz))
            for i in range(128):ff.append((2*i,2*i+1,2*i+3,2*i+2))
            name=('Upper ciliary edge ' if upper else 'Lower tear meniscus ')+str(side)
            mat=lash if upper else bpy.data.objects[name].data.materials[0]
            mesh_object(name,vv,ff,mat,eyes)
    # Painted sclera: soft ivory below, muted upper half and warm corners.
    sclera=bpy.data.materials['Sclera · ivory grey'];p=sclera.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.52;p.inputs['Specular IOR Level'].default_value=.18
    node=sclera.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='EyeTone';sclera.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
    for side in [-1,1]:
        obj=bpy.data.objects['Ocular globe '+str(side)];vv=coords(obj);z=vv[:,2];x=vv[:,0]
        light=.72+.28*(1-smooth(-.004,.003,z));tone=np.ones((len(vv),4));tone[:,:3]=np.array((.30,.315,.30))*light[:,None]
        warm=smooth(.010,.016,np.abs(x));tone[:,:3]+=warm[:,None]*np.array((.012,-.008,-.012))
        layer=obj.data.color_attributes.new(name='EyeTone',type='FLOAT_COLOR',domain='POINT');layer.data.foreach_set('color',tone.astype(np.float32).ravel())
        # Broader painted iris sectors and a controlled dark upper half.
        obj=bpy.data.objects['Radial iris '+str(side)];vv=coords(obj);theta=-side*GAZE;c,s=math.cos(theta),math.sin(theta)
        xx=c*(vv[:,0]-side*CX)+s*(vv[:,1]-CY);zz=vv[:,2]-Z0-CZ;r=np.sqrt(xx*xx+zz*zz);a=np.arctan2(zz,xx)
        fiber=.86+.10*np.sin(29*a+.5*np.sin(9*a))+.06*np.sin(53*a-r*1500)
        limbus=1-.80*smooth(.82,1,r/IRIS_RADIUS);inner=1-.60*(1-smooth(.31,.49,r/IRIS_RADIUS));light=.60+.48*(1-smooth(-.0035,.004,zz))
        tone=np.ones((len(vv),4));tone[:,:3]=np.array((.050,.092,.140))*(fiber*limbus*inner*light)[:,None]
        obj.data.color_attributes['Tone'].data.foreach_set('color',tone.astype(np.float32).ravel())
    p=bpy.data.materials['Iris · layered slate blue'].node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.48;p.inputs['Specular IOR Level'].default_value=.22
    mat=bpy.data.materials['Cornea · transparent wet highlight']
    for node in mat.node_tree.nodes:
        if node.type=='MIX_SHADER':node.inputs[0].default_value=.13
        if node.type=='BSDF_GLASS':node.inputs['Roughness'].default_value=.035
    # Flush scale/location edits made by earlier stages before composing world matrices.
    bpy.context.view_layer.update()
    # Raise the optical axis three degrees; lids cover the upper iris as in the reference.
    for side in [-1,1]:
        center=Vector((side*CX,CY,Z0+CZ));rotation=Matrix.Rotation(math.radians(-3),4,'X')
        transform=Matrix.Translation(center)@rotation@Matrix.Translation(-center)
        for prefix in ['Radial iris ','Corneal wet surface ','Pupil ']:
            obj=bpy.data.objects[prefix+str(side)]
            if prefix=='Pupil ':obj.matrix_world=transform@obj.matrix_world
            else:
                vv=coords(obj);r=np.array(rotation)[:3,:3];vv=(vv-np.array(center))@r.T+np.array(center);assign(obj,vv)
        obj=bpy.data.objects['Lacrimal caruncle '+str(side)];vv=coords(obj);vv[:,2]-=.0013;assign(obj,vv)
    assert signature(head,eyes)==locked
    assert np.array_equal(before[before[:,2]<1.540],coords(head)[before[:,2]<1.540])
    head['eye_revision']=REVISION
    bpy.context.scene['eye_revision']=REVISION
    bpy.context.scene['eye_review_status']='pending_visual_approval'
    print('EYE_STYLE',REVISION,flush=True)
    return dict(revision=REVISION,head_topology_unchanged=True,
                protected_meshes_unchanged=True,remesh_applied=False)


def refine_eye_likeness(head):
    revision=head.get('eye_revision')
    if revision is None:
        _refine_eye_likeness_01(head)
        revision=BASE_REVISION
    if revision==BASE_REVISION:
        _refine_eye_surface_02(head)
        revision=SURFACE_REVISION
    if revision==SURFACE_REVISION:
        _refine_eye_expression_03(head)
        revision=EXPRESSION_REVISION
    if revision==EXPRESSION_REVISION:
        return _refine_eye_style_04(head)
    raise RuntimeError('Eye revision already applied or unsupported; open a baseline.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    args=sys.argv[sys.argv.index('--')+1:] if '--'in sys.argv else []
    options=parser.parse_args(args)
    refine_eye_likeness(bpy.data.objects['Aren · dense facial sculpt'])
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(options.output.resolve()),compress=True)
