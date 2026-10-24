"""Primary-volume pass for Aren's dense head; no resampling or feature edits.

Blender: open an unrefined source or the first volume pass, then run this file
with --output <blend>. The generator calls refine_primary_volumes directly.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np

BASE_REVISION = 'primary_volumes_01'
REVISION = 'primary_volumes_02'
Z0 = 1.44


def smooth(a, b, values):
    t = np.clip((values-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def gaussian(values, center, width):
    return np.exp(-((values-center)/width)**2)


def curve(knots, values, z):
    """Monotone Hermite interpolation avoids artificial rings between sections."""
    knots = np.asarray(knots, dtype=float)
    values = np.asarray(values, dtype=float)
    h = np.diff(knots)
    sec = np.diff(values)/h
    slopes = np.zeros_like(values)
    slopes[0], slopes[-1] = sec[0], sec[-1]
    for i in range(1, len(values)-1):
        if sec[i-1]*sec[i] > 0:
            w1, w2 = 2*h[i]+h[i-1], h[i]+2*h[i-1]
            slopes[i] = (w1+w2)/(w1/sec[i-1]+w2/sec[i])
    idx = np.clip(np.searchsorted(knots, z)-1, 0, len(knots)-2)
    t = np.clip((z-knots[idx])/h[idx], 0, 1)
    return ((2*t**3-3*t*t+1)*values[idx]
            +(t**3-2*t*t+t)*h[idx]*slopes[idx]
            +(-2*t**3+3*t*t)*values[idx+1]
            +(t**3-t*t)*h[idx]*slopes[idx+1])


def coordinates(obj):
    result = np.empty(len(obj.data.vertices)*3, dtype=np.float32)
    obj.data.vertices.foreach_get('co', result)
    return result.reshape(-1, 3).astype(np.float64)


def protected_digest(head):
    """All other mesh positions, topology and object transforms are immutable."""
    digest = hashlib.sha256()
    for obj in sorted(bpy.data.objects, key=lambda item: item.name):
        if obj.type != 'MESH' or obj == head:
            continue
        digest.update(obj.name.encode())
        digest.update(coordinates(obj).astype(np.float32).tobytes())
        digest.update(np.array(obj.matrix_world, dtype=np.float64).tobytes())
        loops = np.empty(len(obj.data.loops), dtype=np.int32)
        obj.data.loops.foreach_get('vertex_index', loops)
        digest.update(loops.tobytes())
    return digest.hexdigest()


def _refine_base_volumes(head):
    if head.get('volume_revision'):
        raise RuntimeError('Volume pass already applied; use the baseline source.')
    before = coordinates(head)
    digest_before = protected_digest(head)
    x, y, z = before[:, 0], before[:, 1], before[:, 2]-Z0
    ax = np.abs(x)
    # Recover the original circumference parameter without moving feature rings.
    old = [(-.095,.054,-.035,.062),(-.055,.046,-.035,.066),
           (-.025,.044,-.040,.068),(0,.030,-.080,.073),
           (.012,.042,-.085,.081),(.025,.057,-.085,.089),
           (.045,.065,-.082,.098),(.067,.075,-.078,.107),
           (.090,.079,-.079,.113),(.110,.080,-.073,.115),
           (.128,.079,-.071,.114),(.148,.078,-.075,.112),
           (.166,.077,-.076,.107),(.188,.074,-.073,.099),
           (.208,.063,-.064,.084),(.225,.043,-.040,.057),
           (.235,.004,.023,.031)]
    old = np.array(old)
    idx = np.clip(np.searchsorted(old[:,0], z)-1, 0, len(old)-2)
    a, b = old[idx], old[idx+1]
    p, q = old[np.maximum(0, idx-1)], old[np.minimum(len(old)-1, idx+2)]
    t = np.clip((z-a[:,0])/(b[:,0]-a[:,0]),0,1)
    h = b[:,0]-a[:,0]
    sections = []
    for j in [1,2,3]:
        ma=(b[:,j]-p[:,j])/(b[:,0]-p[:,0])
        mb=(q[:,j]-a[:,j])/(q[:,0]-a[:,0])
        sections.append((2*t**3-3*t*t+1)*a[:,j]
                        +(t**3-2*t*t+t)*h*ma
                        +(-2*t**3+3*t*t)*b[:,j]+(t**3-t*t)*h*mb)
    old_w, _, old_back = sections
    extra = .015*gaussian(z,0,.020)
    lo, hi = np.zeros(len(z)), np.full(len(z), math.pi/2)
    for _ in range(32):
        mid = (lo+hi)/2
        candidate = (old_w+extra*(1-np.cos(mid)))*np.sin(mid)
        lo = np.where(candidate < ax, mid, lo)
        hi = np.where(candidate < ax, hi, mid)
    angle = (lo+hi)/2
    c = np.cos(angle)
    back = y > .021
    back_c = np.clip((y-.021)/np.maximum(.001,old_back-.021),0,1)
    c = np.where(back,-back_c,c)
    sn = np.sqrt(np.maximum(0,1-c*c))*np.sign(x)

    knots = [-.095,-.060,-.035,-.015,0,.025,.055,.085,.115,.145,.185,.235]
    width = curve(knots,[.054,.047,.042,.037,.033,.049,.063,.072,.077,.078,.075,.004],z)
    front = curve(knots,[-.035,-.031,-.034,-.049,-.077,-.083,-.080,-.078,-.073,-.075,-.074,.023],z)
    rear = curve(knots,[.062,.064,.067,.071,.077,.088,.102,.112,.115,.112,.100,.031],z)
    cp = np.maximum(c,0)
    side = 1-cp
    target = before.copy()
    target[:,0] = (width+.006*gaussian(z,0,.027)*side)*sn
    target[:,1] = np.where(back,.021+(rear-.021)*back_c**.82,
                           .021+(front-.021)*cp**1.05)
    # Zygomatic projection and the softer subzygomatic hollow follow the sheet.
    target[:,1] -= .006*gaussian(ax,.054,.022)*gaussian(z,.103,.020)*cp
    target[:,1] += .003*gaussian(ax,.047,.022)*gaussian(z,.070,.023)*cp
    target[:,1] -= .0025*gaussian(x,0,.025)*gaussian(z,.012,.017)*cp
    # The mandibular border rises toward the ear instead of forming a level ring.
    lift = (.010*cp+.024*(1-cp)-.007*np.maximum(-c,0))
    target[:,2] += lift*gaussian(z,.004,.040)
    # Define the sternocleidomastoid gently, without adding separate bands.
    target[:,1] -= .0012*gaussian(ax,.025+np.maximum(-z,0)*.20,.009)*gaussian(z,-.045,.035)*cp

    # Exact protected feature zones; broad feathering into surrounding volumes.
    nose = np.sqrt((x/.025)**2+((z-.093)/.037)**2)
    mouth = np.sqrt((x/.038)**2+((z-.050)/.022)**2)
    eyes = np.minimum(np.sqrt(((x-.0345)/.025)**2+((z-.128)/.017)**2),
                      np.sqrt(((x+.0345)/.025)**2+((z-.128)/.017)**2))
    guard = np.minimum.reduce([smooth(1,1.90,nose),smooth(1,2.70,mouth),smooth(1,1.65,eyes)])
    guard = np.where(back,1,guard)
    volume_mask = np.where(back,1-smooth(.100,.145,z),1-smooth(.095,.135,z))*smooth(-.095,-.070,z)
    weight = guard*volume_mask
    # Bound each smooth displacement so the pinned feature transitions cannot fold.
    delta = target-before
    limits = np.column_stack((np.full(len(z),.0045),
                              .0075+.0075*(1-smooth(-.020,.020,z)),
                              .008+.010*(1-cp)))
    delta = limits*np.tanh(delta/limits)
    displacement = delta*weight[:,None]
    # Relax the displacement field, then the neck surface, over real adjacency.
    # This preserves dense topology and exact feature pins, while removing the
    # narrow contour ridges produced by blending a jaw correction into a pin.
    edges = np.empty(len(head.data.edges)*2,dtype=np.int32)
    head.data.edges.foreach_get('vertices',edges)
    edges=edges.reshape(-1,2)
    active=(weight>0)
    edges=edges[active[edges].any(axis=1)]
    a,b=edges[:,0],edges[:,1]
    degree=np.bincount(a,minlength=len(z))+np.bincount(b,minlength=len(z))
    degree=np.maximum(degree,1)
    def relax(points, strength, iterations):
        for _ in range(iterations):
            mean=np.column_stack([(np.bincount(a,weights=points[b,k],minlength=len(z))
                                   +np.bincount(b,weights=points[a,k],minlength=len(z)))/degree
                                  for k in range(3)])
            points+=strength[:,None]*(mean-points)
        return points
    displacement=relax(displacement,.45*active,280)
    after=before+displacement
    neck_ceiling=np.where(back,1-smooth(.045,.120,z),1-smooth(.012,.055,z))
    neck_mask=neck_ceiling*smooth(-.095,-.068,z)*guard
    after=relax(after,.40*neck_mask,420)
    head.data.vertices.foreach_set('co',after.astype(np.float32).ravel())
    head.data.update()
    head['volume_revision'] = BASE_REVISION
    head['scope'] = 'Primary head volumes, cheekbones, jaw, chin and neck only'
    fixed = (guard == 0) | (volume_mask == 0)
    assert np.array_equal(before[fixed].astype(np.float32),coordinates(head)[fixed].astype(np.float32))
    assert protected_digest(head) == digest_before
    assert np.isfinite(after).all()
    result = dict(revision=BASE_REVISION,vertices=len(after),polygons=len(head.data.polygons),
                  topology_unchanged=True,protected_meshes_unchanged=True,
                  feature_vertices_unchanged=int(fixed.sum()),
                  moved_vertices=int(np.count_nonzero(np.linalg.norm(after-before,axis=1)>1e-7)),
                  remesh_applied=False)
    print('VOLUME_PASS',json.dumps(result),flush=True)
    return result


def refine_primary_planes(head):
    """Continue the volume study with cheek, mandibular and mental planes."""
    if head.get('volume_revision') != BASE_REVISION:
        raise RuntimeError('Plane refinement requires the first volume pass exactly once.')
    before = coordinates(head)
    digest_before = protected_digest(head)
    x,y,z = before[:,0],before[:,1],before[:,2]-Z0
    ax=np.abs(x)
    front=1-smooth(.015,.075,y)
    region=smooth(-.095,-.075,z)*(1-smooth(.160,.180,z))*front
    nose=np.sqrt((x/.025)**2+((z-.093)/.037)**2)
    mouth=np.sqrt((x/.034)**2+((z-.050)/.014)**2)
    eyes=np.minimum(np.sqrt(((x-.0345)/.026)**2+((z-.128)/.019)**2),
                    np.sqrt(((x+.0345)/.026)**2+((z-.128)/.019)**2))
    ear=np.sqrt(((ax-.080)/.015)**2+((z-.111)/.034)**2+((y-.013)/.030)**2)
    guard=np.minimum.reduce([smooth(1,1.8,nose),smooth(1,2.2,mouth),
                             smooth(1,1.8,eyes),smooth(1,1.6,ear)])
    delta=np.zeros_like(before)
    # Narrow the lower cheek while keeping the zygomatic crest higher and broader.
    delta[:,0]-=np.sign(x)*.0036*gaussian(ax,.059,.025)*gaussian(z,.078,.037)
    delta[:,0]-=np.sign(x)*.0013*smooth(.060,.075,ax)*gaussian(z,.155,.023)
    delta[:,0]+=np.sign(x)*.0011*gaussian(ax,.065,.014)*gaussian(z,.110,.015)
    delta[:,1]-=.0037*gaussian(ax,.055,.020)*gaussian(z,.108,.018)
    delta[:,1]+=.0022*gaussian(ax,.048,.020)*gaussian(z,.076,.024)
    # An ascending mandibular border; no circular ridge around the neck.
    border=.015+.041*smooth(-.075,.030,y)
    lateral=smooth(.020,.048,ax)*(1-smooth(.040,.085,y))
    ridge=gaussian(z,border,.010)*lateral
    under=gaussian(z,border-.017,.016)*lateral
    delta[:,0]+=np.sign(x)*(.0017*ridge-.0018*under)
    # A shallower curved chin front reads as a plane rather than a spherical knob.
    chin=gaussian(x,0,.028)*gaussian(z,.017,.018)
    plane=-.086+.006*(x/.030)**2
    delta[:,1]+=np.clip(plane-y,-.0035,.0035)*chin
    delta[:,1]+=.0008*gaussian(x,0,.023)*gaussian(z,.031,.006)
    delta[:,0]+=np.sign(x)*.0009*gaussian(ax,.022,.009)*gaussian(z,.014,.014)
    # Give the upper neck the athletic breadth of the sheet and soften the
    # excessive hollow below the chin, with continuous oblique SCM volumes.
    delta[:,0]+=np.sign(x)*.0024*gaussian(ax,.041,.018)*gaussian(z,-.025,.034)
    delta[:,1]-=.0035*gaussian(x,0,.031)*gaussian(z,-.022,.032)
    delta[:,1]-=.0012*gaussian(ax,.022+np.maximum(-z,0)*.24,.009)*gaussian(z,-.046,.035)
    displacement=delta*(region*guard)[:,None]
    # Fair only the displacement. Existing details and the dense topology survive.
    edges=np.empty(len(head.data.edges)*2,dtype=np.int32)
    head.data.edges.foreach_get('vertices',edges);edges=edges.reshape(-1,2)
    active=region*guard>0
    edges=edges[active[edges].any(axis=1)]
    a,b=edges[:,0],edges[:,1]
    degree=np.maximum(1,np.bincount(a,minlength=len(z))+np.bincount(b,minlength=len(z)))
    for _ in range(160):
        mean=np.column_stack([(np.bincount(a,weights=displacement[b,k],minlength=len(z))
                               +np.bincount(b,weights=displacement[a,k],minlength=len(z)))/degree
                              for k in range(3)])
        displacement+=.45*active[:,None]*(mean-displacement)
    after=before+displacement
    head.data.vertices.foreach_set('co',after.astype(np.float32).ravel());head.data.update()
    pinned=(region==0)|(guard==0)
    assert np.array_equal(before[pinned].astype(np.float32),coordinates(head)[pinned].astype(np.float32))
    assert protected_digest(head)==digest_before
    assert np.isfinite(after).all()
    head['volume_revision']=REVISION
    head['scope']='Primary head volumes, cheekbones, jaw, chin and neck only'
    result=dict(revision=REVISION,vertices=len(after),polygons=len(head.data.polygons),
                topology_unchanged=True,protected_meshes_unchanged=True,
                pinned_vertices=int(pinned.sum()),
                max_displacement_m=float(np.linalg.norm(displacement,axis=1).max()),
                remesh_applied=False)
    print('PRIMARY_PLANES',json.dumps(result),flush=True)
    return result


def refine_primary_volumes(head):
    revision=head.get('volume_revision')
    if revision is None:
        _refine_base_volumes(head)
    elif revision!=BASE_REVISION:
        raise RuntimeError('Volume pass already applied or incompatible; use the baseline source.')
    return refine_primary_planes(head)


if __name__ == '__main__':
    import argparse
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--surface',type=Path,help='Transfer an already refined head mesh into the open baseline scene.')
    options = parser.parse_args(args)
    head = bpy.data.objects['Aren · dense facial sculpt']
    if options.surface:
        digest = protected_digest(head)
        materials = list(head.data.materials)
        with bpy.data.libraries.load(str(options.surface.resolve()),link=False) as (source,target):
            if head.name not in source.objects:
                raise RuntimeError('Refined source is missing the facial surface')
            target.objects = [head.name]
        source_head = target.objects[0]
        if source_head.type!='MESH' or source_head.get('volume_revision')!=REVISION:
            raise RuntimeError('Source does not contain the expected refined facial surface')
        refined = source_head.data
        if len(refined.materials)!=len(materials):
            raise RuntimeError('Refined source changes the facial material slots')
        head.data = refined
        for index,material in enumerate(materials):
            head.data.materials[index] = material
        bpy.data.objects.remove(source_head,do_unlink=True)
        head['volume_revision'] = REVISION
        head['scope'] = 'Primary head volumes, cheekbones, jaw, chin and neck only'
        assert protected_digest(head)==digest
        print('TRANSFER verified: all other mesh coordinates and transforms preserved',flush=True)
    else:
        refine_primary_volumes(head)
    bpy.context.scene['volume_revision'] = REVISION
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(options.output.resolve()),compress=True)
