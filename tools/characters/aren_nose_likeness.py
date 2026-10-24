"""Nose-only likeness study on Aren's dense head; eye revision 04 is held."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from aren_eye_likeness import coords,assign,smooth,tree_for,surface_y,Z0

FOUNDATION_REVISION='nose_likeness_01'
TIP_REVISION='nose_likeness_02'
REVISION='nose_likeness_03'


def protected_signature(head):
    digest=hashlib.sha256()
    for obj in sorted(bpy.data.objects,key=lambda o:o.name):
        if obj.type!='MESH' or obj==head:continue
        digest.update(obj.name.encode());digest.update(coords(obj).astype(np.float32).tobytes())
        digest.update(np.array(obj.matrix_basis).tobytes())
        for layer in obj.data.color_attributes:
            values=np.empty(len(layer.data)*4,np.float32);layer.data.foreach_get('color',values)
            digest.update(values.tobytes())
    return digest.hexdigest()


def _refine_nose_foundation(head):
    if head.get('nose_revision'):
        raise RuntimeError('Nose revision already applied; open the unmodified baseline.')
    if head.get('eye_revision')!='eye_likeness_04':
        raise RuntimeError('Nose review requires the held eye_likeness_04 source.')
    bpy.context.view_layer.update()
    locked=protected_signature(head)
    before=coords(head);a=before.copy();tree=tree_for(head)
    def curve(x,k,v):
        k=np.array(k);v=np.array(v);d=np.diff(v)/np.diff(k);m=np.r_[d[0],(d[:-1]+d[1:])/2,d[-1]];m[1:-1]=np.where(d[:-1]*d[1:]<=0,0,m[1:-1])
        i=np.clip(np.searchsorted(k,x)-1,0,len(k)-2);span=k[i+1]-k[i];t=np.clip((x-k[i])/span,0,1)
        return (2*t**3-3*t*t+1)*v[i]+(t**3-2*t*t+t)*span*m[i]+(-2*t**3+3*t*t)*v[i+1]+(t**3-t*t)*span*m[i+1]
    x,y,z=before[:,0],before[:,1],before[:,2]-Z0
    # Shape the nostril openings and their connected cavity surfaces together.
    for side in [-1,1]:
        dx=x-side*.0095;dz=z-.0765;rho=np.sqrt((dx/.0068)**2+(dz/.0048)**2)
        w=(1-smooth(.60,1,rho))*(1-smooth(-.055,-.025,y))
        theta=side*math.radians(11);c,s=math.cos(theta),math.sin(theta)
        nx=c*(dx*1.34)-s*(dz*.80);nz=s*(dx*1.34)+c*(dz*.80)
        a[:,0]+=(nx-dx)*w;a[:,2]+=(nz-dz)*w
    x,y,z=a[:,0].copy(),a[:,1].copy(),a[:,2].copy()-Z0
    visible=np.ones(len(a),bool);cavity_count=0
    for cap in head.data.polygons:
        if len(cap.vertices)==26 and abs(cap.center.z-Z0-.0765)<.008:
            cavity_count+=1
            first=cap.index-20*26
            for row in range(15,21):
                for j in range(26):visible[head.data.polygons[first+(row-1)*26+j].vertices[3]]=False
    assert cavity_count==2, 'Expected the two native nostril cavities'
    knots=[.062,.068,.072,.076,.080,.084,.090,.100,.110,.120,.130,.136]
    current=[surface_y(tree,0,Z0+zz)for zz in knots]
    target=[current[0],current[1],-.087,-.0985,-.1050,-.107,-.1040,-.0983,-.0917,-.0830,-.0750,current[-1]]
    old=curve(z,knots,current);desired=curve(z,knots,target)
    width=curve(z,[.062,.076,.084,.100,.120,.136],[.008,.0068,.0070,.007,.006,.006])
    mask=smooth(.066,.072,z)*(1-smooth(.130,.136,z))*(1-smooth(.020,.027,np.abs(x)))*(1-smooth(-.050,-.020,y))
    # Pin the complete eye/lid region, including the medial canthi.
    mask*=1-smooth(.008,.011,np.abs(x))*smooth(.108,.113,z)
    a[:,1]+=(desired-old)*np.exp(-(x/width)**4)*mask
    # Deliberate front and lateral planes through bridge and tip.
    bridge=desired+1.35*np.maximum(0,np.abs(x)-.0035)
    w=.72*smooth(.088,.097,z)*(1-smooth(.119,.129,z))*(1-smooth(.008,.014,np.abs(x)))*mask
    a[:,1]+=w*visible*(bridge-a[:,1])
    tip=desired+.80*np.maximum(0,np.abs(x)-.003)+2.0*np.maximum(0,np.abs(x)-.008)
    w=.56*smooth(.074,.080,z)*(1-smooth(.086,.096,z))*(1-smooth(.006,.010,np.abs(x)))*mask
    a[:,1]+=w*visible*(tip-a[:,1])
    # Separate the alar wings from the tip with a shallow lateral sulcus.
    a[:,1]+=.0009*np.exp(-((np.abs(x)-.0155)/.0028)**2-((z-.0785)/.0045)**2)*mask
    # Recess the connected cavities backward and upward from each alar opening.
    interior=[]
    for cap in head.data.polygons:
        if len(cap.vertices)==26 and abs(cap.center.z-Z0-.0765)<.008:
            first=cap.index-20*26;n=26
            rim=np.array([head.data.polygons[first+13*n+j].vertices[3]for j in range(n)])
            opening=a[rim].copy();center=opening.mean(axis=0)
            for row in range(15,21):
                u=(row-14)/6;ids=np.array([head.data.polygons[first+(row-1)*n+j].vertices[3]for j in range(n)])
                a[ids]=center+(opening-center)*(1-.18*u)+np.array((0,.007*u,.004*u))
                interior.append((ids,u))
    a[:,2]+=.0008*np.exp(-(x/.006)**4-((z-.082)/.006)**2)*mask
    assign(head,a)
    # Restrained painted tones follow the new bridge planes.
    col=np.empty(len(before)*4,np.float32);head.data.color_attributes['Tone'].data.foreach_get('color',col);col=col.reshape(-1,4)
    front=np.exp(-(x/.0045)**4)*smooth(.086,.096,z)*(1-smooth(.119,.130,z))*mask
    col[:,:3]+=front[:,None]*np.array((.025,.017,.009))
    side=(smooth(.0035,.006,np.abs(x))*(1-smooth(.010,.016,np.abs(x))))*smooth(.084,.096,z)*(1-smooth(.118,.128,z))*mask
    shade=np.where(x>0,.40,.20)*side
    col[:,:3]=col[:,:3]*(1-shade[:,None])+np.array((.32,.170,.095))*shade[:,None]
    tip_paint=np.exp(-(x/.0050)**4-((z-.084)/.004)**4)*mask
    col[:,:3]+=tip_paint[:,None]*np.array((.023,.014,.007))
    for ids,u in interior:
        t=float(smooth(0,.22,u));col[ids,:3]=col[ids,:3]*(1-t)+np.array((.07,.030,.015))*t
    head.data.color_attributes['Tone'].data.foreach_set('color',col.ravel())
    # A small painted shadow floor keeps the columella warm under the studio key.
    # Its scalar mask is exactly zero beyond the nose and inside the cavities.
    normals=np.empty(len(a)*3,np.float32);head.data.vertices.foreach_get('normal',normals);normals=normals.reshape(-1,3)
    bounce=.055*np.exp(-(x/.006)**4-((z-.076)/.0045)**2)*smooth(.15,.65,-normals[:,2])*mask*visible
    attribute=head.data.attributes.new(name='NoseBounce',type='FLOAT',domain='POINT')
    attribute.data.foreach_set('value',bounce.astype(np.float32))
    skin=head.data.materials[0].copy();skin.name='Nose · restrained painted underside fill'
    nodes=skin.node_tree.nodes;links=skin.node_tree.links;bsdf=nodes.get('Principled BSDF')
    tone=next(n for n in nodes if n.type=='VERTEX_COLOR' and n.layer_name=='Tone')
    strength=nodes.new('ShaderNodeAttribute');strength.attribute_name='NoseBounce'
    links.new(tone.outputs['Color'],bsdf.inputs['Emission Color'])
    links.new(strength.outputs['Fac'],bsdf.inputs['Emission Strength'])
    head.data.materials[0]=skin
    name='Head review · NoseFront';camera=bpy.data.objects.get(name)
    if camera is None:
        data=bpy.data.cameras.new('Nose review · front detail');camera=bpy.data.objects.new(name,data);bpy.data.collections['99 · neutral portrait studio'].objects.link(camera)
    data=camera.data
    camera.location=(0,-1.2,Z0+.097);camera.rotation_euler=(Vector((0,0,Z0+.097))-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=.115

    # Authoring stays scoped: eyes, mouth, silhouette and all other meshes are held.
    after=coords(head);xx,yy,zz=before.T
    held_eyes=(np.abs(xx)>=.011)&(zz>=1.553)
    outside=(np.abs(xx)>=.027)|(zz<=1.506)|(zz>=1.576)|(yy>=-.020)
    assert np.array_equal(before[held_eyes|outside],after[held_eyes|outside])
    assert protected_signature(head)==locked
    head['nose_revision']=FOUNDATION_REVISION
    scene=bpy.context.scene;scene['nose_revision']=FOUNDATION_REVISION
    scene['nose_review_status']='pending_visual_approval'
    scene['eye_review_status']='held_by_user';scene['active_feature_review']='nose'
    result=dict(revision=FOUNDATION_REVISION,head_topology_unchanged=True,
                protected_meshes_unchanged=True,eyes_held=True,remesh_applied=False)
    print('NOSE_REVIEW',json.dumps(result),flush=True)
    return result


def _refine_nose_tip_alae(head):
    """Apply the nose foundation once, then the bounded tip/alar refinement."""
    revision=head.get('nose_revision')
    if revision==TIP_REVISION:
        raise RuntimeError('Nose revision already applied; open the unmodified baseline.')
    if revision not in (None,FOUNDATION_REVISION):
        raise RuntimeError('Unsupported nose source revision: '+str(revision))
    if head.get('eye_revision')!='eye_likeness_04':
        raise RuntimeError('Nose review requires the held eye_likeness_04 source.')
    if revision is None:
        _refine_nose_foundation(head)
    bpy.context.view_layer.update()
    locked=protected_signature(head)
    tone_before=np.empty(len(head.data.vertices)*4,np.float32)
    head.data.color_attributes['Tone'].data.foreach_get('color',tone_before)

    before=coords(head);a=before.copy();x,y,z=before[:,0],before[:,1],before[:,2]-Z0
    support=smooth(.068,.072,z)*(1-smooth(.091,.099,z))*(1-smooth(.019,.024,np.abs(x)))*(1-smooth(-.050,-.020,y))
    cavities=[];visible=np.ones(len(a),bool)
    for cap in head.data.polygons:
        if len(cap.vertices)==26 and abs(cap.center.z-Z0-.0765)<.008:
            first=cap.index-20*26;n=26
            rows=[np.array([head.data.polygons[first+(row-1)*n+j].vertices[3] for j in range(n)]) for row in range(1,21)]
            cavities.append(rows)
            for ids in rows[14:]:visible[ids]=False
    assert len(cavities)==2
    # A rounded dome broadens the tip shoulders without extending its apex.
    r2=(x/.0105)**2+((z-.084)/.012)**2
    dome=-.1000-.0050*np.sqrt(np.maximum(0,1-r2))
    w=.72*(1-smooth(.58,.96,r2))*support*visible
    a[:,1]+=w*(dome-a[:,1])
    # Give each alar lobule a continuous body above and outside the aperture.
    lobule=np.exp(-((np.abs(x)-.0122)/.0042)**2-((z-.0794)/.0040)**2)*support
    a[:,1]-=.0016*lobule*visible
    # Tilt the opening under the wing; the lower rim recedes into the base.
    for rows in cavities:
        rim=rows[13];center=before[rim].mean(axis=0);dx=x-center[0];dz=z-(center[2]-Z0)
        local=np.exp(-(dx/.0055)**4-(dz/.0040)**4)*support
        a[:,1]+=.0016*np.tanh(-dz/.0014)*local*visible
        # Gently taper the medial corner and flatten the lower contour.
        side=np.sign(center[0]);medial=1-smooth(-.001,.002,side*dx)
        a[:,2]+=.00038*medial*np.exp(-(dx/.0045)**4-(dz/.003)**4)*support*visible
        taper=.28*(1-smooth(-.003,.002,side*dx))
        a[:,2]-=dz*taper*np.exp(-(dx/.0055)**4-(dz/.004)**4)*support*visible
        # Join the cavity to the altered opening, retaining its six native rows.
        opening=a[rim].copy();center=opening.mean(axis=0)
        for row,ids in enumerate(rows[14:],1):
            u=row/6
            depth=u*u*(2-u)
            a[ids]=center+(opening-center)*(1-.22*depth)+np.array((0,.007*depth,.0048*depth))
    assign(head,a)
    # Warm subdued lower rims avoid an isolated bright tube around the nares.
    col=np.empty(len(a)*4,np.float32);head.data.color_attributes['Tone'].data.foreach_get('color',col);col=col.reshape(-1,4)
    for rows in cavities:
        rim=rows[13];center=before[rim].mean(axis=0);dx=x-center[0];dz=z-(center[2]-Z0)
        w=(.25+.25*(1-smooth(-.0006,.0012,dz)))*np.exp(-(dx/.0050)**4-(dz/.0030)**4)*support*visible
        col[:,:3]=col[:,:3]*(1-w[:,None])+np.array((.32,.174,.104))*w[:,None]
    head.data.color_attributes['Tone'].data.foreach_set('color',col.ravel())

    held=(np.abs(x)>=.024)|(z<=.068)|(z>=.099)|(y>=-.020)
    assert np.array_equal(before[held],coords(head)[held])
    assert np.array_equal(tone_before.reshape(-1,4)[held],col[held])
    assert protected_signature(head)==locked
    head['nose_revision']=TIP_REVISION
    scene=bpy.context.scene;scene['nose_revision']=TIP_REVISION
    scene['nose_review_status']='pending_visual_approval'
    scene['eye_review_status']='held_by_user';scene['active_feature_review']='nose'
    result=dict(revision=TIP_REVISION,head_topology_unchanged=True,
                protected_meshes_unchanged=True,eyes_held=True,remesh_applied=False)
    print('NOSE_REVIEW',json.dumps(result),flush=True)
    return result


def refine_nose_likeness(head):
    """Upgrade a held-eye source through the noncumulative nose stages."""
    revision=head.get('nose_revision')
    if revision==REVISION:
        raise RuntimeError('Nose revision already applied; open the unmodified baseline.')
    if revision not in (None,FOUNDATION_REVISION,TIP_REVISION):
        raise RuntimeError('Unsupported nose source revision: '+str(revision))
    if head.get('eye_revision')!='eye_likeness_04':
        raise RuntimeError('Nose review requires the held eye_likeness_04 source.')
    if revision!=TIP_REVISION:
        _refine_nose_tip_alae(head)
    bpy.context.view_layer.update()
    locked=protected_signature(head)
    tone_before=np.empty(len(head.data.vertices)*4,np.float32)
    head.data.color_attributes['Tone'].data.foreach_get('color',tone_before)
    bounce_before=np.empty(len(head.data.vertices),np.float32)
    head.data.attributes['NoseBounce'].data.foreach_get('value',bounce_before)

    before=coords(head);a=before.copy();x,y,z=before[:,0],before[:,1],before[:,2]-Z0
    support=smooth(.066,.071,z)*(1-smooth(.090,.097,z))*(1-smooth(.019,.024,np.abs(x)))*(1-smooth(-.050,-.020,y))
    cavities=[];visible=np.ones(len(a),bool)
    for cap in head.data.polygons:
        if len(cap.vertices)==26 and abs(cap.center.z-Z0-.0765)<.008:
            first=cap.index-20*26;n=26
            rows=[np.array([head.data.polygons[first+j].vertices[0] for j in range(n)])]
            rows += [np.array([head.data.polygons[first+(row-1)*n+j].vertices[3] for j in range(n)]) for row in range(1,21)]
            cavities.append(rows)
            for ids in rows[15:]:visible[ids]=False
    assert len(cavities)==2
    # Continue the lobule toward the cheek with a shallow, broad alar sulcus.
    a[:,1]-=.0011*np.exp(-((np.abs(x)-.0135)/.0040)**2-((z-.0798)/.0042)**2)*support*visible
    a[:,1]+=.00055*np.exp(-((np.abs(x)-.0176)/.0020)**2-((z-.0788)/.0038)**2)*support*visible
    # Ease the projecting columella into the base without changing the apex.
    a[:,1]+=.0011*np.exp(-(x/.0042)**4-((z-.0733)/.0029)**2)*support*visible
    col=np.empty(len(a)*4,np.float32);head.data.color_attributes['Tone'].data.foreach_get('color',col);col=col.reshape(-1,4)
    crease=.14*np.exp(-((np.abs(x)-.0171)/.0023)**2-((z-.0788)/.0038)**2)*support*visible
    col[:,:3]=col[:,:3]*(1-crease[:,None])+np.array((.29,.140,.075))*crease[:,None]
    for rows in cavities:
        outer=a[rows[0]].copy();center=outer.mean(0)
        # Fit the opening to its local alar plane while retaining a nested
        # contour in front projection throughout the annulus and cavity.
        _,_,basis=np.linalg.svd(outer-center,full_matrices=False)
        inward=basis[-1].copy();inward*=np.sign(inward[1])
        assert inward[1]>.08
        # A smooth aperture stays strictly inside the stepped sewn boundary.
        # Retain each radial correspondence so loft sectors cannot cross.
        side=np.sign(center[0]);angle=side*math.radians(11)
        rotation=np.array(((math.cos(angle),-math.sin(angle)),(math.sin(angle),math.cos(angle))))
        metric=((outer-center)[:,[0,2]]@rotation)/np.array((.0027,.0010))
        edges=np.roll(metric,-1,axis=0)-metric
        t=np.clip(-np.sum(metric*edges,axis=1)/np.sum(edges*edges,axis=1),0,1)
        radius=.94*np.min(np.linalg.norm(metric+t[:,None]*edges,axis=1))
        length=np.linalg.norm(metric,axis=1);direction=metric/length[:,None]
        taper=1-.12*(1-smooth(-.2,.6,side*direction[:,0]))*(1-smooth(-.15,.5,direction[:,1]))
        opening=center+(outer-center)*(radius*taper/length)[:,None]
        opening[:,1]=center[1]-(inward[0]*(opening[:,0]-center[0])+inward[2]*(opening[:,2]-center[2]))/inward[1]
        center=opening.mean(0)
        rim_color=.62*col[rows[0],:3]+.38*np.array((.23,.110,.061))
        # Replace the flared annulus by a monotone loft with a restrained lip.
        for row in range(1,15):
            t=row/14;ids=rows[row]
            a[ids]=outer*(1-t)+opening*t
            a[ids,1]-=.00012*np.sin(np.pi*t)
            col[ids,:3]=col[rows[0],:3]*(1-t)+rim_color*t
        for row in range(15,21):
            u=(row-14)/6;depth=u*u*(2-u);ids=rows[row]
            a[ids]=center+(opening-center)*(1-.30*depth)+np.array((0,.012*depth,0))
            t=float(smooth(0,.45,u))
            col[ids,:3]=rim_color*(1-t)+np.array((.065,.027,.012))*t
    assign(head,a)
    head.data.color_attributes['Tone'].data.foreach_set('color',col.ravel())
    # A bounded painted shadow floor reduces the dark central wedge.
    normals=np.empty(len(a)*3,np.float32);head.data.vertices.foreach_get('normal',normals);normals=normals.reshape(-1,3)
    attr=head.data.attributes['NoseBounce'];bounce=np.empty(len(a),np.float32);attr.data.foreach_get('value',bounce)
    bounce+=.14*np.exp(-(x/.007)**4-((z-.0735)/.0045)**2)*smooth(.12,.65,-normals[:,2])*support*visible
    bounce+=.055*np.exp(-(x/.0045)**4-((z-.0720)/.0040)**2)*smooth(.25,.75,-normals[:,1])*support*visible
    attr.data.foreach_set('value',bounce)

    held=(np.abs(x)>=.024)|(z<=.066)|(z>=.097)|(y>=-.020)
    assert np.array_equal(before[held],coords(head)[held])
    assert np.array_equal(tone_before.reshape(-1,4)[held],col[held])
    assert np.array_equal(bounce_before[held],bounce[held])
    assert protected_signature(head)==locked
    head['nose_revision']=REVISION
    scene=bpy.context.scene;scene['nose_revision']=REVISION
    scene['nose_review_status']='pending_visual_approval'
    scene['eye_review_status']='held_by_user';scene['active_feature_review']='nose'
    result=dict(revision=REVISION,head_topology_unchanged=True,
                protected_meshes_unchanged=True,eyes_held=True,remesh_applied=False)
    print('NOSE_REVIEW',json.dumps(result),flush=True)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    args=sys.argv[sys.argv.index('--')+1:] if '--'in sys.argv else []
    options=parser.parse_args(args)
    refine_nose_likeness(bpy.data.objects['Aren · dense facial sculpt'])
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(options.output.resolve()),compress=True)
