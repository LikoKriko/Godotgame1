extends SceneTree
const Clips=preload('res://scripts/prototype_3d/survivor_animation.gd')
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<15:push_error(message)
func _initialize():call_deferred('run')
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 var n=actor.native
 for state in [&'walk',&'run']:
  var previous:Array=[]
  for i in 121:
   var phase:=i/120.0;actor.family_override=&'';actor.animate(state,phase,false,0,phase,Vector3.BACK)
   var pelvis:Basis=actor.last_pose.pelvis.basis
   for segment in 3:
    var bone:int=n.spine[segment]
    var actual:Basis=n.posed[bone].basis*n.rest[bone].basis.inverse()
    var lean:float=Clips.Gait.WALK_LEAN*Clips.Gait.WALK_SPINE_LEAN[segment] if state==&'walk' else Clips.Gait.RUN_LEAN*Clips.Gait.RUN_SPINE_LEAN[segment]
    var unleaned:Basis=Basis(pelvis.x.normalized(),-lean)*actual
    var relative:float=wrapf(unleaned.get_euler().y-pelvis.get_euler().y,-PI,PI)
    var expected:float=Clips.Controls.sample(state,phase).spine.y*[.25,.60,1.0][segment]
    require(absf(relative-expected)<.0003,'The gait twist is distributed along all three spine bones')
    if not previous.is_empty():require(actual.get_rotation_quaternion().angle_to(previous[segment])<.025,'Spine rotation stays fluid across the reduced keys and loop')
   previous=[]
   for bone in n.spine:previous.append((n.posed[bone].basis*n.rest[bone].basis.inverse()).get_rotation_quaternion())
 actor.family_override=&'';actor.animate(&'walk',.25,false,0,.25,Vector3.BACK)
 var upper:Transform3D=n.posed[n.spine[2]]*n.inverse_rest[n.spine[2]]
 var right:Array=n.arms[1].ids
 var difference:Vector3=(n.posed[right[1]].origin-n.posed[right[0]].origin)-upper.basis*(n.rest[right[1]].origin-n.rest[right[0]].origin)
 require(difference.dot(upper.basis.y.normalized())<-.10,'The active leg-side clavicle lowers the whole free arm gently')
 for family in [&'axe',&'pickaxe',&'sword']:
  actor.family_override=family
  for state in [&'idle',&'walk',&'run',&'action',&'equip',&'jump',&'slide',&'slide_back',&'crouch']:
   for phase in [.2,.5,.8]:
    actor.animate(state,phase,true,0,phase,Vector3.BACK if state in [&'walk',&'run'] else Vector3.ZERO)
    require(n.hand_error<.08,'Visible palms keep the actual tool contacts')
    for bone in n.posed.size():
     var parent:int=n.parents[bone]
     if parent>=0:require(absf(n.posed[bone].origin.distance_to(n.posed[parent].origin)-n.rest[bone].origin.distance_to(n.rest[parent].origin)*(n.grip.HAND_SCALE if n.grip.relaxed.has(bone) else 1.0))<.0001,'Spine and clavicles preserve native lengths; fingers preserve their configured hand proportion')
    if state==&'equip':continue
    var shaft:Vector3=actor.last_pose.shaft.normalized()
    for side in 2:
     if Clips.arm_is_free(actor.last_pose,side):continue
     var section:Vector3=n.grip.shafts[family][0 if side==actor.last_pose.active else 1]
     var center:Vector3=actor.grip_socket.position+actor.grip_socket.basis.x*section.x+actor.grip_socket.basis.z*section.y
     for chain in n.grip.fingers[side]:
      var tip:Vector3=n.posed[chain[3]].origin-center
      var radius:float=(tip-shaft*tip.dot(shaft)).length()
      require(radius>=section.z-.02 and radius<=section.z+.42,'Finger tips wrap the measured shaft instead of making an empty fist')
 # The grip is procedural: verify that changing tool orientation never flips
 # a finger to the other side of the shaft between neighbouring samples.
 for family in [&'axe',&'pickaxe',&'sword']:
  actor.family_override=family
  var previous:Array=[]
  for frame in 121:
   var phase:=frame/120.0;actor.animate(&'action',phase,true,0,phase)
   var rotations:Array=[]
   for side in 2:
    if Clips.arm_is_free(actor.last_pose,side):continue
    for chain in n.grip.fingers[side]:
     for bone in chain:rotations.append((n.posed[n.arms[side].ids[3]].basis.inverse()*n.posed[bone].basis).get_rotation_quaternion())
   if not previous.is_empty():
    for bone in rotations.size():require(rotations[bone].angle_to(previous[bone])<.55,'Fingers remain continuous while the held tool strikes and recovers: %s %.3f'%[family,phase])
   previous=rotations
 actor.free();print('%s: %d spine, continuity, native length and shaft-grip checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
