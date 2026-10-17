extends RefCounted
## Local, metre-based prototype. Outside this rectangle the world remains flat.
const AREA:=Rect2(-56,-112,112,140)
const GRID:=0.5
const SUPPORT_MARGIN:=0.05
const SUPPORT_BLEND:=0.75
const Catalog=preload("res://scripts/prototype_3d/story_zone_catalog.gd")
static func path_x(z:float) -> float:return 3.0*sin(-z*.065)+1.2*sin(-z*.17)
static func path_mask(p:Vector2) -> float:
 return (1.0-smoothstep(1.6,2.6,absf(p.x-path_x(p.y))))*smoothstep(-96.0,-88.0,p.y)*(1.0-smoothstep(5.0,10.0,p.y))
static func base_height(p:Vector2) -> float:
 if not AREA.has_point(p):return 0.0
 var edge:=smoothstep(0.0,10.0,minf(minf(p.x-AREA.position.x,AREA.end.x-p.x),minf(p.y-AREA.position.y,AREA.end.y-p.y)))
 var ramp:=clampf((-p.y-18.0),0.0,20.0)*tan(deg_to_rad(5.0))
 ramp*=1.0-smoothstep(65.0,100.0,-p.y)
 var shoulder:=1.0-smoothstep(10.0,36.0,absf(p.x-path_x(p.y)))
 var mountain:=8.0*pow(maxf(0.0,1.0-p.distance_squared_to(Vector2(23,-66))/(23.0*23.0)),2.0)
 var bumps:=.10*sin(p.y*1.1)*sin(p.x*.8+p.y*.4)*path_mask(p)*smoothstep(5.0,12.0,-p.y)
 # Keep a stable, flat spawn and a continuous join with the original floor.
 return edge*(ramp*shoulder+mountain+bumps)
static func support_radius(record:Dictionary) -> float:
 # Ground-contact footprint: roots, rock silhouette, or plant stem/leaf support.
 if record.kind==2:return record.height*.28
 if record.kind==1:return 1.5
 return .47 if record.kind==4 else .32
static func prepare_supports(records:Array) -> Dictionary:
 var pads:Array=[]
 for record in records:
  var point:=Vector2(record.position.x,record.position.z);var radius:=support_radius(record)
  var core:=radius+2.0*radius*SUPPORT_MARGIN
  if not AREA.grow(core+SUPPORT_BLEND).has_point(point):continue
  var altitude:=base_height(point)
  var edge:=not AREA.grow(-core-SUPPORT_BLEND).has_point(point)
  if edge:altitude=0.0
  pads.append({"point":point,"radius":radius,"core":core,"altitude":altitude,"cluster":pads.size(),"edge":edge})
 # Overlapping bases share one elevation, avoiding contradictory flat supports.
 for i in pads.size():
  for j in i:
   if pads[i].point.distance_to(pads[j].point)>pads[i].core+pads[j].core:continue
   var old:int=pads[i].cluster;var target:int=pads[j].cluster
   for pad in pads:
    if pad.cluster==old:pad.cluster=target
 var sums:Dictionary={};var counts:Dictionary={};var edges:Dictionary={}
 for pad in pads:
  if pad.edge:edges[pad.cluster]=true
  sums[pad.cluster]=sums.get(pad.cluster,0.0)+pad.altitude;counts[pad.cluster]=counts.get(pad.cluster,0)+1
 var index:Dictionary={}
 for pad in pads:
  pad.altitude=0.0 if edges.has(pad.cluster) else sums[pad.cluster]/counts[pad.cluster]
  var extent:float=pad.core+SUPPORT_BLEND
  var first:=Vector2i(floori((pad.point.x-extent)/8),floori((pad.point.y-extent)/8))
  var last:=Vector2i(floori((pad.point.x+extent)/8),floori((pad.point.y+extent)/8))
  for z in range(first.y,last.y+1):
   for x in range(first.x,last.x+1):
    var cell:=Vector2i(x,z)
    if not index.has(cell):index[cell]=[]
    index[cell].append(pad)
 return index
static func height(p:Vector2,supports:Dictionary={}) -> float:
 var original:=base_height(p)
 if not AREA.has_point(p):return original
 var weighted:=original;var total:=1.0
 for pad in supports.get(Vector2i(floori(p.x/8),floori(p.y/8)),[]):
  var amount:=1.0-smoothstep(pad.core,pad.core+SUPPORT_BLEND,p.distance_to(pad.point))
  if amount>=.99999:return pad.altitude
  var weight:float=amount/maxf(.00001,1.0-amount)
  weighted+=pad.altitude*weight;total+=weight
 return weighted/total
static func normal(p:Vector2,supports:Dictionary={}) -> Vector3:
 return Vector3(height(p-Vector2(.1,0),supports)-height(p+Vector2(.1,0),supports),.2,height(p-Vector2(0,.1),supports)-height(p+Vector2(0,.1),supports)).normalized()
static func geometry(area:Rect2,supports:Dictionary={}) -> ArrayMesh:
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
 var nx:=ceili(area.size.x/GRID);var nz:=ceili(area.size.y/GRID);var center:=area.get_center()
 for z in nz+1:
  for x in nx+1:
   var point:=area.position+Vector2(float(x)/nx,float(z)/nz)*area.size
   vertices.append(Vector3(point.x-center.x,height(point,supports),point.y-center.y));normals.append(normal(point,supports))
 for z in nz:
  for x in nx:
   var i:=z*(nx+1)+x
   indices.append_array(PackedInt32Array([i,i+1,i+nx+1,i+1,i+nx+2,i+nx+1]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return result
static func install_collision(parent:Node3D,bounds:Rect2,supports:Dictionary={}) -> void:
 # Reserve the full footprint, including the blending border, against story zones.
 assert(not Catalog.new().intersects(AREA),"Initial relief overlaps a fixed story reservation")
 var areas:=[Rect2(bounds.position,Vector2(AREA.position.x-bounds.position.x,bounds.size.y)),Rect2(Vector2(AREA.end.x,bounds.position.y),Vector2(bounds.end.x-AREA.end.x,bounds.size.y)),Rect2(Vector2(AREA.position.x,bounds.position.y),Vector2(AREA.size.x,AREA.position.y-bounds.position.y)),Rect2(Vector2(AREA.position.x,AREA.end.y),Vector2(AREA.size.x,bounds.end.y-AREA.end.y))]
 for area:Rect2 in areas:
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(area.size.x,.4,area.size.y);shape.shape=box;shape.position=Vector3(area.get_center().x,-.2,area.get_center().y);parent.add_child(shape)
 var patch:=CollisionShape3D.new();patch.name="InitialReliefCollision";patch.shape=geometry(AREA,supports).create_trimesh_shape();patch.position=Vector3(AREA.get_center().x,0,AREA.get_center().y);parent.add_child(patch)
static func clear_of_path(p:Vector2,radius:float) -> bool:
 if p.y+radius< -96.0 or p.y-radius>10.0:return true
 # Conservative footprint clearance, including the maximum sideways curve rate.
 return absf(p.x-path_x(p.y))>2.6+radius*1.5
