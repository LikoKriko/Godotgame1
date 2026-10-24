"""Blender 4.3+: independent dense head study, before any reduction or rigging.
Uses the original FBX as a read-only donor for facial volume and hair layers. Facial rings,
lids, oral/nasal cavities, auricles and swept hair are editable geometry.
"""
import bpy,bmesh,math,json,random,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[2]
OUT=R/'assets/characters/aren_v2/head_study';WORK=R/'work/aren-head'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'authoring').mkdir(exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
random.seed(3160)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
HEAD=bpy.data.collections.new('01 · HIGH · editable anatomy');bpy.context.scene.collection.children.link(HEAD)
HAIR=bpy.data.collections.new('02 · HIGH · swept hair locks');bpy.context.scene.collection.children.link(HAIR)
EYES=bpy.data.collections.new('03 · HIGH · eyes and brows');bpy.context.scene.collection.children.link(EYES)
REF=bpy.data.collections.new('90 · original facial volume · reference only');bpy.context.scene.collection.children.link(REF)
STUDIO=bpy.data.collections.new('99 · neutral portrait studio');bpy.context.scene.collection.children.link(STUDIO)
Z0=1.44

def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def g(x,c,w):return math.exp(-((x-c)/w)**2)
def material(name,color,rough=.7,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
SKIN=material('Painted warm skin',(.39,.223,.130),.73)
p=SKIN.node_tree.nodes.get('Principled BSDF');p.inputs['Subsurface Weight'].default_value=.035
c=SKIN.node_tree.nodes.new('ShaderNodeVertexColor');c.layer_name='Tone';SKIN.node_tree.links.new(c.outputs['Color'],p.inputs['Base Color'])
DARK=material('Mouth and nasal interior',(.07,.025,.018),.9)
WHITE=material('Sclera · ivory grey',(.42,.46,.43),.27)
IRIS=material('Iris · layered slate blue',(.085,.18,.235),.28)
c=IRIS.node_tree.nodes.new('ShaderNodeVertexColor');c.layer_name='Tone';IRIS.node_tree.links.new(c.outputs['Color'],IRIS.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
PUPIL=material('Pupil',(.003,.006,.008),.2)
H=[material('Hair · dark umber',(.023,.016,.011),.64),material('Hair · warm brown',(.035,.023,.014),.66),material('Hair · lit ridges',(.049,.032,.019),.67)]
CLAY=material('Neutral clay inspection',(.30,.29,.27),.85)
for m in H:
 m.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.25
 m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.78
 n=m.node_tree.nodes;l=m.node_tree.links;tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=330;tex.inputs['Detail'].default_value=2
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.000025;l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],n.get('Principled BSDF').inputs['Normal'])

def skincolor(x,z,red=0):
 cheek=g(abs(x),.052,.025)*g(z,.096,.025)
 warmth=.7*cheek+red
 return (.39+.025*warmth,.223-.018*warmth,.130-.009*warmth,1)
def mesh(name,vertices,faces,mat=SKIN,col=HEAD,colors=None):
 me=bpy.data.meshes.new(name);me.from_pydata(vertices,[],faces);me.update();o=bpy.data.objects.new(name,me);col.objects.link(o);me.materials.append(mat)
 for f in me.polygons:f.use_smooth=True
 if mat in [SKIN,IRIS]:
  attr=me.color_attributes.new(name='Tone',type='FLOAT_COLOR',domain='POINT')
  if colors is None:colors=[skincolor(v[0],v[2]-Z0) for v in vertices]
  for item,value in zip(attr.data,colors):item.color=value
  me.color_attributes.active_color=attr
 return o

def move(o,col):
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o);return o

def finish_normals(o):
 bm=bmesh.new();bm.from_mesh(o.data)
 loose=[v for v in bm.verts if not v.link_edges]
 if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()

# Smooth, dense sampling of the donor volume; donor textures are not projected onto the face.
source=R/'entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx'
bpy.ops.import_scene.fbx(filepath=str(source))
donor=next(o for o in bpy.data.objects if o.type=='MESH')
points=[donor.matrix_world@v.co for v in donor.data.vertices]
tree=BVHTree.FromPolygons(points,[tuple(p.vertices) for p in donor.data.polygons])
for o in list(bpy.data.objects):
 if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
move(donor,REF);donor.name='Original FBX · immutable volume reference';donor.hide_render=True;REF.hide_render=True;REF.hide_viewport=True
nx=nz=257;xs=np.linspace(-.083,.083,nx);zs=np.linspace(1.438,1.59,nz);field=np.zeros((nz,nx),dtype=np.float64)
for j,z in enumerate(zs):
 valid=[]
 for i,x in enumerate(xs):
  hit=tree.ray_cast(Vector((x,-1,z)),Vector((0,1,0)))[0]
  if hit is not None:field[j,i]=hit.y;valid.append(i)
  else:field[j,i]=np.nan
 if valid:field[j,:]=np.interp(np.arange(nx),valid,field[j,valid])
for _ in range(16):
 padded=np.pad(field,((1,1),(1,1)),mode='edge');field=(padded[1:-1,1:-1]*4+padded[:-2,1:-1]+padded[2:,1:-1]+padded[1:-1,:-2]+padded[1:-1,2:])/8
map_z=[(0,1.44),(.050,1.475),(.081,1.50),(.128,1.54),(.155,1.57),(.175,1.59)]
def donor_y(x,z):
 sz=np.interp(z,[a[0]for a in map_z],[a[1]for a in map_z]);u=max(0,min(nx-1.0001,(x/.93-xs[0])/(xs[-1]-xs[0])*(nx-1)));v=max(0,min(nz-1.0001,(sz-zs[0])/(zs[-1]-zs[0])*(nz-1)));i=int(u);j=int(v);a=u-i;b=v-j
 return float((1-a)*(1-b)*field[j,i]+a*(1-b)*field[j,i+1]+(1-a)*b*field[j+1,i]+a*b*field[j+1,i+1])+.012

# Shape controls describe chin, mandibular angle, cheekbone, orbit and cranium.
profiles=[(-.095,.054,-.035,.062),(-.055,.046,-.035,.066),(-.025,.044,-.040,.068),(0,.030,-.080,.073),(.012,.042,-.085,.081),(.025,.057,-.085,.089),(.045,.065,-.082,.098),(.067,.075,-.078,.107),(.090,.079,-.079,.113),(.110,.080,-.073,.115),(.128,.079,-.071,.114),(.148,.078,-.075,.112),(.166,.077,-.076,.107),(.188,.074,-.073,.099),(.208,.063,-.064,.084),(.225,.043,-.040,.057),(.235,.004,.023,.031)]
def profile(z):
 k=next((i for i in range(len(profiles)-1) if profiles[i+1][0]>=z),len(profiles)-2);a=profiles[k];b=profiles[k+1];p=profiles[max(0,k-1)];q=profiles[min(len(profiles)-1,k+2)];t=max(0,min(1,(z-a[0])/(b[0]-a[0])));result=[]
 for j in [1,2,3]:
  ma=(b[j]-p[j])/(b[0]-p[0]);mb=(q[j]-a[j])/(q[0]-a[0]);h=b[0]-a[0]
  result.append((2*t**3-3*t*t+1)*a[j]+(t**3-2*t*t+t)*h*ma+(-2*t**3+3*t*t)*b[j]+(t**3-t*t)*h*mb)
 return result

def face_y(x,z,c):
 w,front,back=profile(z);power=.90-.20*smooth(-.015,.015,z)-.12*smooth(.045,.085,z);y=front*max(0,c)**power+.021*(1-max(0,c)**power)
 weight=smooth(.25,.85,c)*smooth(-.002,.030,z)*(1-smooth(.125,.136,z))*(1-smooth(.065,.077,abs(x)))
 weight*=1-.85*g(abs(x),.0345,.025)*g(z,.128,.020)
 weight*=.35+.65*smooth(.065,.09,z)
 weight*=1-.30*g(x,0,.019)*g(z,.090,.025)
 if weight>0:y=y*(1-weight)+donor_y(x,z)*weight
 # Deliberate primary planes and secondary relief, in metres.
 y-=.003*g(abs(x),.052,.021)*g(z,.094,.027)
 y+=.0026*g(abs(x),.0345,.020)*g(z,.128,.015)
 y-=.0035*g(abs(x),.031,.025)*g(z,.151,.011)
 y+=.0011*g(abs(x),.071,.012)*g(z,.155,.025)
 y-=.0025*g(x,0,.027)*g(z,.014,.012)
 y+=.0016*g(x,0,.025)*g(z,.027,.006)
 y-=.0030*g(abs(x),.010,.007)*g(z,.080,.007)
 y-=.004*math.exp(-(x/.010)**4)*g(z,.102,.029)+.0025*g(x,0,.012)*g(z,.081,.009)
 y+=.0012*g(abs(x),.017,.003)*g(z,.078,.008)
 y-=.0009*g(abs(x),.0043,.0019)*g(z,.069,.006)
 y+=.0006*g(x,0,.0023)*g(z,.068,.006)
 return y

NC=640;NR=512;verts=[];faces=[]
for row in range(NR+1):
 z=profiles[0][0]+(profiles[-1][0]-profiles[0][0])*row/NR;w,front,back=profile(z)
 for j in range(NC):
  a=j*2*math.pi/NC;c=math.cos(a);width=w+.015*g(z,0,.020)*(1-max(0,c));x=width*math.sin(a)
  y=face_y(x,z,c) if c>0 else back*(-c)+.021*(1+c)
  # SCM tendons are modeled into the upper neck, with a soft medial hollow.
  if z<0 and c>0:
   y-=.0022*g(abs(x),.022+(-z)*.23,.006)*g(z,-.045,.05)
  verts.append((x,y,Z0+z))

def aperture(x,z,c):
 if c<.65:return False
 for side in [-1,1]:
  if ((x-side*.0345)/.021)**2+((z-.128-side*(x-side*.0345)*.08)/.010)**2<1:return True
 if (x/.033)**2+((z-.050)/.013)**2<1:return True
 for side in [-1,1]:
  if ((x-side*.0095)/.0027)**2+((z-.0765)/.0017)**2<1:return True
 return False
for row in range(NR):
 for j in range(NC):
  a=(j+.5)*2*math.pi/NC;idx=row*NC+j;js=(j+1)%NC
  x=(verts[idx][0]+verts[row*NC+js][0]+verts[(row+1)*NC+j][0]+verts[(row+1)*NC+js][0])/4;z=(verts[idx][2]+verts[(row+1)*NC+j][2])/2-Z0
  if not aperture(x,z,math.cos(a)):faces.append((idx,row*NC+js,(row+1)*NC+js,(row+1)*NC+j))
faces += [tuple(reversed(range(NC))),tuple(NR*NC+j for j in range(NC))]
head=mesh('Aren · dense facial sculpt',verts,faces)
# Each aperture gets a dense, continuous anatomical rim and a recessed cavity.
bm=bmesh.new();bm.from_mesh(head.data);loose=[v for v in bm.verts if not v.link_edges]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
boundaries={e for e in bm.edges if e.is_boundary};rings=[]
while boundaries:
 # Preserve actual boundary adjacency and opposite winding. Sorting by polar
 # angle can reorder the stepped grid boundary and twist the sewn surface.
 seed=min(boundaries,key=lambda e:min(v.index for v in e.verts))
 loop=seed.link_loops[0];start=loop.link_loop_next.vert;current=loop.vert
 ring=[start];previous=seed;boundaries.remove(seed)
 while current!=start:
  ring.append(current)
  candidates=[e for e in current.link_edges if e.is_boundary and e!=previous]
  if len(candidates)!=1:raise RuntimeError('Aperture boundary is not a simple cycle')
  edge=candidates[0]
  if edge not in boundaries:raise RuntimeError('Aperture boundary repeats an edge')
  boundaries.remove(edge);current=edge.other_vert(current);previous=edge
 rings.append(ring)
ring_data=[[tuple(v.co)for v in ring]for ring in rings];bm.free()

def add_rim(name,ring,kind,side=0):
 if kind=='eye':cx=side*.0345;cz=.128;rx=.021;rz=.010;steps=30
 elif kind=='mouth':cx=0;cz=.050;rx=.033;rz=.013;steps=34
 else:cx=side*.0095;cz=.0765;rx=.0027;rz=.0017;steps=14
 angles=[math.atan2((p[2]-Z0-cz)/rz,(p[0]-cx)/rx)for p in ring];n=len(ring);vv=[];ff=[];colors=[]
 for k in range(steps+1):
  t=k/steps
  for p,a in zip(ring,angles):
   if kind=='eye':
    dx=.0158*math.cos(a);dz=(.0050*math.sin(a)**.65 if math.sin(a)>=0 else -.0045*abs(math.sin(a))**.9)+side*.0018*math.cos(a);xx=cx+dx;zz=cz+dz;yy=-.046-math.sqrt(max(.000001,.0175**2-dx*dx-dz*dz))-.00018
   elif kind=='mouth':
    u=math.cos(a);xx=.029*u;zz=cz+.0007*math.sin(a)+.0006*g(u,0,.26);yy=face_y(xx,zz,math.sqrt(max(0,1-(xx/profile(zz)[0])**2)))-.0006
   else:
    xx=cx+.0025*math.cos(a);zz=cz+.00145*math.sin(a);yy=face_y(xx,zz,1)-.0002
   x=p[0]*(1-t)+xx*t;z=(p[2]-Z0)*(1-t)+zz*t;y=p[1]*(1-t)+yy*t
   if kind=='eye':
    y-=.00045*math.sin(math.pi*t)**1.1
    if math.sin(a)>0:y+=.00025*g(t,.43,.075)*math.sin(a)
    red=.08*math.sin(math.pi*t)
   elif kind=='mouth':
    y-=(.0026 if math.sin(a)>0 else .0035)*math.sin(math.pi*t)**1.1
    red=smooth(.40,.80,t)*.8
   else:y-=.0005*math.sin(math.pi*t);red=.1
   vv.append((x,y,Z0+z));color=skincolor(x,z,red)
   if kind=='mouth':
    amount=smooth(.48,.90,t)*.65;lip=(.38,.177,.123,1);color=tuple(color[j]*(1-amount)+lip[j]*amount for j in range(4))
   colors.append(color)
 for k in range(steps):
  for j in range(n):ff.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
 # Smooth along each contour while retaining the exact sewn boundary and inner rim.
 surface=np.array(vv,dtype=np.float64).reshape(steps+1,n,3)
 for iteration in range(8):
  filtered=.5*surface+.25*np.roll(surface,1,axis=1)+.25*np.roll(surface,-1,axis=1)
  surface[1:steps]=filtered[1:steps]
 vv=[tuple(p) for p in surface.reshape(-1,3)]
 # Interior rim turns inward; closed caps lie behind the globe or lip aperture.
 for layer in range(1,7):
  u=layer/6;scale=1-.22*u;depth=(.034 if kind=='eye' else .009 if kind=='mouth' else .0045)*u
  for p in vv[steps*n:(steps+1)*n]:
   vv.append((cx+(p[0]-cx)*scale,p[1]+depth,Z0+cz+(p[2]-Z0-cz)*scale));colors.append((.16,.073,.045,1) if kind!='eye' else skincolor(p[0],p[2]-Z0,.15))
  prev=(steps+layer-1)*n;cur=(steps+layer)*n
  for j in range(n):ff.append((prev+j,prev+(j+1)%n,cur+(j+1)%n,cur+j))
 ff.append(tuple((steps+6)*n+j for j in range(n)))
 return mesh(name,vv,ff,colors=colors)
parts=[]
for ring in ring_data:
 x=sum(p[0]for p in ring)/len(ring);z=sum(p[2]for p in ring)/len(ring)-Z0
 if abs(z-.128)<.025:parts.append(add_rim('Orbital lids and folded rim',ring,'eye',1 if x>0 else -1))
 elif abs(z-.050)<.020:parts.append(add_rim('Modeled lip volume and oral recess',ring,'mouth'))
 elif abs(z-.0765)<.008:parts.append(add_rim('Alar rim and nasal cavity',ring,'nose',1 if x>0 else -1))
 else:raise RuntimeError(('Unexpected open boundary',len(ring),x,z))
bpy.ops.object.select_all(action='DESELECT');head.select_set(True)
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=head;bpy.ops.object.join()
bm=bmesh.new();bm.from_mesh(head.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
# Sewn apertures must be closed and consistently oriented, without patch faces.
assert not any(e.is_boundary for e in bm.edges)
loose=[v for v in bm.verts if not v.link_edges]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
assert not any(e.is_manifold and not e.is_contiguous for e in bm.edges)
bm.to_mesh(head.data);bm.free()

# Dense globe, curved iris, limbal ring and pupil. Highlights come from studio lights.
for side in [-1,1]:
 cx=side*.0345;cz=Z0+.128
 bpy.ops.mesh.primitive_uv_sphere_add(segments=96,ring_count=64,radius=.0175,location=(cx,-.046,cz));o=move(bpy.context.object,EYES);o.name='Ocular globe '+str(side);o.data.materials.append(WHITE)
 for p in o.data.polygons:p.use_smooth=True
 vv=[(cx,-.0637,cz)];cols=[(.015,.03,.04,1)];ff=[];n=128;nr=28
 for row in range(1,nr+1):
  r=.0066*row/nr
  for j in range(n):
   a=j*2*math.pi/n;dx=r*math.cos(a);dz=r*math.sin(a);y=-.046-math.sqrt(.0175**2-r*r)-.00025
   fiber=(math.sin(a*93+math.sin(r*2200))*.5+.5)*.25+.75
   edge=1-.75*smooth(.82,1,r/.0066);inner=1-.65*(1-smooth(.30,.48,r/.0066))
   color=(.065*fiber*edge*inner,.13*fiber*edge*inner,.17*fiber*edge*inner,1)
   vv.append((cx+dx,y,cz+dz));cols.append(color)
 for j in range(n):ff.append((0,1+j,1+(j+1)%n))
 for row in range(nr-1):
  for j in range(n):ff.append((1+row*n+j,1+row*n+(j+1)%n,1+(row+1)*n+(j+1)%n,1+(row+1)*n+j))
 mesh('Radial iris '+str(side),vv,ff,IRIS,EYES,cols)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32,radius=1,location=(cx,-.06382,cz));o=move(bpy.context.object,EYES);o.name='Pupil '+str(side);o.scale=(.00265,.00025,.00265);o.data.materials.append(PUPIL)
 for p in o.data.polygons:p.use_smooth=True

# The upper ciliary edge is a fine tapered strip, following the actual ocular surface.
for side in [-1,1]:
 vv=[];ff=[]
 for i in range(129):
  a=i*math.pi/128;dx=.0158*math.cos(a);dz=.0050*math.sin(a)**.65+side*.0018*math.cos(a)
  thickness=.00032*math.sin(a)**.35
  for offset in [0,thickness]:
   yy=-.046-math.sqrt(max(.000001,.0175**2-dx*dx-(dz+offset)**2))-.00040
   vv.append((side*.0345+dx,yy,Z0+.128+dz+offset))
 for i in range(128):ff.append((2*i,2*i+1,2*i+3,2*i+2))
 mesh('Upper ciliary edge '+str(side),vv,ff,H[0],EYES)

# Closed auricles: continuous helix, forked antihelix, concha, tragus and lobe.
def distseg(y,z,a,b):
 v=Vector((y-a[0],z-a[1]));d=Vector((b[0]-a[0],b[1]-a[1]));t=max(0,min(1,v.dot(d)/d.length_squared));return (v-t*d).length
for side in [-1,1]:
 n=160;nr=64;vv=[];ff=[];colors=[]
 for back in [False,True]:
  vv.append((side*(.081 if back else .083),.010,Z0+.109));colors.append(skincolor(side*.085,.109,.3))
  for row in range(1,nr+1):
   r=row/nr
   for j in range(n):
    a=j*2*math.pi/n;yy=.013+.017*r*math.cos(a)*(1+.08*math.sin(a));zz=.110+.027*r*math.sin(a)
    if back:x=.080+.002*(1-r*r)
    else:
     x=.083+.014*g(r,.88,.095)*(.55+.45*smooth(-.5,.2,math.sin(a)))-.0018*g(r,.20,.18)
     for aa,bb in [((.009,.097),(.012,.122)),((.012,.122),(.025,.132)),((.012,.122),(.001,.128))]:x+=.0038*math.exp(-(distseg(yy,zz,aa,bb)/.0022)**2)
     x+=.0035*g(yy,-.001,.0035)*g(zz,.108,.0055)+.003*g(yy,.007,.004)*g(zz,.090,.005)
    yy-=(x-.08)*.22;vv.append((side*x,yy,Z0+zz));colors.append(skincolor(side*x,zz,.32+.18*(1-r)))
  base=(nr*n+1)*(1 if back else 0)
  for j in range(n):ff.append((base,base+1+j,base+1+(j+1)%n))
  for row in range(nr-1):
   for j in range(n):ff.append((base+1+row*n+j,base+1+row*n+(j+1)%n,base+1+(row+1)*n+(j+1)%n,base+1+(row+1)*n+j))
 offset=nr*n+1
 for j in range(n):ff.append((1+(nr-1)*n+j,1+(nr-1)*n+(j+1)%n,offset+1+(nr-1)*n+(j+1)%n,offset+1+(nr-1)*n+j))
 ear=mesh('Auricle · helix and concha '+str(side),vv,ff,colors=colors);finish_normals(ear)

# Solid swept locks, with modeled ridges and a tapered, curved silhouette.
def bezier(points,t):return (1-t)**3*Vector(points[0])+3*(1-t)**2*t*Vector(points[1])+3*(1-t)*t*t*Vector(points[2])+t**3*Vector(points[3])
def lock(name,points,width,thickness,mat=None,segments=52,cross=16,col=HAIR):
 vv=[];ff=[]
 def guide(t):
  p=bezier(points,t)
  # Frame the auricle instead of passing through its helix or concha.
  if col==HAIR and abs(p.x)>.070 and .071<p.z<.153:
   q=(p.z-.111)/.041
   if abs(q)<1:
    extent=.025*math.sqrt(1-q*q)
    if points[-1][1]>.005:p.y=max(p.y,.013+extent)
    else:p.y=min(p.y,.013-extent)
  return p
 for row in range(segments+1):
  t=row/segments;p=guide(t);tangent=(guide(min(1,t+.001))-guide(max(0,t-.001))).normalized()
  outward=Vector((p.x,p.y-.018,(p.z-.15)*.6)).normalized();u=tangent.cross(outward).normalized()
  if u.length<.1:u=tangent.cross(Vector((0,1,0))).normalized()
  v=tangent.cross(u).normalized()
  if v.dot(outward)<0:u=-u;v=-v
  envelope=(.65+.65*math.sin(math.pi*t))*max(.001,(1-t))**.68
  for j in range(cross):
   a=j*2*math.pi/cross;ridge=1+.13*math.cos(6*a+.5*math.sin(4*t))
   h=math.sin(a)*thickness*envelope*ridge
   if h<0:h*=.5
   co=p+u*(math.cos(a)*width*envelope)+v*h
   vv.append((co.x,co.y,Z0+co.z))
 for row in range(segments):
  for j in range(cross):ff.append((row*cross+j,row*cross+(j+1)%cross,(row+1)*cross+(j+1)%cross,(row+1)*cross+j))
 ff.extend([tuple(reversed(range(cross))),tuple(segments*cross+j for j in range(cross))]);o=mesh(name,vv,ff,mat or H[0],col);finish_normals(o);return o
# Scalp shell follows the actual head, hiding beneath the layered locks.
vv=[];ff=[];n=256;nr=100
for row in range(nr+1):
 z=.070+(.236-.070)*row/nr;w,front,back=profile(min(z,.235))
 for j in range(n):
  a=j*2*math.pi/n;c=math.cos(a);x=(w+.004)*math.sin(a);y=(front-.004 if c>=0 else back+.004)*abs(c)+.021*(1-abs(c));vv.append((x,y,Z0+z))
for row in range(nr):
 for j in range(n):
  a=(j+.5)*2*math.pi/n;c=math.cos(a);cut=.160+.035*smooth(.05,.70,c)-.015*smooth(.05,.80,-c)
  z=.070+(.236-.070)*(row+.5)/nr
  if z>cut:ff.append((row*n+j,row*n+(j+1)%n,(row+1)*n+(j+1)%n,(row+1)*n+j))
ff.append(tuple(nr*n+j for j in range(n)));cap=mesh('Fitted scalp underlay',vv,ff,H[0],HAIR);finish_normals(cap)
# Refine the native layered silhouette as a geometric donor, keeping the original immutable.
image=next(n.image for n in donor.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
pix=np.array(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)
uv=donor.data.uv_layers.active;selected=[];tones=[];selected_uvs=[]
for poly in donor.data.polygons:
 center=sum((points[v] for v in poly.vertices),Vector())/len(poly.vertices)
 cutoff=1.585 if center.y<-.05 and abs(center.x)<.065 else 1.570 if abs(center.x)>.075 and center.y<.05 else 1.53
 if center.z<cutoff:continue
 colors=[]
 for li in poly.loop_indices:
  q=uv.data[li].uv;colors.append(pix[min(image.size[1]-1,max(0,int(q.y*image.size[1]))),min(image.size[0]-1,max(0,int(q.x*image.size[0]))),:3])
 color=np.mean(colors,axis=0);lum=float(color@np.array([.2126,.7152,.0722]))
 if lum<.35 or center.z>1.62:
  selected.append(tuple(poly.vertices));selected_uvs.append([tuple(uv.data[li].uv)for li in poly.loop_indices]);tones.append(0 if lum<.08 else 1 if lum<.16 else 2)
used=sorted(set(v for face in selected for v in face));mapping={v:i for i,v in enumerate(used)};vv=[]
for idx in used:
 p=points[idx];fall=.020*smooth(-.055,-.105,p.y)*(1-smooth(1.60,1.665,p.z))*(1.0-.25*p.x/.10)
 vv.append((p.x*.93,p.y+.012,Z0+p.z-1.405-fall))
native_hair=mesh('Hair · refined layered sculpt',vv,[tuple(mapping[v]for v in f)for f in selected],H[0],HAIR)
uvlayer=native_hair.data.uv_layers.new(name='Source hair paint')
for polygon,coords in zip(native_hair.data.polygons,selected_uvs):
 for li,coord in zip(polygon.loop_indices,coords):uvlayer.data[li].uv=coord
# The FBX embeds pixels but reports a stale external directory as its filepath.
# Pack a generated copy so the editable study has no external texture dependency.
packed_hair=bpy.data.images.new('Native hair paint · embedded',width=image.size[0],height=image.size[1],alpha=True)
packed_hair.pixels.foreach_set(pix.ravel())
packed_hair.pack()
native_hair.data.materials.clear()
for scale in [.85,1,1.12]:
 mat=H[0].copy();mat.name='Hair paint · layered umber '+str(scale);nodes=mat.node_tree.nodes;links=mat.node_tree.links
 texture=nodes.new('ShaderNodeTexImage');texture.image=packed_hair;bw=nodes.new('ShaderNodeRGBToBW');ramp=nodes.new('ShaderNodeValToRGB')
 ramp.color_ramp.elements[0].position=.025;ramp.color_ramp.elements[0].color=(.010*scale,.0065*scale,.004,1)
 ramp.color_ramp.elements[1].position=.50;ramp.color_ramp.elements[1].color=(.075*scale,.047*scale,.025*scale,1)
 middle=ramp.color_ramp.elements.new(.17);middle.color=(.027*scale,.017*scale,.010*scale,1)
 links.new(texture.outputs['Color'],bw.inputs[0]);links.new(bw.outputs[0],ramp.inputs[0]);links.new(ramp.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
 native_hair.data.materials.append(mat)
for p,tone in zip(native_hair.data.polygons,tones):p.material_index=tone
bm=bmesh.new();bm.from_mesh(native_hair.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
# Reject isolated eyebrow/skin fragments selected by the dark-pixel mask.
remaining=set(bm.verts);discard=[]
while remaining:
 seed=next(iter(remaining));stack=[seed];group=set()
 while stack:
  v=stack.pop()
  if v in group:continue
  group.add(v);stack.extend(e.other_vert(v) for e in v.link_edges)
 remaining-=group
 if len(group)<100 and max(v.co.z for v in group)<Z0+.185:discard.extend(group)
if discard:bmesh.ops.delete(bm,geom=discard,context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(native_hair.data);bm.free()
finish_normals(native_hair)
solid=native_hair.modifiers.new('Closed thin layer roots','SOLIDIFY');solid.thickness=.00065;solid.offset=-.25
bpy.context.view_layer.objects.active=native_hair;bpy.ops.object.modifier_apply(modifier=solid.name)
crease=native_hair.data.attributes.new('crease_edge','FLOAT','EDGE')
bm=bmesh.new();bm.from_mesh(native_hair.data)
# Retain intentional angular breaks while smoothing the small-scale surface.
for e,item in zip(bm.edges,crease.data):item.value=.22 if len(e.link_faces)==2 and e.calc_face_angle()>.7 else 0
bm.free()
sub=native_hair.modifiers.new('Dense sculpt support','SUBSURF');sub.levels=3;sub.render_levels=3
bpy.ops.object.modifier_apply(modifier=sub.name)
# A few long, asymmetric locks extend the reference fringe, embedded in the source layers.
for i in range(5):
 x=-.043+i*.020;tip=[.166,.148,.176,.158,.185][i]
 lock('Fringe · detailed extension %02d'%i,[(x+.015,-.045,.231),(x+.020,-.075,.247),(x-.005,-.102,.212),(x-.020,-.099,tip)],.0065,.0019,H[i%2])
# Individual brows lie on the supraorbital plane. Dense ribbons carry tapered strands.
for side in [-1,1]:
 vv=[];ff=[]
 for i in range(65):
  u=i/64;x=side*(.013+.047*u);z=.1495+.0015*math.sin(math.pi*u)+.0025*u;half=.0024*math.sin(math.pi*u)**.45
  for zz in [z-half,z+half]:
   w,fr,ba=profile(zz);yy=face_y(x,zz,math.sqrt(max(0,1-(x/w)**2)))-.00035;vv.append((x,yy,Z0+zz))
 for i in range(64):ff.append((2*i,2*i+1,2*i+3,2*i+2))
 mesh('Brow · dense tapered foundation '+str(side),vv,ff,H[0],EYES)
 for i in range(34):
  u=i/33;x=side*(.014+.045*u);z=.1495+.0015*math.sin(math.pi*u)+.0025*u;w,fr,ba=profile(z);y=face_y(x,z,math.sqrt(max(0,1-(x/w)**2)))-.0007
  points=[(x,y,z-.0013),(x+side*.001,y-.0003,z+.0002),(x+side*.0024,y-.0002,z+.0017),(x+side*.0032,y,z+.0015)]
  lock('Brow strand %d %02d'%(side,i),points,.00026,.00016,H[0],12,8,EYES)

# Independent studio with frontal/profile/diagonal/detail cameras.
w=bpy.data.worlds.new('Neutral portrait world');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.10,.12,.15,1);w.node_tree.nodes['Background'].inputs[1].default_value=.35;bpy.context.scene.world=w
for name,pos,power,size in [('Key',(-.42,-.6,2.05),18,.42),('Fill',(.48,-.20,1.72),8,.4),('Rim',(0,.43,1.95),10,.32)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=move(bpy.context.object,STUDIO);o.name=name;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,Z0+.125))-o.location).to_track_quat('-Z','Y').to_euler()
cameras={}
for name,pos,target,size in [('Front',(0,-1.2,Z0+.125),(0,0,Z0+.125),.39),('Left',(1.2,0,Z0+.125),(0,0,Z0+.125),.39),('Right',(-1.2,0,Z0+.125),(0,0,Z0+.125),.39),('Back',(0,1.2,Z0+.125),(0,0,Z0+.125),.39),('ThreeQuarter',(.5,-1.2,Z0+.14),(0,0,Z0+.125),.39),('High',(.4,-1.1,Z0+.50),(0,0,Z0+.13),.42),('Ear',(1,-.35,Z0+.115),(.083,.015,Z0+.11),.09),('Eye',(.15,-1,Z0+.13),(.0345,-.05,Z0+.128),.10)]:
 bpy.ops.object.camera_add(location=pos);o=move(bpy.context.object,STUDIO);o.name='Head review · '+name;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=size;cameras[name]=o
scene=bpy.context.scene;scene.camera=cameras['ThreeQuarter'];scene.render.engine='CYCLES';scene.cycles.samples=24 if '--quick' in sys.argv else 80;scene.cycles.use_denoising=False;scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
scene['stage']='HIGH DENSITY · likeness study · no remesh or rigging'
scene['reference']='User character turnaround and portrait, supplied in chat'
scene['source_commit']='bd1471c8'
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT');head.select_set(True);bpy.context.view_layer.objects.active=head
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from aren_head_volumes import refine_primary_volumes, REVISION
refine_primary_volumes(head)
scene['volume_revision']=REVISION
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_head_high.blend'),compress=True)
counts={col.name:sum(len(o.data.polygons)for o in col.objects if o.type=='MESH')for col in [HEAD,HAIR,EYES]}
(OUT/'source.json').write_text(json.dumps({'stage':'high_density_likeness_study','source_commit':'bd1471c8','donor_source':str(source.relative_to(R)),'reference':'User-supplied character sheet in chat','faces_by_collection':counts,'primary_volume_revision':REVISION,'remesh_applied':False,'rigging_applied':False,'cameras':list(cameras)},indent=2)+'\n');print('HEAD_COUNTS',counts)
views=['Front','ThreeQuarter','Left','Ear','Eye','Back'] if '--quick' in sys.argv else list(cameras)
if '--no-render' in sys.argv:views=[]
for name in views:
 scene.camera=cameras[name];scene.render.filepath=str(WORK/(name+'.png'));bpy.ops.render.render(write_still=True)
