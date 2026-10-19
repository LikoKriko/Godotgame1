"""Blender -b -t 6 --python tools/trees/build_twisted_oak.py -- output_folder.

Keep the delivered roots/lower trunk and their UVs. Author an organic radial
branch hierarchy above that trunk, with a cylindrical bark transfer from the
delivered surface. Source files are never overwritten. All growth is offline.
"""
import sys
import json
import math
import random
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'assets/models/meshy/twisted_oak'
PROFILE = json.loads((ROOT / 'data/world/trees/twisted_oak.json').read_text())
MANIFEST = json.loads((FOLDER / 'source.json').read_text())
OUT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(PROFILE['seed'])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT / MANIFEST['source_fbx']))
source = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = source
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh = source.data
floor = min(v.co.z for v in mesh.vertices)
height = max(v.co.z for v in mesh.vertices) - floor
for v in mesh.vertices:
    v.co = (v.co - Vector((0, 0, floor))) / height
mesh.update()
mesh.calc_loop_triangles()
source_vertices = np.array([v.co[:] for v in mesh.vertices])
source_triangles = np.array([t.vertices[:] for t in mesh.loop_triangles])
source_uv = np.array([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops]
                      for t in mesh.loop_triangles])
source_normals = np.array([[mesh.corner_normals[i].vector[:] for i in t.loops]
                           for t in mesh.loop_triangles])
bvh = BVHTree.FromPolygons([v.co for v in mesh.vertices], source_triangles.tolist(), all_triangles=True)


def centre_at(z):
    """Median of the unbranched, delivered lower trunk cross section."""
    pts = source_vertices[abs(source_vertices[:, 2] - z) < .014]
    return Vector((float(np.median(pts[:, 0])), float(np.median(pts[:, 1])), z))


def bark_transfer():
    """Bake original colour/PBR detail onto a continuous cylindrical bark tile.

    Tangent-space normals are transformed through the source triangle frame,
    then into the cylinder frame; copying RGB alone would rotate bark relief.
    """
    size = PROFILE['bark_tile_size']
    tri_ids, weights, tangents, normals = [], [], [], []
    for row in range(size):
        z = PROFILE['cut_height_fraction']-.125 + .125 * (row + .5) / size
        centre = centre_at(z)
        for col in range(size):
            angle = -math.pi + math.tau * (col + .5) / size
            radial = Vector((math.cos(angle), math.sin(angle), 0))
            hit, _, index, _ = bvh.ray_cast(centre + radial * .24, -radial, .3)
            if index is None:
                hit, _, index, _ = bvh.find_nearest(centre + radial * .05)
            a, b, c = source_vertices[source_triangles[index]]
            v0, v1, v2 = b-a, c-a, np.array(hit)-a
            d00, d01, d11 = v0@v0, v0@v1, v1@v1
            denom = max(d00*d11-d01*d01, 1e-20)
            v = (d11*(v2@v0)-d01*(v2@v1))/denom
            w = (d00*(v2@v1)-d01*(v2@v0))/denom
            tri_ids.append(index); weights.append([1-v-w, v, w])
            tangents.append([-math.sin(angle), math.cos(angle), 0])
            normals.append(radial[:])
    ids, ws = np.array(tri_ids), np.array(weights)
    uvs = (source_uv[ids] * ws[:, :, None]).sum(axis=1)
    positions = source_vertices[source_triangles[ids]]
    duv1 = source_uv[ids, 1]-source_uv[ids, 0]
    duv2 = source_uv[ids, 2]-source_uv[ids, 0]
    e1, e2 = positions[:, 1]-positions[:, 0], positions[:, 2]-positions[:, 0]
    det = duv1[:, 0]*duv2[:, 1]-duv1[:, 1]*duv2[:, 0]
    det = np.where(abs(det) > 1e-12, det, 1e-12)
    n = (source_normals[ids]*ws[:, :, None]).sum(axis=1)
    n /= np.maximum(np.linalg.norm(n, axis=1)[:, None], 1e-12)
    t = (e1*duv2[:, 1, None]-e2*duv1[:, 1, None])/det[:, None]
    t -= n*(t*n).sum(axis=1)[:, None]
    t /= np.maximum(np.linalg.norm(t, axis=1)[:, None], 1e-12)
    b = np.cross(n, t)*np.sign(det)[:, None]
    frame_t, frame_n = np.array(tangents), np.array(normals)
    frame_b = np.cross(frame_n, frame_t)
    for key in ['albedo', 'normal', 'roughness', 'metallic']:
        im = bpy.data.images.load(str(FOLDER / (key+'.png')), check_existing=False)
        # Texture pixels remain in their supplied (sRGB colour / linear data) encoding.
        im.colorspace_settings.name = 'Non-Color'
        pixels = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
        x, y = np.clip(uvs[:, 0]*im.size[0]-.5, 0, im.size[0]-1), np.clip(uvs[:, 1]*im.size[1]-.5, 0, im.size[1]-1)
        x0, y0 = x.astype(int), y.astype(int)
        x1, y1 = np.minimum(x0+1, im.size[0]-1), np.minimum(y0+1, im.size[1]-1)
        fx, fy = (x-x0)[:, None], (y-y0)[:, None]
        colors = (pixels[y0, x0]*(1-fx)+pixels[y0, x1]*fx)*(1-fy)+(pixels[y1, x0]*(1-fx)+pixels[y1, x1]*fx)*fy
        if key == 'normal':
            local = colors[:, :3]*2-1
            shading = t*local[:, 0, None]+b*local[:, 1, None]+n*local[:, 2, None]
            # Preserve detail only: cylinder geometry supplies its own smooth curvature.
            detail = shading-n
            out = np.stack([(detail*frame_t).sum(axis=1), (detail*frame_b).sum(axis=1), np.ones(len(ids))], axis=1)
            out /= np.maximum(np.linalg.norm(out, axis=1)[:, None], 1e-12)
            colors[:, :3] = out*.5+.5
        colors[:, 3] = 1
        result = bpy.data.images.new('bark_'+key, width=size, height=size, alpha=True)
        result.colorspace_settings.name = 'Non-Color'
        result.pixels.foreach_set(colors.astype(np.float32).ravel())
        result.filepath_raw = str(FOLDER / ('bark_'+key+'.png'))
        result.file_format = 'PNG'; result.save()
        bpy.data.images.remove(im); bpy.data.images.remove(result)


if '--skip-bark' not in sys.argv: bark_transfer()
print('BARK_TRANSFER_COMPLETE', flush=True)

# Retain the actual delivered roots and lower trunk; the cut is below the first
# planar branch. Its boundary ring becomes the first ring of the new leader.
bm = bmesh.new(); bm.from_mesh(mesh)
cut = PROFILE['cut_height_fraction']
bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                       plane_co=(0, 0, cut), plane_no=(0, 0, 1), clear_outer=True, dist=1e-7)
bm.to_mesh(mesh); bm.free(); mesh.update()
boundary = [v for v in mesh.vertices if abs(v.co.z-cut) < 1e-5]
assert len(boundary) > 12, 'Expected the single lower-trunk cross section'
centre = sum((v.co for v in boundary), Vector()) / len(boundary)
boundary.sort(key=lambda v: math.atan2(v.co.y-centre.y, v.co.x-centre.x))
boundary_coords = [v.co.copy() for v in boundary]
base_radius = sum((v.co-centre).length for v in boundary)/len(boundary)

# A quiet continuation of the original lean, not a straight cylindrical pole.
leader = []
span = .96-cut
initial_slope = (centre-centre_at(cut-.035))/.035
initial_slope.z = 1
end = centre+Vector((-.095, .006, span))
for i in range(21):
    t = i/20
    p = centre*(2*t**3-3*t*t+1) + initial_slope*span*(t**3-2*t*t+t) + end*(-2*t**3+3*t*t) + Vector((-.012, .0, span))*(t**3-t*t)
    leader.append(p)
leader_radii = [base_radius*((1-t)**1.5*.992+.008) for t in np.linspace(0, 1, len(leader))]

vertices, faces, face_uvs = [], [], []
branches = []
segments = []


def interpolate(points, t):
    f = min(max(t, 0), .999999)*(len(points)-1)
    i = int(f); w = f-i
    return points[i].lerp(points[i+1], w)


def direction(points, t):
    return (interpolate(points, min(t+.02, 1))-interpolate(points, max(0, t-.02))).normalized()


def radius_at(radii, t):
    f = min(max(t, 0), .999999)*(len(radii)-1); i = int(f)
    return radii[i]*(1-f+i)+radii[i+1]*(f-i)


def curve(start, initial, length, bend_degrees, bend_axis, count):
    points = [start.copy()]
    # Integrate a smoothly changing tangent. Total change is bounded and
    # monotonic; dense integration avoids kinks at the exported rings.
    step = length/(count-1)/8
    for i in range((count-1)*8):
        t = (i+.5)/((count-1)*8)
        tangent = Quaternion(bend_axis, math.radians(bend_degrees)*t*t*(3-2*t)) @ initial
        p = points[-1] + tangent*step
        points.append(p)
    return [points[i*8] for i in range(count)]


def segment_distances(a, b, starts, ends):
    """Exact finite segment distances, including parallel/end-point cases."""
    u, v, w = b-a, ends-starts, a-starts
    aa = u@u; bb = v@u; cc = np.einsum('ij,ij->i', v, v)
    dd = w@u; ee = np.einsum('ij,ij->i', v, w)
    denom = aa*cc-bb*bb
    s = np.divide(bb*ee-cc*dd, denom, out=np.zeros_like(denom), where=abs(denom)>1e-16)
    t = np.divide(aa*ee-bb*dd, denom, out=np.zeros_like(denom), where=abs(denom)>1e-16)
    inside = (s>=0)&(s<=1)&(t>=0)&(t<=1)&(abs(denom)>1e-16)
    distance = np.where(inside, np.linalg.norm(w+s[:, None]*u-t[:, None]*v, axis=1), np.inf)
    for p in [a, b]:
        k = np.clip(np.einsum('ij,ij->i', p-starts, v)/np.maximum(cc, 1e-16), 0, 1)
        distance = np.minimum(distance, np.linalg.norm(p-starts-k[:, None]*v, axis=1))
    for p in [starts, ends]:
        k = np.clip((p-a)@u/max(aa, 1e-16), 0, 1)
        distance = np.minimum(distance, np.linalg.norm(p-a-k[:, None]*u, axis=1))
    return distance


def clearance(points, radii, parent, emergence):
    others = [s for s in segments if s[3] != parent]
    if not others:
        return 1.0
    starts = np.array([s[0] for s in others]); ends = np.array([s[1] for s in others])
    sizes = np.array([s[2] for s in others]); minimum = 1.0
    travelled = 0.0
    for i in range(len(points)-1):
        travelled += (points[i+1]-points[i]).length
        if travelled < emergence:
            continue  # The collar embedded in its parent is an intentional union.
        d = segment_distances(np.array(points[i]), np.array(points[i+1]), starts, ends)
        minimum = min(minimum, float(np.min(d-sizes-max(radii[i:i+2]))))
    return minimum


def store_branch(points, radii, level, parent, bend, **extra):
    index = len(branches)
    branches.append(dict(id=index, parent=parent, level=level, curve_degrees=bend,
                         points=[list(p) for p in points], radii=radii, **extra))
    # Exclude the buried collar from unrelated collision checks.
    emergence = extra.get('emergence', 0)
    distance = 0.0
    for i in range(len(points)-1):
        distance += (points[i+1]-points[i]).length
        if distance >= emergence:
            segments.append((list(points[i]), list(points[i+1]), max(radii[i:i+2]), index))
    return index


def sweep(points, radii, sides, phase, initial_ring=None):
    rings, lengths = [], [0.0]
    initial_tangent = (points[1]-points[0]).normalized()
    cross = initial_tangent.cross(Vector((0, 0, 1)))
    if cross.length < .1: cross = Vector((1, 0, 0))
    cross.normalize()
    previous = initial_tangent
    for i, p in enumerate(points):
        tangent = (points[min(i+1, len(points)-1)]-points[max(0, i-1)]).normalized()
        cross = previous.rotation_difference(tangent) @ cross
        cross = (cross-tangent*cross.dot(tangent)).normalized()
        other = tangent.cross(cross).normalized(); previous = tangent
        ring = []
        if i: lengths.append(lengths[-1]+(p-points[i-1]).length)
        for j in range(sides):
            angle = j*math.tau/sides
            flute = 1+.065*math.cos(5*angle+phase+i*.12)+.025*math.sin(3*angle-phase)
            pos = p+(cross*math.cos(angle)+other*math.sin(angle))*radii[i]*flute
            if initial_ring is not None:
                # Transport the actual source cross-section without rounding it
                # into a circle or twisting the boundary's uneven vertex spacing.
                original = initial_ring[j]-points[0]
                original.z = 0
                original *= radii[i]/radii[0]
                frame = Vector((0, 0, 1)).rotation_difference(tangent)
                pos = p + (frame @ original if i else original)
            vertices.append(tuple(pos)); ring.append(len(vertices)-1)
        rings.append(ring)
    repeat = max(.035, radii[0]*math.tau/2.5)
    def tex(j, row):
        if initial_ring is not None:
            j0 = j % sides
            offset = initial_ring[j0]-points[0]
            u = (math.atan2(offset.y, offset.x)+math.pi)/math.tau
            if j == sides: u += 1
            return (u, 1-.5/PROFILE['bark_tile_size']-lengths[row]/repeat)
        return (j/sides, lengths[row]/repeat)
    for i in range(len(points)-1):
        for j in range(sides):
            k = (j+1)%sides
            faces.append((rings[i][j], rings[i][k], rings[i+1][k], rings[i+1][j]))
            face_uvs.append([tex(j, i), tex(j+1, i), tex(j+1, i+1), tex(j, i+1)])
    # Only the fine terminal end is capped; the base lives inside its parent.
    faces.append(tuple(reversed(rings[-1])))
    face_uvs.append([(.5+.45*math.cos(j*math.tau/sides), .5+.45*math.sin(j*math.tau/sides)) for j in reversed(range(sides))])


leader_id = store_branch(leader, leader_radii, 0, -1, 0)
sweep(leader, leader_radii, len(boundary), RNG.random()*6, boundary_coords)

# Unequal circular gaps, all within the requested range, spanning the full turn.
count = PROFILE['primary_count']
gaps = [24+RNG.uniform(-2, 2) for _ in range(count)]
gaps = [g*360/sum(gaps) for g in gaps]
assert min(gaps) >= 20 and max(gaps) <= 30
heights = [(.08+i*.057+RNG.uniform(-.008, .008)) for i in range(count)]
RNG.shuffle(heights)
angle = RNG.uniform(0, 12)
primaries = []
for i in range(count):
    angle += gaps[i]
    attachment = heights[i]
    anchor = interpolate(leader, attachment)
    for attempt in range(160):
        azimuth = math.radians(angle)
        elevation = math.radians(RNG.uniform(18, 39)+attachment*22)
        initial = Vector((math.cos(azimuth)*math.cos(elevation), math.sin(azimuth)*math.cos(elevation), math.sin(elevation)))
        length = RNG.uniform(*PROFILE['primary_length'])*(1-attachment*.45)
        axis = initial.cross(Vector((RNG.uniform(-.25, .25), RNG.uniform(-.25, .25), 1))).normalized()
        maximum = PROFILE['maximum_curve_degrees'][0]
        bend = RNG.uniform(maximum*2/5, maximum*9/10)
        points = curve(anchor, initial, length, bend, axis, 11)
        base = radius_at(leader_radii, attachment)*RNG.uniform(.40, .55)
        radii = [base*((1-t)**.85*.85+.15) for t in np.linspace(0, 1, len(points))]
        emergence = radius_at(leader_radii, attachment)*2.25
        space = clearance(points, radii, leader_id, emergence)
        if space > .0004: break
    else: raise RuntimeError(f'Unable to place primary {i}; clearance={space}; height={attachment}')
    idx = store_branch(points, radii, 1, leader_id, bend, azimuth_degrees=angle%360, emergence=emergence, clearance=space)
    primaries.append(idx); sweep(points, radii, 11, RNG.random()*6)


def grow_children(parent_id, level, count):
    parent = branches[parent_id]
    pp = [Vector(p) for p in parent['points']]; pr = parent['radii']
    total_length = sum((b-a).length for a, b in zip(pp, pp[1:]))
    ids = []
    first = .26 if level == 2 else max(.42, min(.72, parent['attachment_radius']*2/total_length))
    fractions = [first+i*(.9-first)/max(1, count-1)+RNG.uniform(-.018, .018) for i in range(count)]
    initial_phase = RNG.uniform(0, math.tau)
    for i, t in enumerate(fractions):
        start = interpolate(pp, t); parent_tangent = direction(pp, t)
        across = parent_tangent.cross(Vector((0, 0, 1))).normalized()
        up = across.cross(parent_tangent).normalized()
        for attempt in range(240):
            phase = initial_phase+i*2.399963+RNG.uniform(-.55, .55)+attempt*.11
            lateral = across*math.cos(phase)+up*math.sin(phase)
            fork = math.radians(RNG.uniform(25, 49) if level == 2 else RNG.uniform(20, 40))
            initial = (parent_tangent*math.cos(fork)+lateral*math.sin(fork)).normalized()
            length = total_length*RNG.uniform(*(PROFILE['secondary_length_fraction'] if level == 2 else PROFILE['twig_length_fraction']))
            # The last daughter is shorter, but not a linear size progression.
            length *= RNG.uniform(.8, 1.1)
            axis = initial.cross(up+Vector((0, 0, .6))).normalized()
            maximum = PROFILE['maximum_curve_degrees'][level-1]
            bend = RNG.uniform(maximum*4/15, maximum*14/15) if level == 2 else RNG.uniform(maximum/5, maximum*47/50)
            points = curve(start, initial, length, bend, axis, 7 if level == 2 else 5)
            base = max(.0014 if level == 2 else .00065, radius_at(pr, t)*RNG.uniform(.35, .48))
            radii = [max(.0005 if level == 2 else .00018, base*((1-f)**.8*.87+.13)) for f in np.linspace(0, 1, len(points))]
            emergence = radius_at(pr, t)*1.5
            space = clearance(points, radii, parent_id, emergence)
            if space > .00015: break
        else: raise RuntimeError(f'Unable to place level {level} branch {i} on {parent_id}; clearance={space}; fraction={t}')
        idx = store_branch(points, radii, level, parent_id, bend, emergence=emergence, clearance=space, attachment_radius=radius_at(pr, t))
        ids.append(idx); sweep(points, radii, 7 if level == 2 else 5, RNG.random()*6)
    return ids


secondaries = []
for primary in primaries:
    secondaries += grow_children(primary, 2, RNG.randint(*PROFILE['secondary_count']))
for secondary in secondaries:
    grow_children(secondary, 3, RNG.randint(*PROFILE['twig_count']))

branch_mesh = bpy.data.meshes.new('AuthoredRadialBranches')
branch_mesh.from_pydata(vertices, [], faces); branch_mesh.update()
uvs = branch_mesh.uv_layers.new(name='BarkCylinder')
for face, coords in zip(branch_mesh.polygons, face_uvs):
    for loop, uv in zip(face.loop_indices, coords): uvs.data[loop].uv = uv
    face.use_smooth = True
branch_object = bpy.data.objects.new('AuthoredRadialBranches', branch_mesh)
bpy.context.collection.objects.link(branch_object)

# Correct outward orientation once in authoring, then let glTF preserve normals.
bm = bmesh.new(); bm.from_mesh(branch_mesh)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(branch_mesh); bm.free()

# Blend the first leader rings into the delivered trunk's exact UV/shading.
# This avoids a circular colour/normal seam between two different bark unwraps.
source_projection = branch_mesh.uv_layers.new(name='DeliveredProjection')
# Blender initializes a new UV layer by copying the active one.
# Unused projection coordinates must remain zero, not duplicate the bark map.
for item in source_projection.data: item.uv = (0, 0)
branch_mesh.uv_layers.active_index = 0
branch_mesh.uv_layers[0].active_render = True
blend_colors = branch_mesh.color_attributes.new(name='JunctionBlend', type='FLOAT_COLOR', domain='CORNER')
branch_mesh.color_attributes.active_color_index = 0
branch_mesh.color_attributes.render_color_index = 0
# Adding colour/custom-data layers can invalidate RNA layer references. Resolve
# both UV layers by name after allocating them, then restore their own data.
uvs = branch_mesh.uv_layers['BarkCylinder']
for face, coords in zip(branch_mesh.polygons, face_uvs):
    for loop_id, uv in zip(face.loop_indices, coords): uvs.data[loop_id].uv = uv
source_projection = branch_mesh.uv_layers['DeliveredProjection']
for item in source_projection.data: item.uv = (0, 0)
custom_normals = [n.vector.copy() for n in branch_mesh.corner_normals]
leader_vertices = len(leader)*len(boundary)
boundary_uvs = {}
for face in mesh.polygons:
    loops = list(face.loop_indices)
    positions = np.array([mesh.vertices[mesh.loops[j].vertex_index].co[:] for j in loops[:3]])
    tex = np.array([mesh.uv_layers.active.data[j].uv[:] for j in loops[:3]])
    gradient = (tex[1:]-tex[0]).T @ np.linalg.pinv((positions[1:]-positions[0]).T) @ np.array([0, 0, 1])
    for i, loop_id in enumerate(loops):
        next_id = loops[(i+1) % len(loops)]
        a_id, b_id = mesh.loops[loop_id].vertex_index, mesh.loops[next_id].vertex_index
        if abs(mesh.vertices[a_id].co.z-cut)<1e-5 and abs(mesh.vertices[b_id].co.z-cut)<1e-5:
            boundary_uvs[a_id, b_id] = (mesh.uv_layers.active.data[loop_id].uv.copy(), mesh.uv_layers.active.data[next_id].uv.copy(), Vector(gradient))
            boundary_uvs[b_id, a_id] = (boundary_uvs[a_id, b_id][1], boundary_uvs[a_id, b_id][0], Vector(gradient))
for face in branch_mesh.polygons:
    leader_face = face.index < (len(leader)-1)*len(boundary)
    edge = face.index % len(boundary)
    uv_pair = boundary_uvs.get((boundary[edge].index, boundary[(edge+1)%len(boundary)].index)) if leader_face else None
    if leader_face: assert uv_pair is not None, 'Every leader edge must meet the actual original boundary edge'
    for corner, loop_id in enumerate(face.loop_indices):
        vertex = branch_mesh.vertices[branch_mesh.loops[loop_id].vertex_index]
        index = vertex.index
        ring = index//len(boundary)
        fade = max(0, 1-ring/3) if index < leader_vertices else 0
        fade = fade*fade*(3-2*fade)
        blend_colors.data[loop_id].color = (1, 1, 1, fade)
        # Carry the exact edge UVs into the collar. Do not interpolate across
        # unrelated source atlas islands or extrapolate through branch charts.
        if leader_face:
            source_projection.data[loop_id].uv = uv_pair[0 if corner in [0, 3] else 1] + uv_pair[2]*min(ring, 3)*.0005
        if fade <= 0: continue
        hit, _, normal_id, _ = bvh.find_nearest(vertex.co)
        na, nb, nc = source_vertices[source_triangles[normal_id]]
        v, w = np.linalg.pinv(np.stack([nb-na, nc-na], axis=1)) @ (np.array(hit)-na)
        weights = np.array([1-v-w, v, w])
        n = Vector((source_normals[normal_id]*weights[:, None]).sum(axis=0)).normalized()
        custom_normals[loop_id] = custom_normals[loop_id].lerp(n, fade).normalized()

branch_mesh.normals_split_custom_set(custom_normals)

# One coordinate system and one uniform scale for source and edited geometry.
peak = max(max(v.co.z for v in mesh.vertices), max(v.co.z for v in branch_mesh.vertices))
for m in [mesh, branch_mesh]:
    for v in m.vertices: v.co /= peak
    m.update()
for branch in branches:
    branch['points'] = [[x/peak for x in p] for p in branch['points']]
    branch['radii'] = [r/peak for r in branch['radii']]
    if 'emergence' in branch: branch['emergence'] /= peak
    if 'clearance' in branch: branch['clearance'] /= peak
source.name = 'DeliveredRootsTrunk'


def preview_material(prefix, strength):
    material = bpy.data.materials.new('Delivered bark' if not prefix else 'Transferred branch bark')
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes.get('Principled BSDF')
    if prefix:
        bark_uv = nodes.new('ShaderNodeUVMap'); bark_uv.uv_map = 'BarkCylinder'
        source_uv_node = nodes.new('ShaderNodeUVMap'); source_uv_node.uv_map = 'DeliveredProjection'
        mask = nodes.new('ShaderNodeVertexColor'); mask.layer_name = 'JunctionBlend'
    for key, socket in [('albedo', 'Base Color'), ('roughness', 'Roughness'), ('metallic', 'Metallic'), ('normal', 'Normal')]:
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = bpy.data.images.load(str(FOLDER/(prefix+key+'.png')), check_existing=False)
        texture.image.colorspace_settings.name = 'sRGB' if key == 'albedo' else 'Non-Color'
        if prefix: links.new(bark_uv.outputs['UV'], texture.inputs['Vector'])
        if key == 'normal':
            normal = nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value = strength
            if prefix: normal.uv_map = 'BarkCylinder'
            links.new(texture.outputs['Color'], normal.inputs['Color'])
            links.new(normal.outputs['Normal'], shader.inputs[socket])
        else:
            links.new(texture.outputs['Color'], shader.inputs[socket])
        if prefix:
            delivered = nodes.new('ShaderNodeTexImage')
            delivered.image = bpy.data.images.load(str(FOLDER/(key+'.png')), check_existing=False)
            delivered.image.colorspace_settings.name = 'sRGB' if key == 'albedo' else 'Non-Color'
            links.new(source_uv_node.outputs['UV'], delivered.inputs['Vector'])
            mix = nodes.new('ShaderNodeMixRGB'); links.new(mask.outputs['Alpha'], mix.inputs[0])
            if key == 'normal':
                delivered_normal = nodes.new('ShaderNodeNormalMap'); delivered_normal.uv_map = 'DeliveredProjection'
                delivered_normal.inputs['Strength'].default_value = PROFILE['source_normal_strength']
                links.new(delivered.outputs['Color'], delivered_normal.inputs['Color'])
                links.new(normal.outputs['Normal'], mix.inputs[1]); links.new(delivered_normal.outputs['Normal'], mix.inputs[2])
                normalize = nodes.new('ShaderNodeVectorMath'); normalize.operation = 'NORMALIZE'
                links.new(mix.outputs[0], normalize.inputs[0]); links.new(normalize.outputs[0], shader.inputs[socket])
            else:
                links.new(texture.outputs['Color'], mix.inputs[1]); links.new(delivered.outputs['Color'], mix.inputs[2])
                links.new(mix.outputs[0], shader.inputs[socket])
    return material


mesh.materials.clear(); mesh.materials.append(preview_material('', PROFILE['source_normal_strength']))
branch_mesh.materials.clear(); branch_mesh.materials.append(preview_material('bark_', PROFILE['branch_normal_strength']))
print('UV_ROLES', [(layer.name, layer.data[0].uv[:]) for layer in branch_mesh.uv_layers], flush=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'edited.glb'), export_format='GLB', export_materials='NONE', export_animations=False, export_yup=True)

# Runtime uses only the light collision spine; full branch controls stay offline.
lower = []
for z in np.linspace(.025, cut-.015, 9):
    c = centre_at(float(z)); pts = source_vertices[abs(source_vertices[:, 2]-z)<.014]
    radius = float(np.percentile(np.linalg.norm(pts[:, :2]-np.array(c)[:2], axis=1), 35))
    lower.append({'point': [c.x/peak, c.z/peak, -c.y/peak], 'radius': radius*.8/peak})
for p, r in zip(leader[::2], leader_radii[::2]):
    lower.append({'point': [p.x/peak, p.z/peak, -p.y/peak], 'radius': r*.85/peak})
controls = {'version': 1, 'profile': MANIFEST['profile'], 'primary_gaps_degrees': gaps,
            'branches': branches, 'collision_spine': lower,
            'delivered_trunk_cut_fraction': cut, 'height_normalization': peak}
(FOLDER/'branches.json').write_text(json.dumps(controls, indent=2)+'\n')
# Keep Blender backups out of the repository.
bpy.context.preferences.filepaths.save_version = 0
for material in list(bpy.data.materials):
    if material.users == 0: bpy.data.materials.remove(material)
for image in list(bpy.data.images):
    if image.users == 0: bpy.data.images.remove(image)
# Editable authoring scene is a deliverable, not a scratch test report.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'entregables/modelos/twisted_oak/edited.blend'))
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'entregables/modelos/twisted_oak/edited.blend'))
print('EDITED_OAK', json.dumps({'primary': len(primaries), 'secondary': len(secondaries),
                              'twigs': sum(b['level'] == 3 for b in branches),
                              'vertices': len(mesh.vertices)+len(branch_mesh.vertices),
                              'triangles': sum(len(p.vertices)-2 for m in [mesh, branch_mesh] for p in m.polygons)}), flush=True)
