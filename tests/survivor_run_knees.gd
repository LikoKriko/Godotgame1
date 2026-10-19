extends SceneTree
const Solver=preload('res://scripts/continuous_body_pose.gd')
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _initialize():call_deferred('run')
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor);actor.family_override=&''
 var n=actor.native
 var exact:=0;var samples:=0
 var directions=[Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3(.574,0,.819),Vector3(-.574,0,.819),Vector3(.574,0,-.819),Vector3(-.574,0,-.819)]
 for state in [&'walk',&'run']:
  for direction in directions:
   for frame in 65:
    var phase:=frame/64.0;actor.animate(state,phase,false,0,phase,direction)
    var pelvis:Transform3D=actor.last_pose.pelvis
    var lateral:Vector3=pelvis.basis.x.normalized()
    var old_width:=0.0;var new_width:=0.0
    for side in 2:
     var ids:Array=n.legs[side].ids
     var hip:Vector3=n.posed[ids[0]].origin;var foot:Vector3=n.posed[ids[2]].origin
     var pole:Vector3=actor.rig.posed[11+side*3].origin-actor.rig.posed[10+side*3].origin
     var base:=Solver.joint(hip,foot,n.legs[side].a,n.legs[side].b,pole)
     var prior:Dictionary=n.spread_knee(base.duplicate(),pelvis,1.0,1.10)
     var expected:Dictionary=n.spread_knee(base.duplicate(),pelvis,1.0,1.32 if state==&'run' else 1.10)
     require(n.posed[ids[1]].origin.distance_to(expected.joint)<.0001,'Only running receives the extra twenty-percent lateral knee target')
     require(absf(n.posed[ids[1]].origin.distance_to(hip)-n.legs[side].a)<.0001,'The thigh keeps its length while the knee opens outward')
     require(absf(n.posed[ids[1]].origin.distance_to(foot)-n.legs[side].b)<.0001,'The shin keeps its length and the planted foot stays in place')
     old_width+=prior.joint.dot(lateral)*(-1 if side==0 else 1)
     new_width+=n.posed[ids[1]].origin.dot(lateral)*(-1 if side==0 else 1)
    if state==&'run':
     samples+=1
     require(absf(new_width)>=absf(old_width)-.001,'Running never narrows the previous lateral knee spacing')
     if absf(new_width/old_width-1.20)<.002:exact+=1
    else:require(absf(new_width-old_width)<.001,'Walking keeps its previous knee separation')
 require(exact>samples*.80,'The visible running knee distance reaches twenty percent more across the cycle and eight directions')
 # Blend toward the wider pose as sprint starts, preserving the two limb lengths.
 for frame in 21:
  actor.sprint_weight=frame/20.0;actor.animate(&'start_run',.5,false,0,.25,Vector3.BACK)
  require(absf(n.run_posture-actor.sprint_weight)<.0001,'Knee widening follows the current sprint blend')
 actor.free();print('%s: %d unarmed knee-spacing and fixed-length checks; exact running samples %d/%d'%['PASS' if failures==0 else 'FAIL',checks,exact,samples]);quit(1 if failures else 0)
