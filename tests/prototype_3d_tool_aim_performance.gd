extends SceneTree
## The frozen solver is a behavior oracle, not part of the game's runtime path.
const Reference=preload("res://tests/fixtures/tool_aim_reference.gd")
const Aim=preload("res://scripts/prototype_3d/tool_aim.gd")
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
const Profiles=preload("res://scripts/prototype_3d/held_profiles.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func same(a:Dictionary,b:Dictionary) -> bool:
 if a.is_empty() or b.is_empty():return a.is_empty()==b.is_empty()
 return a.grip.distance_to(b.grip)<.00001 and a.support.distance_to(b.support)<.00001 and a.basis.is_equal_approx(b.basis)
func compare(args:Array) -> void:
 var expected:Dictionary=Reference.solve.callv(args)
 require(same(expected,Aim.solve.callv(args)),"Optimized search retains the original reachable result, grip, support and frame")
 require(same(expected,Aim.solve.callv(args)),"Repeated exact query retains the original result, including misses")
func run():
 var rng:=RandomNumberGenerator.new();rng.seed=80321
 for family in [&"axe",&"pickaxe",&"sword"]:
  var profile:=Profiles.profile(family)
  for active in 2:
   for i in 160:
    var crouch:=rng.randf()
    var pose:=Clips.sample(family,&"action",.5,0,Vector3.ZERO,Vector3.INF,{},crouch)
    var point:=Vector3(rng.randf_range(-18,18),rng.randf_range(-12,75),rng.randf_range(2,70))
    compare([point,pose.shoulders,profile.tip,active,profile.two_hands,pose.body,profile.support,profile.get("shaft_range",Vector2(-4,28))])
  var pose:=Clips.sample(family,&"idle",0)
  for point in [Vector3(0,14,28),Vector3(0,30,32),Vector3(0,42,31),Vector3(0,30,4),Vector3(0,60,4),Vector3(0,-10,60),Vector3(0,40,3600)]:
   compare([point,pose.shoulders,profile.tip,pose.active,profile.two_hands,pose.body,profile.support,profile.get("shaft_range",Vector2(-4,28))])
 # Every input that affects a solution must distinguish the memoized query.
 var shoulders:Array=[Vector3(-6.2,48,1.3),Vector3(6.2,48,1.3)]
 var base:Array=[Vector3(0,42,31),shoulders,Vector3(11,20,0),0,true,Transform3D.IDENTITY,8.25,Vector2(-4,28)]
 for index in 8:
  var args:=base.duplicate(true)
  match index:
   0:args[0]+=Vector3(2,3,-1)
   1:args[1]=[shoulders[0]+Vector3.UP,shoulders[1]+Vector3.LEFT]
   2:args[2]+=Vector3(1,-3,2)
   3:args[3]=1
   4:args[4]=false
   5:args[5]=Transform3D(Basis(Vector3.RIGHT,.2),Vector3(0,-3,2))
   6:args[6]=4.95
   7:args[7]=Vector2(-4,18)
  compare(args)
 var expected:Dictionary=Reference.solve.callv(base)
 require(not expected.is_empty(),"Mutation probe starts at a reachable grip")
 var changed:Dictionary=Aim.solve.callv(base);changed.grip=Vector3(900,900,900);changed.clear()
 require(same(expected,Aim.solve.callv(base)),"Callers cannot mutate a stored solution")
 for i in 300:
  var args:=base.duplicate(true);args[0]=Vector3(0,40,500+i)
  Aim.solve.callv(args)
 require(Aim._solutions.size()<=Aim.CACHE_LIMIT,"Walking and continuously changing contacts cannot grow the memoization without bound")
 require(same(expected,Aim.solve.callv(base)),"A query evicted by movement is recomputed correctly")
 # Relative timing uses the same host and original solver. Include the first
 # uncached query, then the repeated contacts of a whole attack sequence.
 var total_before:=0;var total_after:=0
 for point in [Vector3(0,40,3600),Vector3(0,30,4),Vector3(0,42,31)]:
  var args:=base.duplicate(true);args[0]=point
  var start:=Time.get_ticks_usec()
  for i in 48:Reference.solve.callv(args)
  total_before+=Time.get_ticks_usec()-start
  Aim._solutions.clear();start=Time.get_ticks_usec()
  for i in 48:Aim.solve.callv(args)
  total_after+=Time.get_ticks_usec()-start
 require(total_after<float(total_before)*.4,"A repeated-contact attack uses less than forty percent of the original solve time")
 print("Solver timing (144 queries): original ",total_before/1000.0," ms; optimized ",total_after/1000.0," ms")
 print("%s: %d tool reach equivalence, cache isolation, bounded memory and performance checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
