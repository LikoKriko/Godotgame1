extends RefCounted
## Anatomical frames: the elbow/knee plane determines roll as well as swing.
## +Z is the actor's front. Elbows flex forward, knees project forward.
const SurfaceProfile=preload("res://scripts/prototype_3d/meshy_body_profile.gd")
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const Pose=preload("res://scripts/continuous_body_pose.gd")

static func arm(root:Vector3,hand:Vector3,body:Basis,side:int,free_swing:bool=false,draw_amount:float=0.0) -> Dictionary:
 var local:Vector3=body.inverse()*(hand-root)
 var raised:=smoothstep(-12,4,local.y)
 var across_chest:=smoothstep(1.0,5.0,local.x*(1 if side==0 else -1))
 var pole:=Vector3((-1 if side==0 else 1)*lerpf(0.75,2.2,across_chest),lerpf(-0.15,-0.85,raised)-across_chest*0.65,lerpf(0.2,0.9,raised)+across_chest*0.35)
 if free_swing:pole=Vector3(-0.12 if side==0 else 0.12,-0.02,-1.0)
 if draw_amount>0:
  var head_right:Vector3=Basis.IDENTITY.slerp(body,.2).x
  var drawing_pole:Vector3=body.inverse()*(head_right*(-2.0 if side==0 else 2.0)+Vector3(0,-.55,-.3))
  pole=pole.lerp(drawing_pole,clampf(draw_amount,0,1))
 var result:=Pose.joint(root,hand,Pose.UPPER_ARM,Pose.FOREARM,body*pole)
 if free_swing:return result
 # Keep the upper arm outside the rib cage while preserving the hand target.
 # Continuous repulsion avoids choosing between discrete elbow poses per frame.
 var shoulder_local:=Vector3((-1 if side==0 else 1)*Anatomy.SHOULDER.x,Anatomy.SHOULDER.y,Anatomy.SHOULDER.z)
 for iteration in 5:
  var force:=Vector3.ZERO
  for fraction in [0.35,0.60,0.85]:
   var point:Vector3=shoulder_local+body.inverse()*(result.root.lerp(result.joint,fraction)-root)
   if point.y<34 or point.y>48.0:continue
   var radius_value:=SurfaceProfile.radius(point.y)
   var width:=radius_value.x
   var depth:=radius_value.y+0.15
   var local_z:=point.z-SurfaceProfile.center_z(point.y)
   var radius:=sqrt(pow(point.x/width,2)+pow(local_z/depth,2))
   var penetration:=maxf(0,(1-radius)*depth+2.4)
   var normal:=Vector3(point.x/(width*width),0,maxf(0.04,local_z/(depth*depth))).normalized()
   force+=normal*penetration
  if force.length_squared()<0.000001:break
  pole+=(force*0.7)
  result=Pose.joint(root,hand,Pose.UPPER_ARM,Pose.FOREARM,body*pole)
 return result

static func frame(direction:Vector3,normal:Vector3) -> Basis:
 var y:=direction.normalized()
 var x:=normal-y*normal.dot(y)
 if x.length_squared()<0.000001:
  var fallback:=Vector3.RIGHT if absf(y.x)<0.8 else Vector3.BACK
  x=fallback-y*fallback.dot(y)
 x=x.normalized()
 return Basis(x,y,x.cross(y).normalized())

static func plane(chain:Dictionary) -> Vector3:
 return (chain.joint-chain.root).cross(chain.end-chain.joint).normalized()

static func segment_frame(chain:Dictionary,segment:int) -> Basis:
 return frame(chain.joint-chain.root if segment==0 else chain.end-chain.joint,plane(chain))

static func retarget(vertex:Vector3,source:Dictionary,target:Dictionary) -> Vector3:
 # Preserve radial thickness, but map actual joint centres onto the bind bones.
 # Unlike scaling XYZ, this cannot change humerus/radius/femur/tibia lengths.
 var points:Array[Vector3]=[source.root,source.joint,source.end]
 var targets:Array[Vector3]=[target.root,target.joint,target.end]
 var mapped:Array[Vector3]=[]
 for segment in 2:
  var axis:Vector3=points[segment].direction_to(points[segment+1])
  var along:float=(vertex-points[segment]).dot(axis)/points[segment].distance_to(points[segment+1])
  var center:Vector3=points[segment].lerp(points[segment+1],along)
  var rotation:Basis=segment_frame(target,segment)*segment_frame(source,segment).inverse()
  mapped.append(targets[segment].lerp(targets[segment+1],along)+rotation*(vertex-center)*Anatomy.BODY_WIDTH)
 # Blend the two bind mappings through the hinge; selecting the nearest segment
 # split an elbow ring into overlapping strips even in the neutral pose.
 var signed_distance:float=(vertex-source.joint).dot(source.root.direction_to(source.end))
 return mapped[0].lerp(mapped[1],smoothstep(-2.0,2.0,signed_distance))

static func hand_frame(chain:Dictionary,body:Basis,side:int,gripping:bool=false) -> Basis:
 # Fingers continue the forearm; palms face medially, not skyward on a run.
 var y:Vector3=(chain.joint-chain.end).normalized()
 var inward:Vector3=body.x*(1 if side==0 else -1)
 var z:=inward-y*inward.dot(y)
 # Hinge normal provides continuous roll when a forearm crosses the chest.
 z=plane(chain)*(-1.0 if side==0 else 1.0) if gripping else z+plane(chain)*(-0.3 if side==0 else 0.3)
 if z.length_squared()<0.000001:z=body.z-y*body.z.dot(y)
 z=z.normalized()
 var x:=y.cross(z).normalized()
 return Basis(x,y,x.cross(y).normalized())
