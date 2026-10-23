"""Blender 4.3+: build the isolated, unrigged Aren visual study.
Run from the repository: blender -b -t 6 --python tools/characters/build_aren_v2.py
Existing anatomy is a source donor; the original FBX and 66-bone rig are immutable.
No clips, skin or playable scenes are exported by this visual-only workflow.
"""
import bpy, bmesh, math, random, json, hashlib, sys
from pathlib import Path
from mathutils import Vector, Matrix
R=Path(__file__).resolve().parents[2]
OUT=R/'assets/characters/aren_v2'; OUT.mkdir(parents=True,exist_ok=True)
PRE=R/'work/aren-v2'; PRE.mkdir(parents=True,exist_ok=True)
random.seed(3160)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
model=bpy.data.collections.new('AREN V2 · visual study');bpy.context.scene.collection.children.link(model)
reference=bpy.data.collections.new('REFERENCE · original 66 bones · untouched');bpy.context.scene.collection.children.link(reference)
def move(o,col=model):
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o);return o
def mat(name,color,rough=.8,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
skin=mat('Skin · warm ochre',(.43,.235,.115));lip=mat('Lips · muted rose',(.36,.19,.125));shadow=mat('Creases',(.19,.105,.066));ink=mat('Tattoo · charcoal blue',(.035,.055,.061));hair=mat('Hair · dark umber',(.032,.024,.019));hairlit=mat('Hair · warm edges',(.058,.039,.025));cloth=mat('Shorts · graphite',(.045,.055,.068));panel=mat('Shorts · alternate panels',(.060,.073,.089));seam=mat('Shorts · seams',(.10,.115,.13));metal=mat('Buckle · titanium',(.24,.29,.32),.42,.65);white=mat('Eyes · warm sclera',(.42,.45,.41));iris=mat('Eyes · slate blue',(.075,.15,.19),.4);pupil=mat('Pupils',(.006,.009,.011),.35)
# Restrained surface variation follows object space; no photographic projection.
for m,scale,strength in [(skin,8,.12),(cloth,100,.10),(panel,100,.1)]:
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=scale;tex.inputs['Detail'].default_value=1.5
 ramp=n.new('ShaderNodeValToRGB');base=m.diffuse_color[:3]
 ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=tuple(c*(1-strength) for c in base)+(1,)
 ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=tuple(c*(1+strength) for c in base)+(1,)
 l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs['Color'],p.inputs['Base Color'])
def mesh(name,verts,faces,material):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);model.objects.link(o);me.materials.append(material);return o
def uv(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
def sphere(name,location,scale,material,segments=20,rings=12):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=location);o=move(bpy.context.object);o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o
def line(name,points,radius,material,closed=False):
 # Editable mesh tube; welded loops and capped open ends avoid duplicate faces.
 clean=[]
 for p in points:
  if not clean or (Vector(p)-Vector(clean[-1])).length>1e-8:clean.append(p)
 points=clean
 is_closed=closed or (Vector(points[0])-Vector(points[-1])).length<1e-8
 if is_closed:points=points[:-1]
 verts=[];faces=[];N=6;count=len(points)
 for i,p in enumerate(points):
  p=Vector(p);a=Vector(points[(i-1)%count] if is_closed else points[max(0,i-1)]);b=Vector(points[(i+1)%count] if is_closed else points[min(count-1,i+1)])
  t=(b-a).normalized();u=t.cross(Vector((0,1,0))).normalized()
  if u.length<.01:u=t.cross(Vector((1,0,0))).normalized()
  v=t.cross(u).normalized()
  for j in range(N):verts.append(tuple(p+radius*(u*math.cos(j*2*math.pi/N)+v*math.sin(j*2*math.pi/N))))
 for i in range(count if is_closed else count-1):
  k=(i+1)%count
  for j in range(N):faces.append((i*N+j,i*N+(j+1)%N,k*N+(j+1)%N,k*N+j))
 if not is_closed:faces.extend([tuple(reversed(range(N))),tuple((count-1)*N+j for j in range(N))])
 return mesh(name,verts,faces,material)
# Inspect the donor before changing any copy.
source=R/'entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx'
bpy.ops.import_scene.fbx(filepath=str(source));body=next(o for o in bpy.data.objects if o.type=='MESH');rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
assert len(rig.data.bones)==66
bone_record=[{'name':b.name,'parent':b.parent.name if b.parent else None,'matrix':sum([list(row) for row in b.matrix_local],[])} for b in rig.data.bones]
weight_sums=[sum(g.weight for g in v.groups) for v in body.data.vertices]
(PRE/'source-inspection.json').write_text(json.dumps({'bones':bone_record,'vertices':len(body.data.vertices),'polygons':len(body.data.polygons),'weight_sum_range':[min(weight_sums),max(weight_sums)],'materials':[m.name for m in body.data.materials]},indent=2))
# Only a temporary pose copy is used to lower the arms for visual review.
rig.animation_data_clear();body.animation_data_clear()
for side,angle in [('Left',70),('Right',-70)]:
 b=rig.pose.bones['smartrig:'+side+'Arm'];pivot=b.bone.head_local
 b.matrix=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(angle),4,'Y')@Matrix.Translation(-pivot)@b.bone.matrix_local
bpy.context.view_layer.update()
eval_body=body.evaluated_get(bpy.context.evaluated_depsgraph_get());me=bpy.data.meshes.new_from_object(eval_body,preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
new=bpy.data.objects.new('Aren · skin anatomy',me);model.objects.link(new);new.matrix_world=body.matrix_world
bpy.ops.object.select_all(action='DESELECT');new.select_set(True);bpy.context.view_layer.objects.active=new;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Remove the donor's face, ragged garment and hidden upper thighs.
bm=bmesh.new();bm.from_mesh(me)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,1.37),plane_no=(0,0,1),clear_outer=True,dist=1e-6)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,.50),plane_no=(0,0,1),dist=1e-6)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,1.001),plane_no=(0,0,1),dist=1e-6)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if .50001<v.co.z<1.001 and abs(v.co.x)<.26],context='VERTS')
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(me);bm.free();new.vertex_groups.clear();me.materials.clear();me.materials.append(skin)
for p in me.polygons:p.material_index=0;p.use_smooth=True
# Loft new upper thighs from the exact donor knee boundary, then weld them.
for side in [-1,1]:
 bm=bmesh.new();bm.from_mesh(new.data)
 ring=list({v for e in bm.edges if e.is_boundary for v in e.verts if abs(v.co.z-.50)<.0001 and v.co.x*side>0})
 assert len(ring)>8, ('Missing knee boundary',side,len(ring))
 cx=sum(v.co.x for v in ring)/len(ring);cy=sum(v.co.y for v in ring)/len(ring)
 ring.sort(key=lambda v:math.atan2(v.co.y-cy,v.co.x-cx))
 angles=[math.atan2(v.co.y-cy,v.co.x-cx) for v in ring];vv=[tuple(v.co) for v in ring];nn=len(ring);ff=[];bm.free()
 for z,rx,ry in [(.53,.050,.054),(.58,.058,.061),(.63,.067,.072),(.69,.075,.080),(.77,.081,.083),(.85,.080,.082)]:
  for angle in angles:vv.append((side*(.104-(z-.55)*.04)+rx*math.cos(angle),.016+ry*math.sin(angle),z))
 for i in range(6):
  for j in range(nn):ff.append((i*nn+j,i*nn+(j+1)%nn,(i+1)*nn+(j+1)%nn,(i+1)*nn+j))
 thigh=mesh('Upper thigh anatomy',vv,ff,skin)
 bpy.ops.object.select_all(action='DESELECT');thigh.select_set(True);new.select_set(True);bpy.context.view_layer.objects.active=new;bpy.ops.object.join()
 bm=bmesh.new();bm.from_mesh(new.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(new.data);bm.free()
for p in new.data.polygons:p.use_smooth=True
# Restrained anatomical relief, preserving the source limb lengths.
for v in new.data.vertices:
 x,y,z=v.co
 if y<.01 and 1.02<z<1.34 and abs(x)<.19:
  relief=.009*math.exp(-((abs(x)-.075)/.060)**2-((z-1.265)/.045)**2)
  for row in [1.075,1.12,1.165,1.205]:relief+=.0045*math.exp(-((abs(x)-.030)/.025)**2-((z-row)/.017)**2)
  v.co.y-=relief
# Source reference is reset and excluded from the presentation and export.
bpy.data.objects.remove(body,do_unlink=True)
for b in rig.pose.bones:b.matrix_basis.identity()
rig.name='REFERENCE_Original_66_Bones';move(rig,reference);reference.hide_render=True;reference.hide_viewport=True
# Sculpted head: quad rings, integrated cheek planes, sockets, nose and lips.
profiles=[(1.405,.039,-.003,.073),(1.427,.040,-.016,.080),(1.441,.039,-.053,.084),(1.455,.066,-.059,.092),(1.475,.065,-.060,.101),(1.495,.071,-.064,.109),(1.515,.078,-.063,.112),(1.535,.080,-.060,.115),(1.552,.079,-.053,.115),(1.57,.077,-.056,.113),(1.59,.076,-.054,.108),(1.615,.071,-.045,.098),(1.637,.059,-.027,.081),(1.653,.040,-.005,.057),(1.661,.012,.024,.035)]
N=64;verts=[];faces=[]
def gaussian(x,c,w):return math.exp(-((x-c)/w)**2)
for z,w,front,back in profiles:
 for j in range(N):
  t=2*math.pi*j/N;x=w*math.sin(t);c=math.cos(t);power=.55 if c>=0 and 1.45<z<1.60 else 1.0;y=(front if c>=0 else back)*abs(c)**power+.023*(1-abs(c)**power)
  if c>0:
   # Dorsum and tip are continuous with the face.
   y-=.040*gaussian(x,0,.013)*gaussian(z,1.528,.026)*c**3
   y-=.016*gaussian(x,0,.020)*gaussian(z,1.515,.011)*c**3
   y+=.012*gaussian(abs(x),.034,.018)*gaussian(z,1.552,.012)*c
   y-=.007*gaussian(abs(x),.034,.025)*gaussian(z,1.572,.010)*c
   y-=.007*gaussian(abs(x),.047,.024)*gaussian(z,1.531,.014)*c
   y-=.005*gaussian(x,0,.031)*gaussian(z,1.489,.008)*c
  verts.append((x,y,z))
for i in range(len(profiles)-1):
 for j in range(N):faces.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
faces.append(tuple((len(profiles)-1)*N+j for j in range(N)))
head=mesh('Aren · sculpted youthful head',verts,faces,skin)
for p in head.data.polygons:p.use_smooth=True
sub=head.modifiers.new('Facial support loops','SUBSURF');sub.levels=1
bpy.context.view_layer.objects.active=head;bpy.ops.object.modifier_apply(modifier=sub.name)
# A conforming zipper closes the neck between donor and authored head.
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);new.select_set(True);bpy.context.view_layer.objects.active=new;bpy.ops.object.join()
bm=bmesh.new();bm.from_mesh(new.data)
boundary=[e for e in bm.edges if e.is_boundary and (all(abs(v.co.z-1.405)<.0001 for v in e.verts) or all(abs(v.co.z-1.37)<.0001 for v in e.verts))]
# Connected boundary loops, then angular zipper of unequal loop sizes.
remaining=set(v for e in boundary for v in e.verts);loops=[]
while remaining:
 start=next(iter(remaining));stack=[start];group=set()
 while stack:
  v=stack.pop()
  if v in group:continue
  group.add(v)
  for e in v.link_edges:
   if e in boundary:stack.extend(e.verts)
 remaining-=group;loops.append(list(group))
if len(loops)==2:
 for ring in loops:
  ring.sort(key=lambda v:math.atan2(v.co.y-.035,v.co.x))
 a,b=loops;i=j=0
 aa=[math.atan2(v.co.y-.035,v.co.x) for v in a];bb=[math.atan2(v.co.y-.035,v.co.x) for v in b];aa.append(aa[0]+2*math.pi);bb.append(bb[0]+2*math.pi)
 while i<len(a) or j<len(b):
  if i<len(a) and (j==len(b) or aa[i+1]<=bb[j+1]):
   vs=[a[i%len(a)],a[(i+1)%len(a)],b[j%len(b)]];i+=1
  else:vs=[a[i%len(a)],b[(j+1)%len(b)],b[j%len(b)]];j+=1
  bm.faces.new(vs)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(new.data);bm.free()
# Consolidate the copied anatomy and the authored neck into one clean surface.
# This is visual topology; deformation loops/weights still require their own review.
bpy.ops.object.select_all(action='DESELECT');new.select_set(True);bpy.context.view_layer.objects.active=new
bm=bmesh.new();bm.from_mesh(new.data);bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(new.data);bm.free()
remesh=new.modifiers.new('Unified anatomy surface','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.003;remesh.use_smooth_shade=True;remesh.use_remove_disconnected=False
bpy.ops.object.modifier_apply(modifier=remesh.name)
bm=bmesh.new();bm.from_mesh(new.data)
for i in range(20):bmesh.ops.smooth_vert(bm,verts=[v for v in bm.verts if .475<v.co.z<.57],factor=.45,use_axis_x=True,use_axis_y=True,use_axis_z=True)
bm.to_mesh(new.data);bm.free()
smooth=new.modifiers.new('Anatomical surface relaxation','SMOOTH');smooth.factor=.45;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
decimate=new.modifiers.new('Adaptive surface density','DECIMATE');decimate.ratio=.075;decimate.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=decimate.name)
for p in new.data.polygons:p.use_smooth=p.center.z>1.43 or p.center.z<.10 or abs(p.center.x)>.27
# Features are shallow anatomical surfaces rather than exposed eyeballs.
for s,label in [(-1,'R'),(1,'L')]:
 sphere('Ear '+label,(s*.078,.029,1.535),(.014,.018,.030),skin)
 sphere('Ear concha '+label,(s*.087,.013,1.536),(.004,.010,.018),lip)
 x=s*.034
 sphere('Eye '+label,(x,-.054,1.552),(.018,.006,.0048),white,32,16)
 sphere('Iris '+label,(x,-.0622,1.552),(.0055,.0018,.0048),iris,24,12)
 sphere('Pupil '+label,(x,-.064,1.552),(.0025,.0007,.0038),pupil)
 sphere('Catchlight '+label,(x-.002,-.0648,1.555),(.0012,.0005,.0014),white,12,8)
 # Closed eyelid ribbons bridge the globe to the actual socket surface.
 vv=[];ff=[];nn=32
 for outer in [False,True]:
  for j in range(nn):
   a=j*2*math.pi/nn;xx=x+(.025 if outer else .018)*math.cos(a);zz=1.552+(.011 if outer else .0045)*math.sin(a)+s*math.cos(a)*.0015
   if outer:
    ok,p,n,index=new.ray_cast(Vector((xx,-1,zz)),Vector((0,1,0)));yy=p.y-.0005 if ok else -.043
   else:yy=-.056-.004*abs(math.sin(a))
   vv.append((xx,yy,zz))
 for j in range(nn):ff.append((j,(j+1)%nn,nn+(j+1)%nn,nn+j))
 lids=mesh('Sculpted eyelids '+label,vv,ff,skin)
 for p in lids.data.polygons:p.use_smooth=True
 # Tapered eyebrow ribbon follows the brow plane.
 vv=[];ff=[]
 for i in range(13):
  u=-1+2*i/12;xx=x+u*.024;zz=1.567+.003*(1-u*u)+s*u*.005
  ok,p,n,index=new.ray_cast(Vector((xx,-1,zz)),Vector((0,1,0)));yy=p.y-.0012 if ok else -.061
  w=.0016*math.sin(math.pi*(i+.3)/12.6)**.45
  vv.extend([(xx,yy,zz-w),(xx,yy,zz+w)])
 for i in range(12):ff.append((i*2,i*2+1,i*2+3,i*2+2))
 mesh('Brow '+label,vv,ff,hair)
 sphere('Nostril '+label,(s*.010,-.088,1.513),(.003,.0012,.0015),shadow,16,8)
# Shallow lip surfaces with tapered corners and a restrained cupid's bow.
for upper in [True,False]:
 vv=[];ff=[]
 for row in [0,1]:
  for i in range(25):
   u=-1+2*i/24;xx=u*.026;mid=1.487+.001*(1-u*u)-.0008*math.exp(-(u/.23)**2)
   zz=mid if row==0 else mid+(1 if upper else -1)*(.0035 if upper else .0048)*(1-u*u)
   ok,p,n,index=new.ray_cast(Vector((xx,-1,zz)),Vector((0,1,0)));yy=(p.y if ok else -.07)-(.001+.0013*(1-u*u)*row)
   vv.append((xx,yy,zz))
 for i in range(24):ff.append((i,i+1,25+i+1,25+i))
 o=mesh('Upper lip' if upper else 'Lower lip',vv,ff,lip)
 for p in o.data.polygons:p.use_smooth=True
pts=[]
for i in range(33):
 u=-1+2*i/32;xx=u*.026;zz=1.487+.001*(1-u*u)-.0008*math.exp(-(u/.23)**2)
 ok,p,n,index=new.ray_cast(Vector((xx,-1,zz)),Vector((0,1,0)));pts.append((xx,(p.y if ok else -.07)-.0016,zz))
line('Lip separation',pts,.00045,shadow)
# Hair cap follows the skull. Individual solid tapered locks establish the silhouette.
cap_profiles=[p for p in profiles if p[0]>=1.475];vv=[];ff=[];nn=64
for z,w,front,back in cap_profiles:
 for j in range(nn):
  a=j*2*math.pi/nn;c=math.cos(a)
  vv.append(((w+.006)*math.sin(a),(front-.006 if c>=0 else back+.006)*abs(c)+.023*(1-abs(c)),z+.002))
for i in range(len(cap_profiles)-1):
 for j in range(nn):
  face=(i*nn+j,i*nn+(j+1)%nn,(i+1)*nn+(j+1)%nn,(i+1)*nn+j)
  y=sum(vv[k][1] for k in face)/4;z=sum(vv[k][2] for k in face)/4
  cutoff=1.602 if y<.015 else 1.54 if y<.07 else 1.475
  if z>=cutoff:ff.append(face)
ff.append(tuple((len(cap_profiles)-1)*nn+j for j in range(nn)))
cap=mesh('Hair · fitted crown',vv,ff,hair)
bm=bmesh.new();bm.from_mesh(cap.data);bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_edges],context='VERTS');bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(cap.data);bm.free()
for p in cap.data.polygons:p.use_smooth=True
def lock(name,points,width,material):
 verts=[];faces=[];rings=5;sides=6
 for k in range(rings):
  t=k/(rings-1);p=(1-t)**2*Vector(points[0])+2*(1-t)*t*Vector(points[1])+t*t*Vector(points[2]);d=(Vector(points[1])-Vector(points[0])).lerp(Vector(points[2])-Vector(points[1]),t).normalized();normal=Vector((points[0][0],points[0][1]-.03,0)).normalized();u=d.cross(normal).normalized();v=d.cross(u).normalized();w=width*((1-t)**.7+.012)
  for j in range(sides):
   a=j*2*math.pi/sides;verts.append(tuple(p+w*(u*math.cos(a)+v*math.sin(a)*.38)))
 for k in range(rings-1):
  for j in range(sides):faces.append((k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j))
 faces += [tuple(reversed(range(sides))),tuple((rings-1)*sides+j for j in range(sides))]
 o=mesh(name,verts,faces,material);o.data.materials.append(hairlit)
 for p in o.data.polygons:p.material_index=1 if p.index%6==1 else 0
 return o
for row in range(3):
 for j in range(12):
  a=j*2*math.pi/12+row*.25;z=1.63+row*.018;r=.060-row*.016
  root=(r*math.sin(a),.032-r*math.cos(a),z)
  mid=(root[0]+.018*math.cos(a),root[1]-.018, z+.035)
  tip=(root[0]+.030*math.cos(a)+.014,root[1]-.030,z+.044+random.uniform(-.015,.018))
  lock('Hair · crown lock %02d %02d'%(row,j),[root,mid,tip],.019+random.random()*.007,hair)
# Irregular swept fringe, kept off the eyes.
for i in range(11):
 x=-.073+i*.0146
 lock('Hair · fringe %02d'%i,[(x,.005+random.uniform(-.008,.015),1.655+random.uniform(-.008,.016)),(x-.014,-.065,1.632),(x-.025+random.uniform(-.016,.018),-.075,1.586+random.uniform(-.020,.037))],.022,hair)
for side in [-1,1]:
 for i in range(6):
  lock('Hair · temple and nape',[(side*.060,.015+i*.015,1.64),(side*.085,.018+i*.014,1.604),(side*(.091+random.random()*.014),.021+i*.013,1.546+random.uniform(-.024,.012))],.018,hair)
# Layered occipital and nape locks complete the silhouette from the back and sides.
for row in range(3):
 for j in range(13):
  a=math.pi/2+j*math.pi/12+row*.07;r=.073-row*.006
  root=(r*math.sin(a),.03-r*math.cos(a),1.615+row*.018)
  mid=(.098*math.sin(a),.03-.105*math.cos(a),1.570+row*.013)
  tip=(.091*math.sin(a)+random.uniform(-.007,.007),.03-.097*math.cos(a),1.475+row*.025+random.uniform(-.010,.010))
  lock('Hair · layered back %02d %02d'%(row,j),[root,mid,tip],.019+random.random()*.007,hair)
# Shorts: connected waist and two leg tubes, with a closed crotch bridge.
# Each leg shares its medial upper edge with the pelvis through a common ring.
N=32;verts=[];faces=[]
# Waist loop front negative Y, positive X anatomical left.
for z,rx,ry in [(1.003,.135,.091),(.978,.146,.100),(.933,.166,.111),(.895,.173,.113)]:
 for j in range(N):
  a=j*2*math.pi/N;verts.append((rx*math.sin(a),.023-ry*math.cos(a),z))
for k in range(3):
 for j in range(N):faces.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
# Bridge the bottom ring across the perineum, then extend each half-ring into a leg.
# Ring indices: front=0, right outer=8, back=16, left outer=24.
base=3*N
for side,indices in [(1,list(range(0,17))),(-1,[0]+list(range(31,15,-1)))]:
 # 16 outer hem points and 8 medial points define a rounded upper-thigh contour.
 top=[base+j for j in indices]
 for k in range(1,9):
  t=k/9;verts.append((0,.023+.113*(1-2*t),.826+.069*abs(2*t-1)))
  top.append(len(verts)-1)
 M=len(top);prev=top
 for z,rx,ry in [(.826,.089,.105),(.75,.086,.100),(.677,.083,.094),(.662,.083,.094)]:
  ring=[]
  for j in range(M):
   # Parameterize continuously from front via the outer side to the back and medial seam.
   a=math.pi*j/16 if j<=16 else math.pi+math.pi*(j-16)/9;cx=side*.096
   verts.append((cx+side*rx*math.sin(a),.025-ry*math.cos(a),z+.003*math.cos(3*a)))
   ring.append(len(verts)-1)
  for j in range(M):faces.append((prev[j],prev[(j+1)%M],ring[(j+1)%M],ring[j]))
  prev=ring
shorts=mesh('Aren · technical shorts',verts,faces,cloth);shorts.data.materials.append(panel)
# Join coincident crotch vertices from the two leg contours.
bm=bmesh.new();bm.from_mesh(shorts.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(shorts.data);bm.free()
for p in shorts.data.polygons:
 p.use_smooth=True;p.material_index=0
solid=shorts.modifiers.new('Tailored cloth thickness','SOLIDIFY');solid.thickness=.002;solid.offset=0
# Broad technical waistband with a supported upper edge.
vv=[];ff=[]
for z,rx,ry in [(1.005,.136,.093),(.978,.148,.102)]:
 for j in range(48):
  a=j*2*math.pi/48;vv.append((rx*math.sin(a),.023-ry*math.cos(a),z))
for j in range(48):ff.append((j,(j+1)%48,48+(j+1)%48,48+j))
# Fold the waistband inward to the skin so elevated review views cannot see a gap.
for j in range(48):
 a=j*2*math.pi/48;vv.append((.110*math.sin(a),.018-.066*math.cos(a),1.005))
for j in range(48):ff.append((j,(j+1)%48,96+(j+1)%48,96+j))
waist=mesh('Waistband',vv,ff,cloth)
for p in waist.data.polygons:p.use_smooth=True
# Waistband and reinforced hems, seam tubes and angular thigh pocket.
for z,rx,ry,name in [(1.001,.136,.092,'Waist upper seam'),(.976,.147,.101,'Waist lower seam')]:
 line(name,[(rx*math.sin(a*2*math.pi/64),.023-ry*math.cos(a*2*math.pi/64),z) for a in range(65)],.0013,seam)
for s in [-1,1]:
 for z in [.664,.680]:line('Reinforced hem',[(s*.096+s*.084*math.sin(a*2*math.pi/48),.025-.096*math.cos(a*2*math.pi/48),z) for a in range(49)],.0014,seam)
 line('Angular front seam',[(s*.09,-.069,.977),(s*.113,-.088,.918),(s*.151,-.069,.844),(s*.151,-.063,.685)],.0012,seam)
 line('Back yoke',[(s*.015,.130,.925),(s*.079,.134,.906),(s*.155,.093,.916)],.0012,seam)
 # Flat angular outer pocket, with finite thickness and metallic fasteners.
 v=[(s*.181,-.014,.88),(s*.181,.063,.871),(s*.181,.070,.739),(s*.181,.014,.710),(s*.181,-.014,.735)]
 pocket=mesh('Side cargo pocket',v,[(0,1,2,3,4)],panel);mod=pocket.modifiers.new('Pocket thickness','SOLIDIFY');mod.thickness=.003
 line('Pocket perimeter',v+[v[0]],.0013,seam)
 for z in [.842,.752]:sphere('Pocket fastener',(s*.184,.013,z),(.0015,.003,.003),metal,12,8)
# Polygonal buckle with recessed dark center.
line('Buckle · outer', [(-.025,-.073,.997),(.025,-.073,.997),(.016,-.081,.977),(-.016,-.081,.977),(-.025,-.073,.997)],.003,metal)
line('Buckle · inset',[(-.012,-.077,.992),(.012,-.077,.992),(0,-.082,.981),(-.012,-.077,.992)],.0013,seam)
# Project tattoos onto the actual skin surface using the nearest front-facing ray.
def skinpoint(x,z,from_y=-1):
 ok,p,n,idx=new.ray_cast(Vector((x,from_y,z)),Vector((0,1,0)))
 return tuple(p+n*.0007) if ok else (x,-.08,z)
def tattoo(name,xz,width=.00085):
 dense=[]
 for a,b in zip(xz,xz[1:]):
  count=max(1,math.ceil(math.dist(a,b)/.0015))
  for i in range(count):
   t=i/count;dense.append((a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t))
 dense.append(xz[-1]);return line(name,[skinpoint(x,z) for x,z in dense],width,ink)
# Reference: symbol on anatomical left upper chest, runes left ribs, bars right forearm.
cx=.080;cz=1.281
for start,end in [(.10,2.65),(2.95,5.8)]:tattoo('Chest · broken orbit',[(cx+.021*math.cos(a),cz+.024*math.sin(a)) for a in [start+(end-start)*i/28 for i in range(29)]])
tattoo('Chest · orbit slash',[(cx-.032,cz-.031),(cx+.032,cz+.033)],.001)
def flank_mark(name,yz,width=.0008):
 pts=[]
 for a,b in zip(yz,yz[1:]):
  steps=max(1,math.ceil(math.dist(a,b)/.0015))
  for i in range(steps+1):
   t=i/steps;y=a[0]*(1-t)+b[0]*t;z=a[1]*(1-t)+b[1]*t
   ok,p,n,index=new.ray_cast(Vector((1,y,z)),Vector((-1,0,0)))
   if ok:pts.append(tuple(p+n*.0008))
 if len(pts)>1:line(name,pts,width,ink)
for i in range(7):
 z=1.176-i*.012
 flank_mark('Rib · glyph',[(-.024,z+.005),(-.015,z),(-.024,z-.004)] if i%2 else [(-.015,z+.005),(-.024,z),(-.015,z-.004)])
for i in range(11):
 z=1.185-i*.009;flank_mark('Rib · dotted axis',[(-.031,z),(-.031,z-.002)],.0005)
# Forearm after the temporary lowering of arms: ray-sample its actual contour.
# Locate it by original Hand/ForeArm evaluated matrices, not screen coordinates.
for s in [-1]:
 arm=rig.pose.bones['smartrig:RightArm'];pivot=arm.bone.head_local
 rot=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(-70),4,'Y')@Matrix.Translation(-pivot)
 fore=rot@rig.data.bones['smartrig:RightForeArm'].head_local;hand=rot@rig.data.bones['smartrig:RightHand'].head_local
 d=(hand-fore).normalized();u=Vector((d.z,0,-d.x)).normalized();center=fore.lerp(hand,.65)
 for k in [-1,1]:
  for a,b in [(-.032,-.005),(.002,.033)]:
   ps=[center+d*t+u*.006*k for t in [a,b]];tattoo('Forearm · parallel marks',[(p.x,p.z) for p in ps],.0011)
# Every authored mesh receives UVs; the joined anatomy needs a fresh layout.
for o in list(model.objects):
 if o.type=='MESH' and (not o.data.uv_layers or o==new):uv(o)
# Join small detail objects into editable semantic groups.
def join_group(name,objects):
 if not objects:return None
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
# Keep skin, hair, clothes and face/tattoos editable as separate logical meshes.
# Materials retain their names and their non-destructive nodes in the .blend.
for prefix,selector in [('Hair · authored locks',lambda o:o.name.startswith('Hair')),('Shorts · details',lambda o:any(o.name.startswith(p) for p in ['Waist','Reinforced','Angular','Back yoke','Side cargo','Pocket','Buckle']))]:
 join_group(prefix,[o for o in list(model.objects) if selector(o)])
# Remove zero-area detail faces left by very sharp seam corners.
for o in model.objects:
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.dissolve_degenerate(bm,dist=1e-8,edges=list(bm.edges))
 bad=[f for f in bm.faces if f.calc_area()<1e-14]
 if bad:bmesh.ops.delete(bm,geom=bad,context='FACES_ONLY')
 loose=[v for v in bm.verts if not v.link_faces]
 if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
 bm.to_mesh(o.data);bm.free()
# Bake a 2048px color atlas on an independent mesh for the review export.
# Editable semantic meshes and procedural paint remain in the Blender source.
bake_collection=bpy.data.collections.new('EXPORT · baked static copy');bpy.context.scene.collection.children.link(bake_collection)
copies=[]
for o in list(model.objects):
 if o.type!='MESH':continue
 duplicate=o.copy();duplicate.data=o.data.copy();bake_collection.objects.link(duplicate);copies.append(duplicate)
baked=join_group('ArenVisual',copies)
uv(baked)
image=bpy.data.images.new('Aren · painted color atlas',width=2048,height=2048,alpha=False)
image.filepath_raw=str(OUT/'albedo.png');image.file_format='PNG'
for m in baked.data.materials:
 if not m:continue
 node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;node.select=True;m.node_tree.nodes.active=node
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=False
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=8
bpy.ops.object.select_all(action='DESELECT');baked.select_set(True);bpy.context.view_layer.objects.active=baked
# Hide editable originals during baking so coincident surfaces cannot interfere.
model.hide_render=True
bpy.ops.object.bake(type='DIFFUSE');image.save();image.pack()
bakedmat=mat('Aren · baked painted atlas',(.5,.5,.5));node=bakedmat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
bakedmat.node_tree.links.new(node.outputs['Color'],bakedmat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
baked.data.materials.clear();baked.data.materials.append(bakedmat)
for p in baked.data.polygons:p.material_index=0
bpy.ops.export_scene.gltf(filepath=str(OUT/'aren_visual.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=False,export_cameras=False,export_lights=False)
# The source opens with the editable version visible. Export geometry is retained hidden.
model.hide_render=False;bake_collection.hide_render=True;bake_collection.hide_viewport=True
# Neutral review studio and six saved cameras.
studio=bpy.data.collections.new('STUDIO · neutral review');bpy.context.scene.collection.children.link(studio)
world=bpy.data.worlds.new('Neutral charcoal');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.20,.23,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35;bpy.context.scene.world=world
floor=mat('Studio floor',(.075,.085,.1));bpy.ops.mesh.primitive_plane_add(size=200);o=move(bpy.context.object,studio);o.name='Studio floor';o.data.materials.append(floor);o.location.z=-.005
for name,pos,power,size in [('Key',(-2,-3,4),260,3),('Fill',(3,-1,2),150,3),('Rim',(0,3,3),330,2)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=move(bpy.context.object,studio);o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
cameras={}
for name,pos in [('Front',(0,-4,.95)),('Left',(4,0,.95)),('Right',(-4,0,.95)),('Back',(0,4,.95)),('ThreeQuarter',(2,-4,1.3)),('High',(2,-4,2.6)),('Face',(.30,-1,1.57))]:
 bpy.ops.object.camera_add(location=pos);o=move(bpy.context.object,studio);o.name='Review · '+name;target=Vector((0,0,1.56 if name=='Face' else .88));o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=.43 if name=='Face' else 1.96;cameras[name]=o
scene=bpy.context.scene;scene.camera=cameras['ThreeQuarter'];scene.render.engine='CYCLES';scene.cycles.samples=16 if '--quick' in sys.argv else 64;scene.cycles.use_denoising=False;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
# Open in material view, with the reference collection hidden.
bpy.ops.object.select_all(action='DESELECT');new.select_set(True);bpy.context.view_layer.objects.active=new
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
scene['review_stage']='VISUAL ONLY · awaiting approval before rigging'
scene['source_commit']='b6f96efe63e09ed31a651a7b0fa8d6ffdf7919ac'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_visual.blend'))
(OUT/'authoring/.gdignore').touch()
summary={'atlas_resolution':[2048,2048],'stage':'visual_only_unapproved','source_commit':scene['source_commit'],'source_fbx':str(source.relative_to(R)),'source_fbx_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'rig_reference_bones':len(rig.data.bones),'rig_exported':False,'animations_exported':False,'height_m':max((o.matrix_world@v.co).z for o in model.objects if o.type=='MESH' for v in o.data.vertices),'meshes':len(model.objects),'triangles':sum(len(p.vertices)-2 for p in baked.data.polygons),'cameras':list(cameras),'body_method':'Original anatomy donor; lowered-arm static copy; authored head, hair, garment and tattoos; consolidated visual surface. Deformation topology and skinning await approval.'}
(OUT/'source.json').write_text(json.dumps(summary,indent=2)+'\n');print('AREN_SUMMARY',json.dumps(summary))
for name in ([] if '--no-render' in sys.argv else ['Left','Back','Face','ThreeQuarter','Front'] if '--quick' in sys.argv else cameras):
 scene.camera=cameras[name];scene.render.filepath=str(PRE/(name+'.png'));bpy.ops.render.render(write_still=True)
